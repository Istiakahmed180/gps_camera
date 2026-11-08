import 'dart:async';
import 'dart:isolate';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/app/app.dart';
import 'package:gps_camera/app/bindings/initial_binding.dart';
import 'package:gps_camera/app/i18n/app_language.dart';
import 'package:gps_camera/app/i18n/app_translations.dart';
import 'package:gps_camera/app/i18n/ar/ar.dart';
import 'package:gps_camera/app/i18n/ar/ar_plurals.dart';
import 'package:gps_camera/app/i18n/count_text.dart';
import 'package:gps_camera/app/i18n/bn/bn.dart';
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/database/database_service.dart';
import 'package:gps_camera/core/utils/script.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/location/services/location_service.dart';
import 'package:gps_camera/features/settings/views/language_view.dart';
import 'package:gps_camera/features/reports/services/report_service.dart';
import 'package:gps_camera/features/watermark/utils/capture_time_formatter.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await mockPathProvider();
    await GetStorage.init();
  });

  setUp(() async {
    await GetStorage().erase();
    await GetStorage().write(StorageKeys.onboardingDone, true);
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    Get.put(DatabaseService(NativeDatabase.memory()), permanent: true);
    Get.put<PermissionService>(FakePermissionService());
    Get.put<GalleryService>(FakeGalleryService(), permanent: true);
    Get.put<ReportService>(FakeReportService());
    Get.put<LocationService>(
      FakeLocationService(permission: PermissionAccess.denied),
    );
    InitialBinding().dependencies();
  });

  tearDown(Get.reset);

  /// Changing the locale waits for a redrawn frame, which a widget test
  /// only draws when pumped.
  Future<void> switchTo(WidgetTester tester, AppLanguage language) async {
    final done = Get.find<LanguageService>().setLanguage(language);
    await tester.pumpAndSettle();
    await done;
    await tester.pumpAndSettle();
  }

  test('System follows the phone: Bangla phones get Bangla', () {
    expect(
      LanguageService.resolve(AppLanguage.system, const Locale('bn', 'BD')),
      AppLanguage.bangla.locale,
    );
    expect(
      LanguageService.resolve(AppLanguage.system, const Locale('fr')),
      AppLanguage.fallback,
    );
    expect(
      LanguageService.resolve(AppLanguage.english, const Locale('bn')),
      AppLanguage.english.locale,
    );
  });

  testWidgets('switching language changes the screens and is remembered', (
    tester,
  ) async {
    await tester.pumpWidget(const GpsCameraApp());
    await tester.pumpAndSettle();
    expect(find.text('Open camera'), findsOneWidget);

    await switchTo(tester, AppLanguage.bangla);
    expect(find.text(bn['Open camera']!), findsOneWidget);
    expect(find.text('Open camera'), findsNothing);
    expect(GetStorage().read<String>(StorageKeys.language), 'bangla');

    // Dates on screen and on new watermarks follow the language.
    expect(
      CaptureTimeFormatter.date(DateTime.utc(2026, 11, 7)),
      '07 ${bn['Nov']} 2026',
    );

    await switchTo(tester, AppLanguage.english);
    expect(find.text('Open camera'), findsOneWidget);
  });

  test('PDF reports stay English: the background renderer has no '
      'translations', () async {
    Get.addTranslations({'bn_BD': bn});
    Get.locale = AppLanguage.bangla.locale;
    final day = DateTime.utc(2026, 11, 7);
    expect(CaptureTimeFormatter.date(day), '07 ${bn['Nov']} 2026');

    // Reports render in their own isolate, like this.
    final inReport = await Isolate.run(() => _reportDate(day));
    expect(inReport, '07 Nov 2026');
  });

  test('every Bangla text is filled in', () {
    for (final e in bn.entries) {
      expect(e.value.trim(), isNotEmpty, reason: e.key);
      final placeholders = RegExp(r'@\w+').allMatches(e.key).map((m) => m[0]);
      for (final p in placeholders) {
        expect(e.value, contains(p), reason: 'missing $p in "${e.key}"');
      }
    }
  });
  test('every language has the same texts, filled in, with placeholders', () {
    final tables = AppTranslations().keys;
    final keys = bn.keys.toSet();
    for (final language in AppLanguage.values) {
      final locale = language.locale;
      if (locale == null || locale.languageCode == 'en') continue;
      final table = tables['${locale.languageCode}_${locale.countryCode}'];
      expect(table, isNotNull, reason: '$language has no table');
      expect(table!.keys.toSet(), keys, reason: '$language keys');
      for (final e in table.entries) {
        expect(e.value.trim(), isNotEmpty, reason: '$language ${e.key}');
        for (final m in RegExp(r'@\w+').allMatches(e.key)) {
          expect(e.value, contains(m[0]), reason: '$language "${e.key}"');
        }
      }
    }
  });

  test('System picks the phone language when the app has it', () {
    expect(
      LanguageService.resolve(AppLanguage.system, const Locale('es', 'MX')),
      AppLanguage.spanish.locale,
    );
    expect(
      LanguageService.resolve(AppLanguage.system, const Locale('pt', 'PT')),
      AppLanguage.portuguese.locale,
    );
    expect(
      LanguageService.resolve(AppLanguage.system, const Locale('ar', 'EG')),
      AppLanguage.arabic.locale,
    );
    expect(AppLanguage.arabic.isRtl, isTrue);
    expect(AppLanguage.hindi.isRtl, isFalse);
  });

  testWidgets(
    'language screen lists every language and shows Arabic right to left',
    (tester) async {
      await tester.pumpWidget(const GpsCameraApp());
      await tester.pumpAndSettle();
      unawaited(Get.to<void>(() => const LanguageView()));
      await tester.pumpAndSettle();
      for (final language in AppLanguage.values.skip(1)) {
        await tester.scrollUntilVisible(
          find.text(language.label).first,
          80,
          scrollable: find
              .descendant(
                of: find.byType(LanguageView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text(language.label), findsWidgets);
      }

      await switchTo(tester, AppLanguage.arabic);
      expect(Get.find<LanguageService>().language.value, AppLanguage.arabic);
      expect(GetStorage().read<String>(StorageKeys.language), 'arabic');
      // Arabic screens are laid out right to left.
      expect(
        Directionality.of(tester.element(find.byType(LanguageView))),
        TextDirection.rtl,
      );
      await switchTo(tester, AppLanguage.system);
    },
  );
  test('Arabic keeps numbers and units in their order', () {
    const i = '\u2066', p = '\u2069';
    expect(keepLtrRuns('الاتجاه 240° SW', rtl: true), 'الاتجاه ${i}240° SW$p');
    expect(keepLtrRuns('دقة GPS: ±12 m', rtl: true), 'دقة ${i}GPS: ±12 m$p');
    // List items stay separate so they follow right-to-left order.
    expect(
      keepLtrRuns('07 نوفمبر 2026 · 11:58 ص', rtl: true),
      '${i}07$p نوفمبر ${i}2026$p · ${i}11:58$p ص',
    );
    expect(
      keepLtrRuns('23.91° N, 90.40° E', rtl: true),
      '${i}23.91° N, 90.40° E$p',
    );
    // Brackets stay paired.
    expect(
      keepLtrRuns('339° N (الشمال الحقيقي, ±10°)', rtl: true),
      '${i}339° N$p (الشمال الحقيقي, $i±10°$p)',
    );
    expect(
      keepLtrRuns('11:03 م (UTC+06:00)', rtl: true),
      '${i}11:03$p م $i(UTC+06:00)$p',
    );
    expect(keepLtrRuns('240° SW', rtl: false), '240° SW');
    expect(hasRtlLetters('العربية'), isTrue);
    expect(hasRtlLetters('23.91° N'), isFalse);
  });
  test('Arabic counts use the dual, 3 to 10 and 11-and-up forms', () {
    expect([0, 1, 2, 3, 10, 11, 99, 100, 102, 105].map(arabicCountForm), [
      'other',
      'one',
      'two',
      'few',
      'few',
      'other',
      'other',
      'other',
      'other',
      'few',
    ]);
    Get.addTranslations(AppTranslations().keys);
    String photos(int n) => '@n photo'.trCount('@n photos', n, {'n': '$n'});

    Get.locale = AppLanguage.arabic.locale;
    expect(photos(1), '1 صورة');
    expect(photos(2), 'صورتان');
    expect(photos(5), '5 صور');
    expect(photos(15), '15 صورة');
    expect(photos(100), '100 صورة');
    expect(
      'Deleted @removed, but @failed file could not be removed'.trCount(
        'Deleted @removed, but @failed files could not be removed',
        2,
        {'removed': '4', 'failed': '2'},
      ),
      'تم حذف 4، لكن تعذّر حذف ملفين',
    );

    Get.locale = AppLanguage.english.locale;
    expect(photos(2), '2 photos');
    expect(photos(1), '1 photo');
  });

  test('every Arabic count form belongs to a plural text', () {
    for (final MapEntry(key: key, value: forms) in arPlurals.entries) {
      expect(ar, contains(key), reason: key);
      final params = RegExp(r'@\w+').allMatches(key).map((m) => m[0]!);
      for (final MapEntry(key: form, value: text) in forms.entries) {
        expect(['two', 'few', 'other'], contains(form), reason: key);
        final missing = params.where((p) => !text.contains(p)).toList();
        // The dual names the counted number in the word itself.
        expect(
          missing.length,
          form == 'two' ? lessThanOrEqualTo(1) : 0,
          reason: '$form of "$key" misses $missing',
        );
      }
    }
  });
  test('time units follow the language', () {
    Get.addTranslations(AppTranslations().keys);
    Get.locale = AppLanguage.bangla.locale;
    expect(CaptureTimeFormatter.age(const Duration(seconds: 5)), '5 সে.');
    expect(CaptureTimeFormatter.age(const Duration(minutes: 3)), '3 মি.');
    Get.locale = AppLanguage.english.locale;
    expect(CaptureTimeFormatter.age(const Duration(seconds: 5)), '5 s');
    expect(CaptureTimeFormatter.age(Duration.zero), '<1 s');
  });
}

String _reportDate(DateTime day) => CaptureTimeFormatter.date(day);
