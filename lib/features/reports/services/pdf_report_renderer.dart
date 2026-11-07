import 'dart:io';
import 'dart:typed_data';

import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/gallery/utils/photo_info_formatter.dart';
import 'package:gps_camera/features/location/models/gps_accuracy_level.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/location/models/place_info.dart';
import 'package:gps_camera/features/reports/models/report_models.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/utils/capture_time_formatter.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Embedded font files (Roboto), so symbols like ° ± − render offline.
class ReportFonts {
  const ReportFonts({
    required this.regular,
    required this.medium,
    required this.bold,
  });

  final Uint8List regular;
  final Uint8List medium;
  final Uint8List bold;
}

class ReportRenderStats {
  const ReportRenderStats({
    required this.pageCount,
    required this.imageCount,
    required this.missingImages,
  });

  final int pageCount;
  final int imageCount;
  final int missingImages;
}

/// Builds the report PDF and writes it to [outputPath]. Pure Dart: runs in
/// a background isolate. Photos are decoded one at a time at reduced size,
/// so memory stays bounded however large the project.
Future<ReportRenderStats> renderReportPdf(
  ReportJob job,
  ReportFonts fonts,
  String outputPath, {
  void Function(ReportProgress progress)? onProgress,
}) async {
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(fonts.regular.buffer.asByteData()),
    bold: pw.Font.ttf(fonts.bold.buffer.asByteData()),
  );
  final medium = pw.Font.ttf(fonts.medium.buffer.asByteData());
  final style = _Styles(medium);
  final large = job.entries.length > 60;

  final blocks = <pw.Widget>[];
  var images = 0;
  var missing = 0;
  for (final (i, entry) in job.entries.indexed) {
    final prepared = <(ReportImage, Uint8List?)>[];
    for (final image in entry.images) {
      final bytes = _prepareImage(image.path, maxSide: large ? 640 : 900);
      bytes == null ? missing++ : images++;
      prepared.add((image, bytes));
    }
    blocks.add(_entryBlock(i + 1, entry, prepared, job.type, style));
    onProgress?.call(ReportProgress(i + 1, job.entries.length));
  }

  final doc = pw.Document(
    theme: theme,
    title: job.title,
    author: 'GPS Camera',
    creator: 'GPS Camera',
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 32),
      maxPages: 1000,
      header: (context) =>
          context.pageNumber == 1 ? pw.SizedBox() : _runningHeader(job, style),
      footer: (context) => _footer(context, job, style),
      build: (context) => [_summary(job, style, missing), ...blocks],
    ),
  );

  onProgress?.call(
    ReportProgress(job.entries.length, job.entries.length, saving: true),
  );
  final bytes = await doc.save();
  File(outputPath).writeAsBytesSync(bytes, flush: true);
  return ReportRenderStats(
    pageCount: doc.document.pdfPageList.pages.length,
    imageCount: images,
    missingImages: missing,
  );
}

/// Decodes at a JPEG DCT scale close to the target size (never full
/// resolution for large photos), applies EXIF orientation, and re-encodes
/// compactly. Returns null when the file is missing or unreadable.
Uint8List? _prepareImage(String path, {required int maxSide}) {
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    final bytes = file.readAsBytesSync();
    final info = img.JpegData().readInfo(bytes);
    if (info == null) return null;
    final longSide = info.width > info.height ? info.width : info.height;
    var scale = 1;
    for (final s in const [8, 4, 2]) {
      if (longSide / s >= maxSide) {
        scale = s;
        break;
      }
    }
    var image = img.decodeJpg(bytes, scale: scale);
    if (image == null) return null;
    final orientation = image.exif.imageIfd.orientation;
    if (orientation != null && orientation != 1) {
      image = img.bakeOrientation(image);
    }
    final side = image.width > image.height ? image.width : image.height;
    if (side > maxSide) {
      image = img.copyResize(
        image,
        width: image.width >= image.height ? maxSide : null,
        height: image.height > image.width ? maxSide : null,
        interpolation: img.Interpolation.average,
      );
    }
    return img.encodeJpg(image, quality: 78);
  } catch (_) {
    return null;
  }
}

class _Styles {
  _Styles(this.medium);

  final pw.Font medium;

