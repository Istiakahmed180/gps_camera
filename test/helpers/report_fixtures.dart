import 'dart:io';

import 'package:gps_camera/features/reports/services/pdf_report_renderer.dart';

/// The bundled fonts, read straight from the repo.
ReportFonts testReportFonts() => ReportFonts(
  regular: File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync(),
  medium: File('assets/fonts/Roboto-Medium.ttf').readAsBytesSync(),
  bold: File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync(),
);

/// Text of all uncompressed-or-not PDF objects is not directly searchable
/// (streams are deflated), so tests check structure via the page count and
/// the PDF header, and content via the report model.
bool looksLikePdf(File file) {
  final head = file.openSync()..setPositionSync(0);
  final bytes = head.readSync(5);
  head.closeSync();
  return String.fromCharCodes(bytes) == '%PDF-';
}
