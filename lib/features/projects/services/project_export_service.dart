import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:get/get.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/camera/services/photo_exif.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/watermark/utils/capture_time_formatter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Which photos go into a project ZIP.
enum ProjectZipContents {
  watermarked(
    'Watermarked photos',
    'The watermarked copy of each photo, or the original if it has none.',
  ),
  originals('Original photos', 'The untouched originals.'),
  both('Both', 'Every original and every watermarked copy.');

  const ProjectZipContents(this.label, this.description);

  final String label;
  final String description;
}

class ProjectExportException implements Exception {
  const ProjectExportException(this.message);

  final String message;
}

/// A finished ZIP waiting to be shared.
class ProjectZip {
  const ProjectZip({required this.file, required this.photoCount});

  final File file;
  final int photoCount;

  String get name => file.uri.pathSegments.last;
}

/// One file to put in the ZIP: an image, and for originals the EXIF to add
/// (originals keep no GPS in the app; the shared copy should have it).
class _Item {
  const _Item(this.path, this.name, this.exif, {required this.isCopy});

  final String path;
  final String name;
  final ExifSpec? exif;

  /// A watermarked copy: its pixels are upright, and copies made since
  /// EXIF support already carry GPS, so they are left as they are.
  final bool isCopy;
}

/// Packs a project's photos into one ZIP for sending to a client, with a
/// spreadsheet (CSV) of when and where each was taken. Photos are only
/// read; nothing in the app changes.
class ProjectExportService {
  ProjectExportService({
    Future<Directory> Function()? tempDirectory,
    DateTime Function()? clock,
  }) : _tempDirectory = tempDirectory ?? getTemporaryDirectory,
       _clock = clock ?? DateTime.now;

  final Future<Directory> Function() _tempDirectory;
  final DateTime Function() _clock;

  final RxBool isBusy = false.obs;

  /// Files added so far, out of the total; null while idle or preparing.
  final Rxn<(int, int)> progress = Rxn<(int, int)>();

  static const String csvName = 'photo_locations.csv';

  /// The photos [contents] selects from [index], oldest first.
  static List<GalleryPhoto> plan(
    GalleryIndex index,
    ProjectZipContents contents,
  ) {
    final picked = <GalleryPhoto>[];
    for (final photo in index.photos.reversed) {
      if (photo.isOriginal) {
        final copies = index.variantsOf(photo).reversed.toList();
        switch (contents) {
          case ProjectZipContents.originals:
            picked.add(photo);
          case ProjectZipContents.watermarked:
            copies.isEmpty ? picked.add(photo) : picked.addAll(copies);
          case ProjectZipContents.both:
            picked
              ..add(photo)
              ..addAll(copies);
        }
      } else if (index.sourceOf(photo) == null &&
          contents != ProjectZipContents.originals) {
        // A copy whose original was deleted.
        picked.add(photo);
      }
    }
    return picked;
  }