  static const PdfColor accent = PdfColor.fromInt(0xFF0B6E99);
  static const PdfColor amber = PdfColor.fromInt(0xFFB87900);
  static const PdfColor ink = PdfColor.fromInt(0xFF14181D);
  static const PdfColor muted = PdfColor.fromInt(0xFF5B6470);
  static const PdfColor line = PdfColor.fromInt(0xFFDDE2E7);
  static const PdfColor panel = PdfColor.fromInt(0xFFF3F5F7);
  static const PdfColor warning = PdfColor.fromInt(0xFFB3261E);

  pw.TextStyle get brand => pw.TextStyle(
    font: medium,
    fontSize: 9,
    color: accent,
    letterSpacing: 1.6,
  );

  pw.TextStyle get title => const pw.TextStyle(
    fontSize: 22,
    fontWeight: pw.FontWeight.bold,
    color: ink,
  );

  pw.TextStyle get heading => const pw.TextStyle(
    fontSize: 11,
    fontWeight: pw.FontWeight.bold,
    color: ink,
  );

  pw.TextStyle get label =>
      pw.TextStyle(font: medium, fontSize: 7.5, color: muted);

  pw.TextStyle get value => const pw.TextStyle(fontSize: 8.5, color: ink);

  pw.TextStyle get small => const pw.TextStyle(fontSize: 7.5, color: muted);
}

pw.Widget _runningHeader(ReportJob job, _Styles s) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    padding: const pw.EdgeInsets.only(bottom: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _Styles.line)),
    ),
    child: pw.Row(
      children: [
        pw.Text('GPS CAMERA', style: s.brand),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Text(
            job.title,
            style: s.small,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _footer(pw.Context context, ReportJob job, _Styles s) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 8),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Generated ${_localTime(job.generatedAt)}', style: s.small),
        pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: s.small,
        ),
      ],
    ),
  );
}

pw.Widget _summary(ReportJob job, _Styles s, int missingImages) {
  final entries = job.entries;
  int count(LocationRecordStatus status) =>
      entries.where((e) => e.metadata?.location.status == status).length;
  final noMetadata = entries.where((e) => e.metadata == null).length;
  final originalsMissing = entries.where((e) => !e.originalAvailable).length;

  final rows = <(String, String)>[
    ('Report type', job.type.label),
    if (job.projectName != null) ('Project', job.projectName!),
    ('Generated', _localTime(job.generatedAt)),
    ('Photos', '${entries.length}'),
    (
      'Watermarked versions',
      job.type == ReportType.project
          ? '${job.watermarkedVersionCount}'
          : '${job.watermarkedVersionCount} (of the included photos)',
    ),
    ('Current location', '${count(LocationRecordStatus.current)}'),
    ('Last known location', '${count(LocationRecordStatus.stale)}'),
    ('No location recorded', '${count(LocationRecordStatus.unavailable)}'),
    if (noMetadata > 0) ('Metadata unavailable', '$noMetadata'),
    if (originalsMissing > 0) ('Original file deleted', '$originalsMissing'),
    if (missingImages > 0) ('Image files missing', '$missingImages'),
  ];

  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 18),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('GPS CAMERA', style: s.brand),
        pw.SizedBox(height: 6),
        pw.Text(job.projectName ?? job.title, style: s.title, maxLines: 3),
        if (job.projectDescription?.isNotEmpty ?? false) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            job.projectDescription!,
            style: s.value.copyWith(color: _Styles.muted),
            maxLines: 6,
          ),
        ],
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: const pw.BoxDecoration(
            color: _Styles.panel,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            children: [
              for (final (label, value) in rows)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 130,
                        child: pw.Text(label, style: s.label),
                      ),
                      pw.Expanded(
                        child: pw.Text(value, style: s.value, maxLines: 3),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'All values come from the metadata recorded when each photo was '
          'taken. Capture times are shown in the time zone recorded at '
          'capture. Coordinates and GPS accuracy are reproduced as recorded; '
          'accuracy is the device\'s own estimate. Altitude is shown with '
          'its reference: on Android it is height above the WGS84 ellipsoid, '
          'not sea level. Missing values are marked Unavailable.',
          style: s.small,
        ),
      ],
    ),
  );
}

