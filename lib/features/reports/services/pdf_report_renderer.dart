import 'dart:io';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:gps_camera/app/i18n/count_text.dart';
import 'package:gps_camera/core/utils/script.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/gallery/utils/photo_info_formatter.dart';
import 'package:gps_camera/features/location/models/gps_accuracy_level.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/location/models/place_info.dart';
import 'package:gps_camera/features/reports/models/report_map.dart';
import 'package:gps_camera/features/reports/models/report_models.dart';
import 'package:gps_camera/features/reports/services/report_text.dart';
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
///
/// Text is written in the language set by `Get.locale`. The PDF library
/// cannot join Bangla, Hindi or Arabic letters, so [shaper] draws that text
/// (on the main isolate) and it is placed as images; without a shaper it
/// falls back to plain PDF text.
Future<ReportRenderStats> renderReportPdf(
  ReportJob job,
  ReportFonts fonts,
  String outputPath, {
  void Function(ReportProgress progress)? onProgress,
  TextShaper? shaper,
}) async {
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(fonts.regular.buffer.asByteData()),
    bold: pw.Font.ttf(fonts.bold.buffer.asByteData()),
  );
  final medium = pw.Font.ttf(fonts.medium.buffer.asByteData());
  final style = _Styles(medium);
  final large = job.entries.length > 60;
  final rtl = job.language.isRtl;

  final prepared = <List<(ReportImage, Uint8List?)>>[];
  var images = 0;
  var missing = 0;
  for (final (i, entry) in job.entries.indexed) {
    final entryImages = <(ReportImage, Uint8List?)>[];
    for (final image in entry.images) {
      final bytes = _prepareImage(image.path, maxSide: large ? 640 : 900);
      bytes == null ? missing++ : images++;
      entryImages.add((image, bytes));
    }
    prepared.add(entryImages);
    onProgress?.call(ReportProgress(i + 1, job.entries.length));
  }

  List<pw.Widget> content(_Tx tx) => [
    _summary(job, style, missing, tx),
    ?_overview(job, style, tx),
    for (final (i, entry) in job.entries.indexed)
      _entryBlock(i + 1, entry, prepared[i], job.type, style, tx),
  ];

  // First pass: find the text that has to be drawn, and draw it.
  final collect = _Tx(rtl: rtl);
  content(collect);
  _runningHeader(job, style, collect);
  _generatedLine(job, style, collect);
  final requests = collect.requests.toList();
  final shapes = shaper == null || requests.isEmpty
      ? const <ShapedText?>[]
      : await shaper(requests);
  final tx = _Tx(
    rtl: rtl,
    shaped: {
      for (final (i, request) in requests.indexed)
        if (i < shapes.length && shapes[i] != null) request: shapes[i]!,
    },
  );

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
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : _runningHeader(job, style, tx),
      footer: (context) => _footer(context, job, style, tx),
      build: (context) => content(tx),
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

/// Places text: plain PDF text where the PDF library can draw it, otherwise
/// the shaped image. Without [shaped] it only records what needs shaping.
class _Tx {
  _Tx({required this.rtl, this.shaped});

  final bool rtl;
  final Map<TextRequest, ShapedText>? shaped;
  final Set<TextRequest> requests = {};
  final Map<TextRequest, pw.MemoryImage> _images = {};

