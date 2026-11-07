import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/app/app.dart';
import 'package:gps_camera/app/bindings/initial_binding.dart';
import 'package:gps_camera/core/database/database_service.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/location/services/location_service.dart';
import 'package:gps_camera/features/reports/services/report_service.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await mockPathProvider();
    await GetStorage.init();
  });

  setUp(() {
    // Registered first so InitialBinding's lazy registration keeps the fake.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    Get.put(DatabaseService(NativeDatabase.memory()), permanent: true);
    Get.put<PermissionService>(FakePermissionService());
    Get.put<GalleryService>(FakeGalleryService());
    Get.put<ReportService>(FakeReportService());
    Get.put<LocationService>(
      FakeLocationService(permission: PermissionAccess.denied),
    );
    InitialBinding().dependencies();
  });
  tearDown(Get.reset);

  Future<void> openFromHome(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> goBack(WidgetTester tester) async {
    Get.back<void>();
    await tester.pumpAndSettle();
  }

  testWidgets('every initial route opens from home', (tester) async {
    await tester.pumpWidget(const GpsCameraApp());
    await tester.pumpAndSettle();
    expect(find.text('Open camera'), findsOneWidget);

    await openFromHome(tester, 'Open camera');
    expect(find.text('Camera access needed'), findsOneWidget);
    expect(find.text('Location permission needed'), findsOneWidget);
    await goBack(tester);

    await openFromHome(tester, 'Gallery');
    expect(find.text('No photos yet'), findsOneWidget);
    await goBack(tester);

    await openFromHome(tester, 'Projects');
    expect(find.text('No projects yet'), findsOneWidget);
    await goBack(tester);

    await openFromHome(tester, 'Settings');
    expect(find.text('Appearance'.toUpperCase()), findsOneWidget);
    await goBack(tester);

    await openFromHome(tester, 'Reports');
    expect(find.text('No reports yet'), findsOneWidget);
  });

  testWidgets('theme selector switches light and dark', (tester) async {
    await tester.pumpWidget(const GpsCameraApp());
    await tester.pumpAndSettle();
    await openFromHome(tester, 'Settings');

    Brightness brightness() =>
        Theme.of(tester.element(find.text('Theme'))).brightness;

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.light);
  });

  testWidgets('creating a project navigates through edit to details', (
    tester,
  ) async {
    await tester.pumpWidget(const GpsCameraApp());
    await tester.pumpAndSettle();
    await openFromHome(tester, 'Projects');
    expect(find.text('No projects yet'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();
    expect(find.text('Create project'), findsOneWidget);

    await tester.tap(find.text('Create project'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a project name.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'North Bridge');
    await tester.tap(find.text('Create project'));
    await tester.pumpAndSettle();

    expect(find.text('North Bridge'), findsWidgets);
    expect(find.text('No photos in this project'), findsOneWidget);
  });
}
