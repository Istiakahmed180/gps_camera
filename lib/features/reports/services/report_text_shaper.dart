import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:gps_camera/features/reports/services/report_text.dart';

/// Draws report text with Flutter's text engine, which joins Bangla, Hindi
/// and Arabic letters correctly. Runs on the main isolate.
class ReportTextShaper {
  /// Pixels per PDF point: sharp when printed (about 300 dpi).
  static const double scale = 4;

  static Future<List<ShapedText?>> shape(List<TextRequest> requests) async {
    final out = <ShapedText?>[];
    for (final request in requests) {
      try {
        out.add(await _draw(request));
      } catch (_) {
        out.add(null);
      }
    }
    return out;
  }

  static Future<ShapedText> _draw(TextRequest r) async {
    final weight = switch (r.weight) {
      >= 700 => FontWeight.w700,
      >= 500 => FontWeight.w500,
      _ => FontWeight.w400,
    };
    final direction = r.rtl ? TextDirection.rtl : TextDirection.ltr;
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textDirection: direction,
              textAlign: r.center ? TextAlign.center : TextAlign.start,
              maxLines: r.maxLines,
              ellipsis: r.maxLines == null ? null : '…',
              fontSize: r.fontSize,
              fontWeight: weight,
              height: 1.25,
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: Color(r.color),
              fontSize: r.fontSize,
              fontWeight: weight,
              letterSpacing: r.letterSpacing,
              height: 1.25,
            ),
          )
          ..addText(r.text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: r.maxWidth));

    // One line that is not centred: crop to the text so it lines up like
    // the PDF's own text; otherwise keep the full width.
    final oneLine = paragraph.computeLineMetrics().length <= 1 && !r.center;
    final width = oneLine
        ? math.min(r.maxWidth, paragraph.longestLine.ceilToDouble() + 1)
        : r.maxWidth;
    final height = paragraph.height.ceilToDouble();
    final inset = (r.fontSize * 0.5).ceilToDouble();
    final dx = inset + (oneLine && r.rtl ? width - r.maxWidth : 0.0);

    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
      ..scale(scale)
      ..drawParagraph(paragraph, Offset(dx, 0));
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      ((width + inset * 2) * scale).ceil(),
      math.max(1, (height * scale).ceil()),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    paragraph.dispose();
    return ShapedText(
      data!.buffer.asUint8List(),
      width + inset * 2,
      height,
      inset: inset,
    );
  }
}