  pw.Widget call(
    String text,
    pw.TextStyle style, {
    required double width,
    int? maxLines,
    bool center = false,
  }) {
    if (!needsShaping(text)) {
      return pw.Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: maxLines == null ? null : pw.TextOverflow.clip,
        textAlign: center ? pw.TextAlign.center : null,
      );
    }
    final request = TextRequest(
      // Numbers and units keep their order inside Arabic text.
      text: keepLtrRuns(text, rtl: rtl),
      fontSize: style.fontSize ?? 8.5,
      weight: style.fontWeight == pw.FontWeight.bold
          ? 700
          : (style.font != null ? 500 : 400),
      color: (style.color ?? _Styles.ink).toInt(),
      letterSpacing: style.letterSpacing ?? 0,
      maxWidth: width,
      maxLines: maxLines,
      rtl: rtl,
      center: center,
    );
    final shapes = shaped;
    if (shapes == null) {
      requests.add(request);
      return pw.SizedBox();
    }
    final shape = shapes[request];
    if (shape == null) {
      return pw.Text(text, style: style, maxLines: maxLines);
    }
    final image = _images[request] ??= pw.MemoryImage(shape.png);
    return pw.Align(
      alignment: center
          ? pw.Alignment.topCenter
          : (rtl ? pw.Alignment.topRight : pw.Alignment.topLeft),
      // Sized to the text; the blank inset around it spills over.
      child: pw.SizedBox(
        width: shape.width - shape.inset * 2,
        height: shape.height,
        child: pw.OverflowBox(
          maxWidth: shape.width,
          child: pw.Image(image, width: shape.width, height: shape.height),
        ),
      ),
    );
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

/// A4 width minus the 36 pt left and right margins.
final double _contentWidth = PdfPageFormat.a4.width - 72;

/// Table cells clip their content, so leave room for marks that reach
/// past the text (like the Bangla ি).
const _cellPadding = pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3);

/// Inside a photo block: its padding and border.
final double _blockWidth = _contentWidth - 22;

/// The value column next to a photo's images and labels.
final double _entryValueWidth = _blockWidth - 196 - 12 - 92;

pw.Widget _runningHeader(ReportJob job, _Styles s, _Tx tx) {
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
          child: tx(job.title, s.small, width: _contentWidth - 80, maxLines: 1),
        ),
      ],
    ),
  );
}

pw.Widget _generatedLine(ReportJob job, _Styles s, _Tx tx) => tx(
  'Generated @time'.trParams({'time': _localTime(job.generatedAt)}),
  s.small,
  width: _contentWidth * 0.75,
  maxLines: 1,
);

pw.Widget _footer(pw.Context context, ReportJob job, _Styles s, _Tx tx) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 8),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Flexible(child: _generatedLine(job, s, tx)),
        pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: s.small,
        ),
      ],
    ),
  );
}

pw.Widget _summary(ReportJob job, _Styles s, int missingImages, _Tx tx) {
  final entries = job.entries;
  int count(LocationRecordStatus status) =>
      entries.where((e) => e.metadata?.location.status == status).length;
  final noMetadata = entries.where((e) => e.metadata == null).length;
  final originalsMissing = entries.where((e) => !e.originalAvailable).length;

  final rows = <(String, String)>[
    ('Report type'.tr, job.type.label.tr),
    if (job.projectName != null) ('Project'.tr, job.projectName!),
    ('Generated'.tr, _localTime(job.generatedAt)),
    ('Photos'.tr, '${entries.length}'),
    (
      'Watermarked versions'.tr,
      job.type == ReportType.project
          ? '${job.watermarkedVersionCount}'
          : '@n (of the included photos)'.trParams({
              'n': '${job.watermarkedVersionCount}',
            }),
    ),
    ('Current location'.tr, '${count(LocationRecordStatus.current)}'),
    ('Last known location'.tr, '${count(LocationRecordStatus.stale)}'),
    ('No location recorded'.tr, '${count(LocationRecordStatus.unavailable)}'),
    if (noMetadata > 0) ('Metadata unavailable'.tr, '$noMetadata'),
    if (originalsMissing > 0) ('Original file deleted'.tr, '$originalsMissing'),
    if (missingImages > 0) ('Image files missing'.tr, '$missingImages'),
  ];
  const labelWidth = 130.0;
  final valueWidth = _contentWidth - 24 - labelWidth;

  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 18),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('GPS CAMERA', style: s.brand),
        pw.SizedBox(height: 6),
        tx(
          job.projectName ?? job.title,
          s.title,
          width: _contentWidth,
          maxLines: 3,
        ),
        if (job.projectDescription?.isNotEmpty ?? false) ...[
          pw.SizedBox(height: 6),
          tx(
            job.projectDescription!,
            s.value.copyWith(color: _Styles.muted),
            width: _contentWidth,
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
                        width: labelWidth,
                        child: tx(label, s.label, width: labelWidth - 4),
                      ),
                      pw.Expanded(
                        child: tx(
                          value,
                          s.value,
                          width: valueWidth,
                          maxLines: 3,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        tx(
          ('All values come from the metadata recorded when each photo was '
                  'taken. Capture times are shown in the time zone recorded at '
                  'capture. Coordinates and GPS accuracy are reproduced as '
                  'recorded; accuracy is the device\'s own estimate. Altitude '
                  'is shown with its reference: on Android it is height above '
                  'the WGS84 ellipsoid, not sea level. Missing values are '
                  'marked Unavailable.')
              .tr,
          s.small,
          width: _contentWidth,
        ),
      ],
    ),
  );
}

