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
import 'package:gps_camera/app/i18n/bn/bn.dart';
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/database/database_service.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/location/services/location_service.dart';
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
}

String _reportDate(DateTime day) => CaptureTimeFormatter.date(day);
