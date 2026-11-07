import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/core/settings/app_preferences.dart';
import 'package:gps_camera/features/camera/controllers/capture_controller.dart';
import 'package:gps_camera/features/camera/models/capture_timer.dart';
import 'package:gps_camera/features/camera/services/capture_saver.dart';
import 'package:gps_camera/features/camera/services/volume_shutter.dart';
import 'package:gps_camera/features/camera/widgets/camera_controls_bar.dart';
import 'package:gps_camera/features/camera/widgets/shutter_button.dart';
import 'package:gps_camera/features/camera/widgets/viewfinder_layer.dart';
import 'package:gps_camera/features/location/controllers/location_controller.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('co.tdevs.gps_camera/volume');
  final volumeCalls = <bool>[];

  setUp(() {
    volumeCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'setEnabled') {
            volumeCalls.add(call.arguments as bool);
          }
          return null;
        });
  });

  tearDown(Get.reset);

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: SizedBox(width: 300, height: 400, child: child)),
    ),
  );

  group('capture timer', () {
    test('cycles off → 3 s → 10 s → off and parses safely', () {
      expect(CaptureTimer.off.next, CaptureTimer.three);
      expect(CaptureTimer.three.next, CaptureTimer.ten);
      expect(CaptureTimer.ten.next, CaptureTimer.off);
      expect(CaptureTimer.parse('ten'), CaptureTimer.ten);
      expect(CaptureTimer.parse(null), CaptureTimer.off);
    });
  });

  group('preferences', () {
    setUpAll(() async {
      await mockPathProvider();
      await GetStorage.init('camera_controls');
    });

    test('grid, timer and volume shutter persist', () async {
      final box = GetStorage('camera_controls');
      await box.erase();
      final prefs = AppPreferences(StorageService(box));
      expect(prefs.showGrid.value, isFalse);
      expect(prefs.captureTimer.value, CaptureTimer.off);
      expect(prefs.volumeShutter.value, isTrue);

      await prefs.setShowGrid(true);
      await prefs.setCaptureTimer(CaptureTimer.ten);
      await prefs.setVolumeShutter(false);

      final again = AppPreferences(StorageService(box));
      expect(again.showGrid.value, isTrue);
      expect(again.captureTimer.value, CaptureTimer.ten);
      expect(again.volumeShutter.value, isFalse);
    });
  });

  group('capture controller', () {
    late FakePermissionService permissions;

    CaptureController build({bool volumeOn = true}) {
      permissions = FakePermissionService();
      return Get.put(
        CaptureController(
          permissions,
          CaptureSaver(PhotoStorageService()),
          LocationController(FakeLocationService(), permissions),
          cameraLoader: () async => const [],
          volume: VolumeShutter(),
          volumeEnabled: () => volumeOn,
          timer: () => CaptureTimer.three,
        ),
      );
    }

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test(
      'volume keys are taken only while the camera screen is open',
      () async {
        final controller = build();
        await settle();
        expect(volumeCalls, [true]);

        await Get.delete<CaptureController>();
        await settle();
        expect(volumeCalls, [true, false]);
        expect(controller.countdown.value, isNull);
      },
    );

    test('volume shutter switched off in Settings is never enabled', () async {
      build(volumeOn: false);
      await settle();
      expect(volumeCalls, [false]);
    });

    test('a volume press reaches the shutter; ignored until ready', () async {
      final controller = build();
      await settle();
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('pressed'),
            ),
            (_) {},
          );
      expect(controller.countdown.value, isNull, reason: 'no camera yet');
      expect(controller.isCapturing.value, isFalse);
    });

    test('zoom presets follow the lens range', () {
      final controller = build();
      controller.minZoom.value = 1;
      controller.maxZoom.value = 1;
      expect(controller.zoomPresets, [1.0]);

      controller.minZoom.value = 0.6;
      controller.maxZoom.value = 10;
      expect(controller.zoomPresets, [0.6, 1.0, 2.0, 5.0, 10.0]);

      controller.minZoom.value = 1;
      controller.maxZoom.value = 4;
      expect(controller.zoomPresets, [1.0, 2.0]);
    });

    test('zoom and focus are ignored without a camera', () async {
      final controller = build();
      controller.setZoom(3);
      await controller.focusAt(const Offset(0.5, 0.5));
      expect(controller.zoom.value, 1);
      expect(controller.focusPoint.value, isNull);
    });
  });

  group('controls bar', () {
    testWidgets('zoom chips show the exact zoom on the active chip', (
      tester,
    ) async {
      double? picked;
      await tester.pumpWidget(
        host(
          CameraControlsBar(
            showGrid: false,
            timer: CaptureTimer.three,
            zoom: 1.7,
            zoomPresets: const [0.6, 1, 2, 5],
            enabled: true,
            onToggleGrid: () {},
            onCycleTimer: () {},
            onZoom: (z) => picked = z,
          ),
        ),
      );
      expect(find.text('0.6×'), findsOneWidget);
      expect(find.text('1.7×'), findsOneWidget);
      expect(find.text('2×'), findsOneWidget);
      expect(find.text('5×'), findsOneWidget);
      expect(find.text('3'), findsOneWidget, reason: 'timer badge');

      await tester.tap(find.text('5×'));
      expect(picked, 5);
    });

    testWidgets('a single lens zoom hides the chips', (tester) async {
      await tester.pumpWidget(
        host(
          CameraControlsBar(
            showGrid: true,
            timer: CaptureTimer.off,
            zoom: 1,
            zoomPresets: const [1],
            enabled: true,
            onToggleGrid: () {},
            onCycleTimer: () {},
            onZoom: (_) {},
          ),
        ),
      );
      expect(find.text('1×'), findsNothing);
      expect(find.byIcon(Icons.grid_on_rounded), findsOneWidget);
    });
  });

  group('viewfinder layer', () {
    testWidgets('tap focuses at the tapped fraction of the preview', (
      tester,
    ) async {
      Offset? focus;
      await tester.pumpWidget(
        host(
          ViewfinderLayer(
            zoom: 1,
            onZoom: (_) {},
            onFocus: (p) => focus = p,
            focusPoint: null,
            focusTaps: 0,
            showGrid: false,
            countdown: null,
          ),
        ),
      );
      final box = tester.getRect(find.byType(ViewfinderLayer));
      await tester.tapAt(box.topLeft + const Offset(75, 300));
      expect(focus!.dx, closeTo(0.25, 0.01));
      expect(focus!.dy, closeTo(0.75, 0.01));
    });

    testWidgets('pinch zooms relative to the zoom at the start', (
      tester,
    ) async {
      final zooms = <double>[];
      await tester.pumpWidget(
        host(
          ViewfinderLayer(
            zoom: 2,
            onZoom: zooms.add,
            onFocus: (_) {},
            focusPoint: null,
            focusTaps: 0,
            showGrid: false,
            countdown: null,
          ),
        ),
      );
      final center = tester.getCenter(find.byType(ViewfinderLayer));
      final a = await tester.startGesture(center - const Offset(20, 0));
      final b = await tester.startGesture(
        center + const Offset(20, 0),
        pointer: 2,
      );
      await a.moveTo(center - const Offset(40, 0));
      await b.moveTo(center + const Offset(40, 0));
      await a.up();
      await b.up();
      // Gesture slop eats part of the first move, so check direction and
      // that the result builds on the starting zoom.
      expect(zooms.first, greaterThan(2));
      expect(zooms.last, greaterThan(2.5));
    });

    testWidgets('shows grid, focus ring and countdown without blocking the '
        'overlay', (tester) async {
      var overlayTapped = false;
      Offset? focus;
      await tester.pumpWidget(
        host(
          ViewfinderLayer(
            zoom: 1,
            onZoom: (_) {},
            onFocus: (p) => focus = p,
            focusPoint: const Offset(0.5, 0.5),
            focusTaps: 1,
            showGrid: true,
            countdown: 3,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => overlayTapped = true,
                child: const SizedBox(width: 80, height: 40),
              ),
            ),
          ),
        ),
      );
      expect(find.text('3'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ViewfinderLayer),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );

      final box = tester.getRect(find.byType(ViewfinderLayer));
      await tester.tapAt(box.bottomLeft + const Offset(20, -20));
      await tester.pump(const Duration(milliseconds: 500));
      expect(overlayTapped, isTrue);
      expect(focus, isNull, reason: 'the overlay keeps its own taps');

      await tester.pump(const Duration(seconds: 2));
    });
  });

  testWidgets('shutter shows a cancel state while the timer runs', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(ShutterButton(onPressed: () => taps++, isCountingDown: true)),
    );
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('Cancel timer'), findsOneWidget);
    await tester.tap(find.byType(ShutterButton));
    expect(taps, 1);
  });
}