/// Where the photos were taken: the map with numbered pins (numbers match
/// the # of each photo below), and which photos each pin stands for.
pw.Widget? _overview(ReportJob job, _Styles s, _Tx tx) {
  final map = job.map;
  if (map == null) {
    if (!job.mapUnavailable) return null;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: tx(
        ('Location map not included: there was no internet connection when '
                'this report was made.')
            .tr,
        s.small,
        width: _contentWidth,
      ),
    );
  }

  String photos(List<int> entries) {
    if (entries.length == 1) return '#${entries.single}';
    final shown = entries.take(12).map((n) => '#$n').join(', ');
    return entries.length > 12
        ? '@shown and @n more'.trParams({
            'shown': shown,
            'n': '${entries.length - 12}',
          })
        : shown;
  }

  const pinWidth = 40.0;
  final photosWidth = (_contentWidth - pinWidth) * 3 / 7;
  final placeWidth = (_contentWidth - pinWidth) * 4 / 7;
  final widths = [pinWidth, photosWidth, placeWidth];
  final note = [
    'Pin numbers match the photo numbers below. Photos taken within '
            '@radius m of each other share a pin.'
        .trParams({'radius': '${ReportMapPins.radiusMeters.round()}'}),
    if (map.omitted > 0)
      '@n more location is not shown on the map.'.trCount(
        '@n more locations are not shown on the map.',
        map.omitted,
        {'n': '${map.omitted}'},
      ),
  ].join(' ');

  return pw.Inseparable(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          tx('Locations'.tr, s.heading, width: _contentWidth),
          pw.SizedBox(height: 6),
          pw.ClipRRect(
            horizontalRadius: 6,
            verticalRadius: 6,
            // A4 width minus the page margins; the map is 5:3.
            child: pw.Image(
              pw.MemoryImage(map.image),
              fit: pw.BoxFit.cover,
              width: _contentWidth,
              height: _contentWidth * 0.6,
            ),
          ),
          pw.SizedBox(height: 4),
          tx(note, s.small, width: _contentWidth),
          if (map.pins.any((p) => p.entries.length > 1) ||
              map.pins.length > 1) ...[
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: const {
                0: pw.FixedColumnWidth(pinWidth),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(4),
              },
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: _Styles.line),
              ),
              children: [
                pw.TableRow(
                  children: [
                    for (final (i, h) in ['PIN', 'PHOTOS', 'PLACE'].indexed)
                      pw.Padding(
                        padding: _cellPadding,
                        child: tx(h.tr, s.label, width: widths[i] - 8),
                      ),
                  ],
                ),
                for (final pin in map.pins)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: _cellPadding,
                        child: pw.Text(
                          '${pin.label}',
                          style: s.value.copyWith(color: _Styles.accent),
                        ),
                      ),
                      pw.Padding(
                        padding: _cellPadding,
                        child: tx(
                          photos(pin.entries),
                          s.value,
                          width: photosWidth - 8,
                        ),
                      ),
                      pw.Padding(
                        padding: _cellPadding,
                        child: tx(
                          pin.place ??
                              '${pin.latitude.toStringAsFixed(5)}, '
                                  '${pin.longitude.toStringAsFixed(5)}',
                          s.value,
                          width: placeWidth - 8,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

pw.Widget _entryBlock(
  int number,
  ReportEntry entry,
  List<(ReportImage, Uint8List?)> images,
  ReportType type,
  _Styles s,
  _Tx tx,
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
                child: tx(
                  entry.fileName,
                  s.heading,
                  width: _blockWidth - 40,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(width: 196, child: _images(images, s, tx)),
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
                              child: tx(label, s.label, width: 88),
                            ),
                            pw.Expanded(
                              child: tx(
                                value,
                                warn
                                    ? s.value.copyWith(color: _Styles.warning)
                                    : s.value,
                                width: _entryValueWidth,
                                maxLines: 4,
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

pw.Widget _images(List<(ReportImage, Uint8List?)> images, _Styles s, _Tx tx) {
  if (images.isEmpty) return _missingImage('No image'.tr, 196, s, tx);
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
                    ? _missingImage('Image file missing'.tr, width, s, tx)
                    : pw.Image(pw.MemoryImage(bytes)),
              ),
              pw.SizedBox(height: 3),
              tx(
                image.role == ReportImageRole.original
                    ? 'Original'.tr
                    : 'Watermarked'.tr,
                s.small.copyWith(
                  color: image.role == ReportImageRole.original
                      ? _Styles.muted
                      : _Styles.amber,
                ),
                width: width,
                maxLines: 2,
              ),
            ],
          ),
        ),
    ],
  );
}

