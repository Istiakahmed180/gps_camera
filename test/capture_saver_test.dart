import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/camera/controllers/capture_controller.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/camera/services/capture_saver.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';

import 'helpers/test_env.dart';

class _FailingMetadataStorage extends PhotoStorageService {
  @override
  Future<File> saveMetadata(File photo, Map<String, dynamic> json) async {
    throw const FileSystemException('disk full');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  final capturedAt = DateTime.utc(2026, 11, 7, 9, 5, 3, 42);
  const jpeg = [0xFF, 0xD8, 0xFF, 0xD9];

  setUp(() async => root = await mockPathProvider());

  Future<XFile> fakeCapture() async {
    final file = File('${root.path}/cache_${DateTime.now().microsecond}.jpg');
    await file.writeAsBytes(jpeg);
    return XFile(file.path);
  }

  Future<Map<String, dynamic>> readSidecar(SavedCapture saved) async =>
      jsonDecode(await saved.metadataFile!.readAsString())
          as Map<String, dynamic>;

  test('saves photo and sidecar with exact GPS values', () async {
    final fix = testFix(
      latitude: 37.42199834,
      longitude: -122.08400012,
      timestamp: capturedAt.subtract(const Duration(seconds: 2)),
    );
    final saved = await CaptureSaver(PhotoStorageService()).save(
      await fakeCapture(),
      capturedAt: capturedAt,
      location: LocationSnapshot.current(fix, const Duration(seconds: 2)),
    );

    expect(await saved.photo.readAsBytes(), jpeg);
    expect(
      saved.metadataFile!.path,
      saved.photo.path.replaceAll('.jpg', '.json'),
    );

    final json = await readSidecar(saved);
    expect(json['imageFileName'], saved.photo.uri.pathSegments.last);
    expect(json['capturedAt'], '2026-11-07T09:05:03.042Z');
    final location = json['location'] as Map<String, dynamic>;
    expect(location['status'], 'current');
    expect(location['accuracyLevel'], 'good');
    expect(location['fixAgeMs'], 2000);
    final fixJson = location['fix'] as Map<String, dynamic>;
    expect(fixJson['latitude'], 37.42199834);
    expect(fixJson['longitude'], -122.08400012);
    expect(fixJson['accuracy'], 4.2);
    expect(fixJson['timestamp'], '2026-11-07T09:05:01.042Z');

    final restored = PhotoMetadata.fromJson(json);
    expect(restored.location.fix, fix);
  });

  test('saves the photo and records location as unavailable', () async {
    final saved = await CaptureSaver(PhotoStorageService()).save(
      await fakeCapture(),
      capturedAt: capturedAt,
      location: const LocationSnapshot.unavailable(
        LocationUnavailableReason.permissionDenied,
      ),
    );

    expect(await saved.photo.exists(), isTrue);
    final location = (await readSidecar(saved))['location'] as Map;
    expect(location['status'], 'unavailable');
    expect(location['reason'], 'permissionDenied');
    expect(location['fix'], isNull);
    expect(location['accuracyLevel'], isNull);
    expect(
      CaptureController.captureFeedbackMessage(saved),
      'Photo saved · no location',
    );
  });

  test('stale and poor fixes are labelled honestly in feedback', () async {
    final saver = CaptureSaver(PhotoStorageService());
    final stale = await saver.save(
      await fakeCapture(),
      capturedAt: capturedAt,
      location: LocationSnapshot.stale(testFix(), const Duration(minutes: 5)),
    );
    final poor = await saver.save(
      await fakeCapture(),
      capturedAt: capturedAt,
      location: LocationSnapshot.current(testFix(accuracy: 60), Duration.zero),
    );

    expect(
      CaptureController.captureFeedbackMessage(stale),
      'Photo saved · last known location',
    );
    expect(
      CaptureController.captureFeedbackMessage(poor),
      'Photo saved · poor GPS accuracy',
    );
    expect(stale.photo.path, isNot(poor.photo.path));
  });

  test('keeps the photo when the sidecar cannot be written', () async {
    final saved = await CaptureSaver(_FailingMetadataStorage()).save(
      await fakeCapture(),
      capturedAt: capturedAt,
      location: const LocationSnapshot.unavailable(
        LocationUnavailableReason.noFixYet,
      ),
    );

    expect(await saved.photo.exists(), isTrue);
    expect(saved.metadataFile, isNull);
    expect(
      CaptureController.captureFeedbackMessage(saved),
      contains('location data could not be saved'),
    );
  });

  test('metadata records the device time zone', () {
    final metadata = PhotoMetadata.create(
      imageFileName: 'IMG_1.jpg',
      capturedAt: capturedAt,
      location: const LocationSnapshot.unavailable(
        LocationUnavailableReason.noFixYet,
      ),
    );
    final json = metadata.toJson();

    expect(json['schemaVersion'], 1);
    expect(
      json['timeZoneOffsetMinutes'],
      capturedAt.toLocal().timeZoneOffset.inMinutes,
    );
    expect(PhotoMetadata.fromJson(json).capturedAt, capturedAt);
  });
}
