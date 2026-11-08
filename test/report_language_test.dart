import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/i18n/app_language.dart';
import 'package:gps_camera/app/i18n/app_translations.dart';
import 'package:gps_camera/app/i18n/bn/bn.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/reports/models/report_models.dart';
import 'package:gps_camera/features/reports/services/pdf_report_renderer.dart';
import 'package:gps_camera/features/reports/services/report_service.dart';
import 'package:gps_camera/features/reports/services/report_text.dart';
import 'package:gps_camera/features/reports/services/report_text_shaper.dart';
import 'package:image/image.dart' as img;

import 'helpers/report_fixtures.dart';
import 'helpers/test_env.dart';
import 'helpers/watermark_fixtures.dart';

PhotoMetadata _at(double lat, double lng) => fixtureMetadata(
  location: LocationSnapshot.current(
    testFix(latitude: lat, longitude: lng),
    Duration.zero,
  ),
);

ReportJob _job({ReportLanguage language = const ReportLanguage()}) => ReportJob(
  type: ReportType.project,
  title: 'Site visit',
  projectName: 'Site visit',
  generatedAt: DateTime(2026, 11, 7, 12),
  language: language,
  entries: [
    ReportEntry(
      fileName: 'IMG_1.jpg',
      originalAvailable: true,
      images: const [],
      metadata: _at(23.91, 90.40),
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  final png = Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 2)));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zz_report_language');
    Get.addTranslations(AppTranslations().keys);
  });

  tearDown(() async {
    Get.locale = AppLanguage.english.locale;
    await dir.delete(recursive: true);
  });

  Future<List<TextRequest>> render(ReportJob job) async {
    final requests = <TextRequest>[];
    final path = '${dir.path}/report.pdf';
    await renderReportPdf(
      job,
      testReportFonts(),
      path,
      shaper: (batch) async {
        requests.addAll(batch);
        return [for (final _ in batch) ShapedText(png, 20, 10)];
      },
    );
    expect(looksLikePdf(File(path)), isTrue);
    return requests;
  }

  test('only text the PDF library cannot shape is drawn', () {
    expect(needsShaping('Latitude 23.91° ± 4 m · …'), isFalse);
    expect(needsShaping('অক্ষাংশ'), isTrue);
    expect(needsShaping('अक्षांश'), isTrue);
    expect(needsShaping('خط العرض'), isTrue);
  });

  test('the report follows the app language', () {
    Get.locale = AppLanguage.bangla.locale;
    final bangla = ReportService.currentLanguage();
    expect(bangla.languageCode, 'bn');
    expect(bangla.strings, same(bn));

    Get.locale = AppLanguage.english.locale;
    expect(ReportService.currentLanguage().strings, isEmpty);
  });

  test('a Bangla report draws Bangla text; numbers stay PDF text', () async {
    Get.locale = AppLanguage.bangla.locale;
    final requests = await render(
      _job(language: ReportService.currentLanguage()),
    );
    final texts = requests.map((r) => r.text);
    expect(texts, contains(bn['Latitude']));
    expect(requests.every((r) => needsShaping(r.text)), isTrue);
    expect(requests.any((r) => r.rtl), isFalse);
    // Coordinates are plain text, so they stay searchable.
    expect(texts.any((t) => t.startsWith('23.91')), isFalse);
  });

  test('an English report needs no drawing', () async {
    final requests = await render(_job());
    expect(requests, isEmpty);
  });

  test('an Arabic report is laid out right to left', () async {
    Get.locale = AppLanguage.arabic.locale;
    final requests = await render(
      _job(language: ReportService.currentLanguage()),
    );
    expect(requests, isNotEmpty);
    expect(requests.every((r) => r.rtl), isTrue);
  });

  testWidgets('the shaper draws text as a sharp image of the right size', (
    tester,
  ) async {
    final shaped = await tester.runAsync(
      () => ReportTextShaper.shape(const [
        TextRequest(
          text: 'অক্ষাংশ',
          fontSize: 8.5,
          weight: 400,
          color: 0xFF14181D,
          letterSpacing: 0,
          maxWidth: 120,
          maxLines: 1,
          rtl: false,
          center: false,
        ),
        TextRequest(
          text: 'خط العرض',
          fontSize: 8.5,
          weight: 500,
          color: 0xFF14181D,
          letterSpacing: 0,
          maxWidth: 120,
          maxLines: 2,
          rtl: true,
          center: false,
        ),
      ]),
    );
    expect(shaped, hasLength(2));
    for (final s in shaped!) {
      expect(s, isNotNull);
      expect(s!.width - s.inset * 2, inInclusiveRange(1, 120));
      expect(s.inset, greaterThan(0));
      expect(s.height, greaterThan(8));
      final image = img.decodePng(s.png)!;
      expect(image.width, (s.width * ReportTextShaper.scale).ceil());
    }
  });
}
