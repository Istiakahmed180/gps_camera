import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/share_service.dart';
import 'package:gps_camera/features/reports/models/report_models.dart';
import 'package:gps_camera/features/reports/models/report_record.dart';
import 'package:gps_camera/features/reports/services/pdf_report_renderer.dart';

class ReportException implements Exception {
  const ReportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReportResult {
  const ReportResult({required this.file, required this.record});

  final File file;
  final ReportRecord record;
}

enum ReportOpenOutcome { opened, noApp, missing, failed }

typedef ReportRunner = Future<ReportRenderStats> Function(
  ReportJob job,
  ReportFonts fonts,
  String outputPath,
  void Function(ReportProgress progress) onProgress,
);

typedef FontLoader = Future<ReportFonts> Function();

/// Generates, lists, shares, opens and deletes PDF reports in
/// `GPSCamera/Reports/`. Never reads or writes anything but report files;
/// photos and metadata are only read during generation.
class ReportService extends GetxService {
  ReportService(
    this._storage,
    this._share, {
    ReportRunner? runner,
    FontLoader? fonts,
    MethodChannel? channel,
  }) : _runner = runner ?? runInIsolate,
       _fonts = fonts ?? loadBundledFonts,
       _channel =
           channel ?? const MethodChannel('co.tdevs.gps_camera/report_files');

  /// Keeps memory and file size reasonable on phones.
  static const int maxPhotos = 300;

  final PhotoStorageService _storage;
  final ShareService _share;
  final ReportRunner _runner;
  final FontLoader _fonts;
  final MethodChannel _channel;

  final RxBool isGenerating = false.obs;
  final Rxn<ReportProgress> progress = Rxn<ReportProgress>();

  /// Renders [job] in a background isolate and saves it under a new, unique
  /// name. Throws [ReportException]; on failure no partial file remains.
  Future<ReportResult> generate(ReportJob job) async {
    if (isGenerating.value) {
      throw const ReportException('A report is already being generated.');
    }
    if (job.entries.isEmpty) {
      throw const ReportException('There are no photos to include.');
    }
    if (job.entries.length > maxPhotos) {
      throw const ReportException(
        'Reports are limited to $maxPhotos photos. Select fewer photos.',
      );
    }

    isGenerating.value = true;
    progress.value = ReportProgress(0, job.entries.length);
    File? target;
    File? temp;
    try {
      final fonts = await _fonts();
      target = await _storage.reserveReportFile(baseNameFor(job));
      temp = File('${target.path}.tmp');
      final stats = await _runner(
        job,
        fonts,
        temp.path,
        (p) => progress.value = p,
      );
      if (!await temp.exists() || await temp.length() == 0) {
        throw const ReportException('The report file was not written.');
      }
      await temp.rename(target.path);

      final record = ReportRecord(
        fileName: target.uri.pathSegments.last,
        type: job.type,
        title: job.title,
        generatedAt: job.generatedAt,
        photoCount: job.entries.length,
        pageCount: stats.pageCount,
        projectId: job.projectId,
        projectName: job.projectName,
      );
      await _storage.writeJsonAtomic(
        _storage.metadataFileFor(target),
        record.toJson(),
      );
      return ReportResult(file: target, record: record);
    } catch (e) {
      for (final file in [?temp, ?target]) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      if (e is ReportException) rethrow;
      throw ReportException('The report could not be created: $e');
    } finally {
      isGenerating.value = false;
      progress.value = null;
    }
  }

  /// Reports in the reports folder, newest first. Only finished PDFs are
  /// listed; reserved or temporary files are skipped.
  Future<List<ReportFile>> history() async {
    final directory = await _storage.reportsDirectory();
    final reports = <ReportFile>[];
    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.pdf')) continue;
      final stat = entity.statSync();
      if (stat.size == 0) continue;
      reports.add(
        ReportFile(
          file: entity,
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
          record: _readRecord(entity),
        ),
      );
    }
    return reports..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
  }

