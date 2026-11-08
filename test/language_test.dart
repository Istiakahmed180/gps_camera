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
import 'package:gps_camera/app/i18n/bn/bn.dart';
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/database/database_service.dart';
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
}

String _reportDate(DateTime day) => CaptureTimeFormatter.date(day);