pw.Widget _missingImage(String text, double width, _Styles s, _Tx tx) =>
    pw.Container(
      height: 210,
      alignment: pw.Alignment.center,
      child: tx(text, s.small, width: width - 8, center: true),
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
      'Captured'.tr,
      metadata == null
          ? 'Unavailable'.tr
          : PhotoInfoFormatter.captureFull(metadata),
      false,
    ),
    if (metadata?.note != null) ('Note'.tr, metadata!.note!, false),
    (
      'Original file'.tr,
      entry.originalAvailable
          ? entry.fileName
          : '@file (original deleted)'.trParams({'file': entry.fileName}),
      !entry.originalAvailable,
    ),
    if (type == ReportType.selection)
      ('Project'.tr, entry.projectName ?? 'None'.tr, false),
    if (metadata == null)
      ('Metadata'.tr, entry.metadataProblem?.tr ?? 'Unavailable'.tr, true)
    else
      ..._locationRows(metadata),
    if (metadata?.direction != null)
      ('Camera direction'.tr, metadata!.direction!.description, false),
    ..._watermarkRows(entry),
    if (entry.otherSelectedCopies.isNotEmpty)
      ('Also selected'.tr, entry.otherSelectedCopies.join(', '), false),
  ];
}

List<(String, String, bool)> _locationRows(PhotoMetadata metadata) {
  final location = metadata.location;
  final fix = location.fix;
  final status = switch (location.status) {
    LocationRecordStatus.current => 'Current'.tr,
    LocationRecordStatus.stale => 'Stale (last known location)'.tr,
    LocationRecordStatus.unavailable => 'Unavailable (@reason)'.trParams({
      'reason': _reason(location.reason),
    }),
  };
  return [
    (
      'Location status'.tr,
      status,
      location.status != LocationRecordStatus.current,
    ),
    if (fix == null) ...[
      ('Latitude'.tr, 'Unavailable'.tr, false),
      ('Longitude'.tr, 'Unavailable'.tr, false),
      ('GPS accuracy'.tr, 'Unavailable'.tr, false),
    ] else ...[
      ('Latitude'.tr, '${fix.latitude}°', false),
      ('Longitude'.tr, '${fix.longitude}°', false),
      (
        'GPS accuracy'.tr,
        '±${PhotoInfoFormatter.length(fix.accuracy)} '
            '(${_level(GpsAccuracyLevel.fromMeters(fix.accuracy))})',
        GpsAccuracyLevel.fromMeters(fix.accuracy) == GpsAccuracyLevel.poor,
      ),
      if (location.fixAge != null)
        (
          'Fix age'.tr,
          '@age before capture'.trParams({
            'age': CaptureTimeFormatter.age(location.fixAge!),
          }),
          false,
        ),
      if (fix.altitude != null) ('Altitude'.tr, _altitude(fix), false),
      if (fix.heading != null)
        (
          'Direction of travel'.tr,
          '${PhotoInfoFormatter.measured(fix.heading!, maxDecimals: 1)}°',
          false,
        ),
      ..._placeRows(metadata.place, fix),
      if (fix.isMocked) ('Source'.tr, 'Mock location provider'.tr, true),
    ],
  ];
}

