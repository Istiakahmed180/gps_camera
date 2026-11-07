import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/app/app.dart';
import 'package:gps_camera/app/bindings/initial_binding.dart';
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/database/database_service.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/location/services/location_service.dart';
import 'package:gps_camera/features/onboarding/onboarding_gate.dart';
import 'package:gps_camera/features/reports/services/report_service.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late FakePermissionService permissions;

  setUpAll(() async {
    root = await mockPathProvider();
    await GetStorage.init();
  });

  setUp(() async {
    await GetStorage().erase();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    Get.put(DatabaseService(NativeDatabase.memory()), permanent: true);
    permissions = FakePermissionService();
    Get.put<PermissionService>(permissions);
    Get.put<GalleryService>(FakeGalleryService(), permanent: true);
    Get.put<ReportService>(FakeReportService());
    Get.put<LocationService>(
      FakeLocationService(permission: PermissionAccess.denied),
    );
    InitialBinding().dependencies();
  });

  tearDown(Get.reset);

  StorageService storage() => Get.find<StorageService>();

  testWidgets('first launch shows the introduction, then home', (tester) async {
    await tester.pumpWidget(const GpsCameraApp());
    await tester.pumpAndSettle();
    expect(find.text('Welcome to GPS Camera'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Two permissions'), findsOneWidget);

    permissions.requestResult = PermissionAccess.granted;
    await tester.tap(find.text('Allow').first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('Allow'), findsOneWidget, reason: 'location still asks');

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('You’re ready'), findsOneWidget);
    final skip = tester.widget<TextButton>(
      find.ancestor(of: find.text('Skip'), matching: find.byType(TextButton)),
    );
    expect(skip.onPressed, isNull, reason: 'hidden on the last page');

    await tester.tap(find.text('Go to home'));
    await tester.pumpAndSettle();
    expect(find.text('Open camera'), findsOneWidget);
    expect(storage().read<bool>(StorageKeys.onboardingDone), isTrue);
  });

  testWidgets('Skip goes home and is remembered', (tester) async {
    await tester.pumpWidget(const GpsCameraApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Open camera'), findsOneWidget);
    expect(OnboardingGate.isDone(storage()), isTrue);
  });

  test('existing users with settings or photos skip it', () async {
    final photos = PhotoStorageService();
    await OnboardingGate.skipForExistingUsers(
      storage(),
      photos,
      hasSettings: false,
    );
    expect(OnboardingGate.isDone(storage()), isFalse, reason: 'fresh');

    await OnboardingGate.skipForExistingUsers(
      storage(),
      photos,
      hasSettings: true,
    );
    expect(OnboardingGate.isDone(storage()), isTrue);

    await storage().remove(StorageKeys.onboardingDone);
    final dir = await photos.photosDirectory();
    File('${dir.path}/IMG_1.jpg').writeAsBytesSync([1]);
    await OnboardingGate.skipForExistingUsers(
      storage(),
      photos,
      hasSettings: false,
    );
    expect(OnboardingGate.isDone(storage()), isTrue);
    expect(root.existsSync(), isTrue);
  });
}