pw.Widget _entryBlock(
  int number,
  ReportEntry entry,
  List<(ReportImage, Uint8List?)> images,
  ReportType type,
  _Styles s,
) {
  final rows = reportEntryRows(entry, type);

  // Inseparable: a photo's block moves to the next page whole instead of
  // being split between pages.
  return pw.Inseparable(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _Styles.line),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                '#$number',
                style: s.heading.copyWith(color: _Styles.accent),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Text(
                  entry.fileName,
                  style: s.heading,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(width: 196, child: _images(images, s)),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    for (final (label, value, warn) in rows)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 1.6),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.SizedBox(
                              width: 92,
                              child: pw.Text(label, style: s.label),
                            ),
                            pw.Expanded(
                              child: pw.Text(
                                value,
                                style: warn
                                    ? s.value.copyWith(color: _Styles.warning)
                                    : s.value,
                                maxLines: 4,
                                overflow: pw.TextOverflow.clip,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

pw.Widget _images(List<(ReportImage, Uint8List?)> images, _Styles s) {
  if (images.isEmpty) return _missingImage('No image', s);
  final width = images.length == 1 ? 196.0 : 95.0;
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final (image, bytes) in images)
        pw.SizedBox(
          width: width,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                height: 210,
                width: width,
                alignment: pw.Alignment.center,
                color: _Styles.panel,
                child: bytes == null
                    ? _missingImage('Image file missing', s)
                    : pw.Image(pw.MemoryImage(bytes)),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                image.role == ReportImageRole.original
                    ? 'Original'
                    : 'Watermarked',
                style: s.small.copyWith(
                  color: image.role == ReportImageRole.original
                      ? _Styles.muted
                      : _Styles.amber,
                ),
                maxLines: 2,
                overflow: pw.TextOverflow.clip,
              ),
            ],
          ),
        ),
    ],
  );
}

pw.Widget _missingImage(String text, _Styles s) => pw.Container(
  height: 210,
  alignment: pw.Alignment.center,
  child: pw.Text(text, style: s.small, textAlign: pw.TextAlign.center),
);

/// The detail rows shown for one photo: (label, value, highlight). Values
/// come only from stored metadata; anything missing reads "Unavailable".
/// Public so tests can check the exact text the PDF shows.
List<(String, String, bool)> reportEntryRows(
  ReportEntry entry,
  ReportType type,
) {
  final metadata = entry.metadata;
  return <(String, String, bool)>[
    (
      'Captured',
      metadata == null
          ? 'Unavailable'
          : PhotoInfoFormatter.captureFull(metadata),
      false,
    ),
    (
      'Original file',
      entry.originalAvailable
          ? entry.fileName
          : '${entry.fileName} (original deleted)',
      !entry.originalAvailable,
    ),
    if (type == ReportType.selection)
      ('Project', entry.projectName ?? 'None', false),
    if (metadata == null)
      ('Metadata', entry.metadataProblem ?? 'Unavailable', true)
    else
      ..._locationRows(metadata),
    ..._watermarkRows(entry),
    if (entry.otherSelectedCopies.isNotEmpty)
      ('Also selected', entry.otherSelectedCopies.join(', '), false),
  ];
}

List<(String, String, bool)> _locationRows(PhotoMetadata metadata) {
  final location = metadata.location;
  final fix = location.fix;
  final status = switch (location.status) {
    LocationRecordStatus.current => 'Current',
    LocationRecordStatus.stale => 'Stale (last known location)',
    LocationRecordStatus.unavailable =>
      'Unavailable (${_reason(location.reason)})',
  };
  return [
    (
      'Location status',
      status,
      location.status != LocationRecordStatus.current,
    ),
    if (fix == null) ...[
      ('Latitude', 'Unavailable', false),
      ('Longitude', 'Unavailable', false),
      ('GPS accuracy', 'Unavailable', false),
    ] else ...[
      ('Latitude', '${fix.latitude}°', false),
      ('Longitude', '${fix.longitude}°', false),
      (
        'GPS accuracy',
        '±${PhotoInfoFormatter.length(fix.accuracy)} '
            '(${_level(GpsAccuracyLevel.fromMeters(fix.accuracy))})',
        GpsAccuracyLevel.fromMeters(fix.accuracy) == GpsAccuracyLevel.poor,
      ),
      if (location.fixAge != null)
        (
          'Fix age',
          '${CaptureTimeFormatter.age(location.fixAge!)} before capture',
          false,
        ),
      if (fix.altitude != null) ('Altitude', _altitude(fix), false),
      if (fix.heading != null)
        (
          'Direction of travel',
          '${PhotoInfoFormatter.measured(fix.heading!, maxDecimals: 1)}°',
          false,
        ),
      ..._placeRows(metadata.place, fix),
      if (fix.isMocked) ('Source', 'Mock location provider', true),
    ],
  ];
}