  /// Builds the ZIP in the app's cache. The previous export is removed
  /// first, so at most one is ever kept.
  Future<ProjectZip> build({
    required String projectName,
    required GalleryIndex index,
    required ProjectZipContents contents,
    bool includeCsv = true,
  }) async {
    if (isBusy.value) {
      throw const ProjectExportException('An export is already running.');
    }
    final photos = plan(index, contents);
    if (photos.isEmpty) {
      throw const ProjectExportException('This project has no photos.');
    }
    isBusy.value = true;
    progress.value = null;
    final dir = Directory('${(await _tempDirectory()).path}/project_exports');
    final zip = File('${dir.path}/${fileNameFor(projectName, _clock())}');
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
      final items = [
        for (final p in photos)
          _Item(
            p.path,
            p.fileName,
            p.metadata == null ? null : ExifSpec.from(p.metadata!),
            isCopy: p.isWatermarked,
          ),
      ];
      final csv = includeCsv ? csvFor(photos) : null;
      final port = ReceivePort();
      port.listen((m) {
        if (m case [final int done, final int total]) {
          progress.value = (done, total);
        }
      });
      try {
        await _zipInBackground(zip.path, items, csv, port.sendPort);
      } finally {
        port.close();
      }
      return ProjectZip(file: zip, photoCount: photos.length);
    } catch (e) {
      try {
        if (await zip.exists()) await zip.delete();
      } catch (_) {}
      if (e is ProjectExportException) rethrow;
      throw const ProjectExportException(
        'The ZIP could not be created. Check that the phone has free space.',
      );
    } finally {
      isBusy.value = false;
      progress.value = null;
    }
  }

  /// `Site C_photos_20261108.zip`, safe as a file name.
  static String fileNameFor(String projectName, DateTime now) {
    final safe = projectName
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    String two(int v) => v.toString().padLeft(2, '0');
    final base = safe.isEmpty ? 'Project' : safe;
    final cut = base.length > 60 ? base.substring(0, 60).trimRight() : base;
    return '${cut}_photos_${now.year}${two(now.month)}${two(now.day)}.zip';
  }

  /// One row per file: when, where, accuracy, direction, address and note.
  /// Starts with a byte-order mark so Excel reads non-English text.
  static String csvFor(List<GalleryPhoto> photos) {
    const header = [
      'File',
      'Type',
      'Taken (local)',
      'UTC offset',
      'Latitude',
      'Longitude',
      'GPS accuracy (m)',
      'Location status',
      'Altitude (m)',
      'Camera direction (deg)',
      'Place',
      'Address',
      'Plus Code',
      'Note',
    ];
    final rows = <List<String>>[header];
    for (final photo in photos) {
      final m = photo.metadata;
      rows.add([
        photo.fileName,
        photo.isOriginal ? 'Original' : 'Watermarked',
        ...?_metadataCells(m),
        if (m == null) ...List.filled(header.length - 2, ''),
      ]);
    }
    return '﻿${rows.map((r) => r.map(_cell).join(',')).join('\r\n')}\r\n';
  }

  static List<String>? _metadataCells(PhotoMetadata? m) {
    if (m == null) return null;
    final wall = CaptureTimeFormatter.wallClock(m.capturedAt, m.timeZoneOffset);
    String two(int v) => v.toString().padLeft(2, '0');
    final fix = m.location.status == LocationRecordStatus.unavailable
        ? null
        : m.location.fix;
    return [
      '${wall.year}-${two(wall.month)}-${two(wall.day)} '
          '${two(wall.hour)}:${two(wall.minute)}:${two(wall.second)}',
      CaptureTimeFormatter.utcOffset(m.timeZoneOffset),
      fix?.latitude.toStringAsFixed(7) ?? '',
      fix?.longitude.toStringAsFixed(7) ?? '',
      fix?.accuracy.toStringAsFixed(1) ?? '',
      m.location.status.name,
      fix?.altitude?.toStringAsFixed(1) ?? '',
      m.direction?.degrees.toStringAsFixed(1) ?? '',
      m.place?.title ?? '',
      m.place?.addressLine ?? fix?.address ?? '',
      m.place?.plusCode ?? '',
      m.note ?? '',
    ];
  }

  /// Quotes a cell when needed, and neutralises leading = + - @ so a
  /// spreadsheet never runs text as a formula.
  static String _cell(String value) {
    var v = value;
    if (v.isNotEmpty && '=+-@'.contains(v[0]) && double.tryParse(v) == null) {
      v = "'$v";
    }
    return RegExp(r'[",\r\n]').hasMatch(v) ? '"${v.replaceAll('"', '""')}"' : v;
  }
}

Future<void> _zipInBackground(
  String zipPath,
  List<_Item> items,
  String? csv,
  SendPort port,
) => Isolate.run(() => _writeZip(zipPath, items, csv, port));

Future<void> _writeZip(
  String zipPath,
  List<_Item> items,
  String? csv,
  SendPort port,
) async {
  final encoder = ZipFileEncoder()
    ..create(zipPath, level: ZipFileEncoder.store);
  try {
    if (csv != null) {
      encoder.addArchiveFile(
        ArchiveFile.bytes(
          ProjectExportService.csvName,
          Uint8List.fromList(utf8.encode(csv)),
        ),
      );
    }
    final used = <String>{};
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final file = File(item.path);
      if (file.existsSync()) {
        var name = item.name;
        for (var n = 1; used.contains(name); n++) {
          final dot = item.name.lastIndexOf('.');
          name = dot < 0
              ? '${item.name}_$n'
              : '${item.name.substring(0, dot)}_$n${item.name.substring(dot)}';
        }
        used.add(name);
        // EXIF is for photos; videos are added as they are.
        final exif = item.name.toLowerCase().endsWith('.mp4')
            ? null
            : item.exif;
        final bytes = exif == null ? null : file.readAsBytesSync();
        final hasGps =
            bytes != null &&
            item.isCopy &&
            (img.decodeJpgExif(bytes)?.gpsIfd.containsKey(0x02) ?? false);
        if (exif == null || bytes == null || hasGps) {
          await encoder.addFile(file, name);
        } else {
          final tagged =
              PhotoExif.apply(bytes, exif, upright: item.isCopy) ?? bytes;
          encoder.addArchiveFile(ArchiveFile.bytes(name, tagged));
        }
      }
      port.send([i + 1, items.length]);
    }
  } finally {
    await encoder.close();
  }
}
