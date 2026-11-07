import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/app/app.dart';
import 'package:gps_camera/app/bindings/initial_binding.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('gps_camera_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => tempDir.path,
    );
    await GetStorage.init();
  });

  setUp(() => InitialBinding().dependencies());
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
    expect(find.text('Camera preview'), findsOneWidget);
    await goBack(tester);

    await openFromHome(tester, 'Gallery');
    expect(find.text('No photos yet'), findsOneWidget);
    await goBack(tester);

    await openFromHome(tester, 'Projects');
    expect(find.text('No projects yet'), findsOneWidget);
    await goBack(tester);

    await openFromHome(tester, 'Settings');
    expect(find.text('Appearance'.toUpperCase()), findsOneWidget);
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
}