List<(String, String, bool)> _watermarkRows(ReportEntry entry) {
  if (entry.watermarks.isEmpty) return const [('Watermark', 'None', false)];
  final latest = entry.watermarks.first;
  final count = entry.watermarks.length;
  final config = latest.config;
  return [
    (
      'Watermark',
      '$count version${count == 1 ? '' : 's'} · latest ${latest.fileName}'
          '${latest.renderedAt == null ? '' : ', rendered ${_localTime(latest.renderedAt!)}'}',
      false,
    ),
    (
      'Watermark settings',
      config == null ? 'Unavailable (render record missing)' : _config(config),
      config == null,
    ),
  ];
}

List<(String, String, bool)> _placeRows(PlaceInfo? place, LocationFix fix) {
  if (place == null) {
    return [if (fix.address != null) ('Address', fix.address!, false)];
  }
  return [
    if (place.title != null) ('Place', place.title!, false),
    (
      'Address',
      place.addressLine ?? 'Unavailable (no address found)',
      place.addressLine == null,
    ),
    ('Plus Code', place.plusCode, false),
  ];
}

String _config(WatermarkConfig c) {
  final shown = [
    if (c.showDate) 'date',
    if (c.showTime) 'time',
    if (c.showCoordinates) 'coordinates',
    if (c.showAccuracy) 'accuracy',
    if (c.showAddress) 'address (when recorded)',
  ];
  final position = switch (c.position) {
    WatermarkPosition.bottomLeft => 'bottom left',
    WatermarkPosition.bottomCenter => 'bottom center',
    WatermarkPosition.bottomRight => 'bottom right',
  };
  return '${c.template.label} · $position · ${c.textSize.name} text · '
      '${(c.opacity * 100).round()}% opacity · shows '
      '${shown.isEmpty ? 'nothing' : shown.join(', ')}';
}

String _altitude(LocationFix fix) {
  final reference = switch (fix.altitudeReference) {
    AltitudeReference.wgs84Ellipsoid => 'above WGS84 ellipsoid (not sea level)',
    AltitudeReference.meanSeaLevel => 'above mean sea level',
    null => 'reference unknown',
  };
  final accuracy = fix.altitudeAccuracy == null
      ? ''
      : ', ±${PhotoInfoFormatter.length(fix.altitudeAccuracy!)}';
  return '${PhotoInfoFormatter.length(fix.altitude!)} $reference$accuracy';
}

String _level(GpsAccuracyLevel level) => switch (level) {
  GpsAccuracyLevel.good => 'Good',
  GpsAccuracyLevel.moderate => 'Moderate',
  GpsAccuracyLevel.poor => 'Poor',
};

String _reason(LocationUnavailableReason? reason) => switch (reason) {
  LocationUnavailableReason.permissionDenied => 'permission denied',
  LocationUnavailableReason.locationServicesDisabled => 'location services off',
  LocationUnavailableReason.noFixYet => 'no GPS fix yet',
  LocationUnavailableReason.gpsUnavailable => 'GPS unavailable',
  null => 'not recorded',
};

/// Report generation time in the device zone, with its UTC offset.
String _localTime(DateTime time) {
  final local = time.toLocal();
  final wall = CaptureTimeFormatter.wallClock(local, local.timeZoneOffset);
  return '${CaptureTimeFormatter.date(wall)} · '
      '${CaptureTimeFormatter.time(wall)} '
      '(${CaptureTimeFormatter.utcOffset(local.timeZoneOffset)})';
}