List<(String, String, bool)> _watermarkRows(ReportEntry entry) {
  if (entry.watermarks.isEmpty) {
    return [('Watermark'.tr, 'None'.tr, false)];
  }
  final latest = entry.watermarks.first;
  final count = entry.watermarks.length;
  final config = latest.config;
  final versions = '@n version · latest @file'.trCount(
    '@n versions · latest @file',
    count,
    {'n': '$count', 'file': latest.fileName},
  );
  return [
    (
      'Watermark'.tr,
      latest.renderedAt == null
          ? versions
          : '@versions, rendered @time'.trParams({
              'versions': versions,
              'time': _localTime(latest.renderedAt!),
            }),
      false,
    ),
    (
      'Watermark settings'.tr,
      config == null
          ? 'Unavailable (render record missing)'.tr
          : _config(config),
      config == null,
    ),
  ];
}

List<(String, String, bool)> _placeRows(PlaceInfo? place, LocationFix fix) {
  if (place == null) {
    return [if (fix.address != null) ('Address'.tr, fix.address!, false)];
  }
  return [
    if (place.title != null) ('Place'.tr, place.title!, false),
    (
      'Address'.tr,
      place.addressLine ?? 'Unavailable (no address found)'.tr,
      place.addressLine == null,
    ),
    ('Plus Code'.tr, place.plusCode, false),
  ];
}

String _config(WatermarkConfig c) {
  final shown = [
    if (c.showDate) 'date'.tr,
    if (c.showTime) 'time'.tr,
    if (c.showCoordinates) 'coordinates'.tr,
    if (c.showAccuracy) 'accuracy'.tr,
    if (c.showAddress) 'address (when recorded)'.tr,
  ];
  final position = switch (c.position) {
    WatermarkPosition.bottomLeft => 'bottom left'.tr,
    WatermarkPosition.bottomCenter => 'bottom center'.tr,
    WatermarkPosition.bottomRight => 'bottom right'.tr,
  };
  final size = switch (c.textSize) {
    WatermarkTextSize.small => 'small text'.tr,
    WatermarkTextSize.medium => 'medium text'.tr,
    WatermarkTextSize.large => 'large text'.tr,
  };
  return [
    c.template.label.tr,
    position,
    size,
    '@n% opacity'.trParams({'n': '${(c.opacity * 100).round()}'}),
    'shows @items'.trParams({
      'items': shown.isEmpty ? 'nothing'.tr : shown.join(', '),
    }),
  ].join(' · ');
}

String _altitude(LocationFix fix) {
  final reference = switch (fix.altitudeReference) {
    AltitudeReference.wgs84Ellipsoid =>
      'above WGS84 ellipsoid (not sea level)'.tr,
    AltitudeReference.meanSeaLevel => 'above mean sea level'.tr,
    null => 'reference unknown'.tr,
  };
  final accuracy = fix.altitudeAccuracy == null
      ? ''
      : ', ±${PhotoInfoFormatter.length(fix.altitudeAccuracy!)}';
  return '${PhotoInfoFormatter.length(fix.altitude!)} $reference$accuracy';
}

String _level(GpsAccuracyLevel level) => switch (level) {
  GpsAccuracyLevel.good => 'Good'.tr,
  GpsAccuracyLevel.moderate => 'Moderate'.tr,
  GpsAccuracyLevel.poor => 'Poor'.tr,
};

String _reason(LocationUnavailableReason? reason) => switch (reason) {
  LocationUnavailableReason.permissionDenied => 'permission denied'.tr,
  LocationUnavailableReason.locationServicesDisabled =>
    'location services off'.tr,
  LocationUnavailableReason.noFixYet => 'no GPS fix yet'.tr,
  LocationUnavailableReason.gpsUnavailable => 'GPS unavailable'.tr,
  null => 'not recorded'.tr,
};

/// Report generation time in the device zone, with its UTC offset.
String _localTime(DateTime time) {
  final local = time.toLocal();
  final wall = CaptureTimeFormatter.wallClock(local, local.timeZoneOffset);
  return '${CaptureTimeFormatter.date(wall)} · '
      '${CaptureTimeFormatter.time(wall)} '
      '(${CaptureTimeFormatter.utcOffset(local.timeZoneOffset)})';
}