  /// Deletes the PDF and its record. Nothing outside the reports folder is
  /// ever touched.
  Future<void> delete(ReportFile report) async {
    final directory = await _storage.reportsDirectory();
    if (report.file.parent.absolute.path != directory.absolute.path) {
      throw const ReportException('Only reports can be deleted here.');
    }
    if (await report.file.exists()) await report.file.delete();
    final record = _storage.metadataFileFor(report.file);
    if (await record.exists()) await record.delete();
  }

  Future<ShareOutcome> share(File report, {Rect? origin}) =>
      _share.shareFile(report, mimeType: 'application/pdf', origin: origin);

  /// Opens the PDF in another app. iOS uses the share sheet, which offers
  /// "Open in…".
  Future<ReportOpenOutcome> open(File report, {Rect? origin}) async {
    if (!await report.exists()) return ReportOpenOutcome.missing;
    if (!Platform.isAndroid) {
      final outcome = await share(report, origin: origin);
      return outcome == ShareOutcome.failed
          ? ReportOpenOutcome.failed
          : ReportOpenOutcome.opened;
    }
    try {
      final result = await _channel.invokeMethod<String>('openPdf', {
        'path': report.path,
      });
      return switch (result) {
        'opened' => ReportOpenOutcome.opened,
        'noApp' => ReportOpenOutcome.noApp,
        'missing' => ReportOpenOutcome.missing,
        _ => ReportOpenOutcome.failed,
      };
    } catch (_) {
      return ReportOpenOutcome.failed;
    }
  }

  ReportRecord? _readRecord(File pdf) {
    try {
      final json = jsonDecode(_storage.metadataFileFor(pdf).readAsStringSync());
      return ReportRecord.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// `Report_<Project>_yyyyMMdd_HHmmss` or `Report_Selection_…`. Only safe
  /// ASCII characters, so names work in any app the report is shared to.
  static String baseNameFor(ReportJob job) {
    final label = job.type == ReportType.project
        ? _slug(job.projectName ?? 'Project')
        : 'Selection';
    final t = job.generatedAt;
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Report_${label}_${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  static String _slug(String name) {
    final slug = name
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) return 'Project';
    return slug.length > 40 ? slug.substring(0, 40) : slug;
  }

  static Future<ReportFonts> loadBundledFonts() async {
    Future<Uint8List> load(String name) async =>
        (await rootBundle.load('assets/fonts/$name')).buffer.asUint8List();
    return ReportFonts(
      regular: await load('Roboto-Regular.ttf'),
      medium: await load('Roboto-Medium.ttf'),
      bold: await load('Roboto-Bold.ttf'),
    );
  }

  /// Renders in a separate isolate and streams progress back.
  static Future<ReportRenderStats> runInIsolate(
    ReportJob job,
    ReportFonts fonts,
    String outputPath,
    void Function(ReportProgress progress) onProgress,
  ) async {
    final port = ReceivePort();
    final done = Completer<ReportRenderStats>();
    port.listen((message) {
      switch (message) {
        case ReportProgress():
          onProgress(message);
        case ReportRenderStats():
          done.complete(message);
          port.close();
        case [final Object error, final Object _]:
          done.completeError(ReportException('$error'));
          port.close();
        case null:
          if (!done.isCompleted) {
            done.completeError(
              const ReportException('Report generation stopped unexpectedly.'),
            );
          }
          port.close();
      }
    });
    final isolate = await Isolate.spawn(
      _isolateMain,
      (port.sendPort, job, fonts, outputPath),
      onError: port.sendPort,
      onExit: port.sendPort,
    );
    try {
      return await done.future;
    } finally {
      isolate.kill(priority: Isolate.immediate);
    }
  }

  static Future<void> _isolateMain(
    (SendPort, ReportJob, ReportFonts, String) args,
  ) async {
    final (send, job, fonts, path) = args;
    final stats = await renderReportPdf(
      job,
      fonts,
      path,
      onProgress: send.send,
    );
    send.send(stats);
  }
}
