import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/share_service.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/camera/models/video_details.dart';
import 'package:gps_camera/features/camera/services/capture_saver.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/gallery/models/gallery_filter.dart';
import 'package:gps_camera/features/gallery/services/gallery_scanner.dart';
import 'package:gps_camera/features/location/models/camera_direction.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/video/services/video_recovery.dart';
import 'package:gps_camera/features/video/services/video_service.dart';
import 'package:gps_camera/features/video/services/video_stamp_service.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_record.dart';
import 'package:gps_camera/features/watermark/services/watermark_renderer.dart';

import 'helpers/test_env.dart';
import 'helpers/watermark_fixtures.dart';

/// Records what would be sent to the native stamper and writes a dummy
/// output, so the Dart side can be checked without Android.
class _FakeVideo extends VideoService {
  _FakeVideo(super.storage) : super(channel: const MethodChannel('test/video'));

  List<StampFrame>? frames;
  (int, int)? size;
  bool fail = false;
  int stamps = 0;
  VideoInfo? fileInfo = const VideoInfo(
    durationMs: 3000,
    width: 720,
    height: 1280,
    hasAudio: true,
  );

  @override
  Future<VideoInfo?> info(String path) async => fileInfo;

  @override
  Future<void> stamp({
    required String input,
    required String output,
    required int width,
    required int height,
    required List<StampFrame> frames,
    void Function(double progress)? onProgress,
  }) async {
    if (fail) throw const VideoException('encoder failed');
    stamps++;
    this.frames = frames;
    size = (width, height);
    for (final f in frames) {
      expect(File(f.path).existsSync(), isTrue, reason: 'stamp PNG exists');
    }
    onProgress?.call(1);
    File(output).writeAsBytesSync([1, 2, 3]);
  }
}

PhotoMetadata _videoMetadata({int seconds = 3}) {
  final start = fixtureMetadata();
  final fix = fixtureFix();
  return PhotoMetadata(
    imageFileName: 'VID_test.mp4',
    capturedAt: start.capturedAt,
    timeZoneOffset: start.timeZoneOffset,
    timeZoneName: start.timeZoneName,
    location: start.location,
    video: VideoDetails(
      durationMs: seconds * 1000,
      width: 720,
      height: 1280,
      hasAudio: true,
      track: [
        for (var s = 0; s < seconds; s++)
          VideoTrackPoint(
            atMs: s * 1000,
            location: LocationSnapshot.current(fix, Duration.zero),
            direction: CameraDirection(degrees: 10.0 * s, trueNorth: false),
          ),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('video details', () {
    test('survive a round trip through the sidecar JSON', () {
      final metadata = _videoMetadata();
      final back = PhotoMetadata.fromJson(
        jsonDecode(jsonEncode(metadata.toJson())) as Map<String, dynamic>,
      );
      expect(back.isVideo, isTrue);
      expect(back.video!.durationMs, 3000);
      expect(back.video!.track, hasLength(3));
      expect(back.video!.track[2].direction!.degrees, 20);
      // Photos are unchanged.
      expect(fixtureMetadata().toJson().containsKey('video'), isFalse);
    });

    test('the stamp moves on with time and follows the track', () {
      final metadata = _videoMetadata();
      final later = metadata.atVideoTime(2400);
      expect(
        later.capturedAt.difference(metadata.capturedAt),
        const Duration(milliseconds: 2400),
      );
      expect(later.direction!.degrees, 20);
      expect(metadata.video!.pointAt(-1), isNull);
      expect(metadata.video!.pointAt(999)!.atMs, 0);
    });

    test('durations read like a clock', () {
      expect(formatVideoDuration(const Duration(seconds: 42)), '0:42');
      expect(
        formatVideoDuration(const Duration(minutes: 12, seconds: 5)),
        '12:05',
      );
      expect(
        formatVideoDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });
  });

  group('storage and gallery', () {
    late Directory root;
    late PhotoStorageService storage;

    setUp(() async {
      root = await mockPathProvider();
      storage = PhotoStorageService();
    });

    tearDown(() => root.delete(recursive: true));

    test('videos are saved as VID_<time>.mp4 next to photos', () async {
      final temp = File('${root.path}/capture.mp4')..writeAsBytesSync([7, 7]);
      final saved = await storage.saveVideo(
        XFile(temp.path),
        startedAt: DateTime(2026, 11, 8, 9, 5, 1, 7),
      );
      expect(saved.uri.pathSegments.last, 'VID_20261108_090501_007.mp4');
      expect(saved.parent.path, (await storage.photosDirectory()).path);
      final copy = await storage.reserveWatermarkedFile(saved);
      expect(copy.uri.pathSegments.last, 'VID_20261108_090501_007_wm.mp4');
    });

    test('the gallery lists videos and links stamped copies', () async {
      final photos = await storage.photosDirectory();
      final copies = await storage.watermarkedDirectory();
      File('${photos.path}/VID_a.mp4').writeAsBytesSync([1]);
      File('${photos.path}/VID_a.json')
          .writeAsStringSync(jsonEncode(_videoMetadata().toJson()));
      File('${copies.path}/VID_a_wm.mp4').writeAsBytesSync([1]);
      final index = scanGallery(photos.path, copies.path);
      expect(index.photos, hasLength(2));
      final copy = index.photos.firstWhere((p) => p.isWatermarked);
      expect(copy.sourceFileName, 'VID_a.mp4');
      expect(copy.isVideo, isTrue);
      expect(index.count(GalleryFilter.videos), 2);
      expect(sourceNameFromOutput('IMG_b_wm_2.jpg'), 'IMG_b.jpg');
    });

    test('videos are shared as video/mp4', () {
      expect(ShareService.mediaTypeOf('/a/VID_x.mp4'), 'video/mp4');
      expect(ShareService.mediaTypeOf('/a/IMG_x.jpg'), 'image/jpeg');
    });
  });

  group('live stamp', () {
    late Directory root;
    late PhotoStorageService storage;
    late _FakeVideo video;
    late File original;

    setUp(() async {
      root = await mockPathProvider();
      storage = PhotoStorageService();
      video = _FakeVideo(storage);
      final photos = await storage.photosDirectory();
      original = File('${photos.path}/VID_test.mp4')..writeAsBytesSync([9]);
    });

    tearDown(() => root.delete(recursive: true));

    VideoStampService stamper() => VideoStampService(
      storage,
      video,
      workDirectory: () async => Directory('${root.path}/cache')..createSync(),
    );

    testWidgets('draws a stamp for each second and saves its record', (
      tester,
    ) async {
      final service = stamper();
      final result = await tester.runAsync(
        () => service.stamp(
          original: original,
          metadata: _videoMetadata(),
          config: const WatermarkConfig(),
          automatic: true,
        ),
      );
      // The time changes every second, so every second gets its own image.
      expect(video.frames!.map((f) => f.fromMs), [0, 1000, 2000]);
      expect(video.size, (720, 1280));
      expect(result!.output.uri.pathSegments.last, 'VID_test_wm.mp4');
      final record = WatermarkRecord.fromJson(
        jsonDecode(result.record.readAsStringSync()) as Map<String, dynamic>,
      );
      expect(record.sourceImageFileName, 'VID_test.mp4');
      expect(record.automatic, isTrue);
      // Work files are removed and the original is untouched.
      expect(Directory('${root.path}/cache').listSync(), isEmpty);
      expect(original.readAsBytesSync(), [9]);
      expect(service.isBusy, isFalse);
    });

    testWidgets('a failed stamp leaves nothing behind', (tester) async {
      video.fail = true;
      final service = stamper();
      Object? error;
      await tester.runAsync(() async {
        try {
          await service.stamp(
            original: original,
            metadata: _videoMetadata(seconds: 1),
            config: const WatermarkConfig(),
          );
        } catch (e) {
          error = e;
        }
      });
      expect(error, isA<WatermarkException>());
      final copies = await tester.runAsync(storage.watermarkedDirectory);
      expect(copies!.listSync(), isEmpty);
      expect(service.progress.value, isNull);
    });
  });
  group('safety', () {
    late Directory root;
    late PhotoStorageService storage;
    late _FakeVideo video;
    late File original;

    setUp(() async {
      root = await mockPathProvider();
      storage = PhotoStorageService();
      video = _FakeVideo(storage);
      final photos = await storage.photosDirectory();
      original = File('${photos.path}/VID_test.mp4')..writeAsBytesSync([9]);
    });

    tearDown(() => root.delete(recursive: true));

    VideoStampService stamper() => VideoStampService(
      storage,
      video,
      workDirectory: () async => Directory('${root.path}/cache')..createSync(),
    );

    PhotoMetadata pending({int width = 720}) {
      final m = _videoMetadata();
      return m.withVideo(
        VideoDetails(
          durationMs: m.video!.durationMs,
          width: width,
          height: width == 0 ? 0 : 1280,
          hasAudio: true,
          track: m.video!.track,
          stampPending: true,
        ),
      );
    }

    testWidgets('stamps queue up instead of failing, and wait for recording', (
      tester,
    ) async {
      final service = stamper()..hold.value = true;
      await tester.runAsync(() async {
        final first = service.stamp(
          original: original,
          metadata: _videoMetadata(),
          config: const WatermarkConfig(),
        );
        final second = service.stamp(
          original: original,
          metadata: _videoMetadata(),
          config: const WatermarkConfig(),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        // Held while a video records.
        expect(video.stamps, 0);
        service.hold.value = false;
        await Future.wait([first, second]);
      });
      expect(video.stamps, 2);
    });

    testWidgets('a made copy clears the pending mark; zero sizes are re-read', (
      tester,
    ) async {
      final service = stamper();
      await tester.runAsync(
        () => service.stamp(
          original: original,
          metadata: pending(width: 0),
          config: const WatermarkConfig(),
          automatic: true,
        ),
      );
      expect(video.size, (720, 1280));
      final saved = PhotoMetadata.fromJson(
        jsonDecode(
          File(PhotoStorageService.sidecarPathFor(original.path))
              .readAsStringSync(),
        ) as Map<String, dynamic>,
      );
      expect(saved.video!.stampPending, isFalse);
    });

    testWidgets('an interrupted recording is saved and stamped next start', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final cache = Directory('${root.path}/cache')..createSync();
        final started = DateTime.now().subtract(const Duration(minutes: 1));
        final camera = File('${cache.path}/REC123.mp4')
          ..writeAsBytesSync([5, 5, 5]);
        camera.setLastModifiedSync(
          DateTime.now().subtract(const Duration(seconds: 30)),
        );
        final saver = CaptureSaver(storage, video: video);
        await saver.writeJournal(
          RecordingJournal(
            startedAt: started,
            location: _videoMetadata().location,
            note: 'Pillar 3',
            track: _videoMetadata().video!.track,
          ),
        );
        // The original sample video is not part of this test.
        await original.delete();

        final recovered = await VideoRecovery(
          storage: storage,
          saver: saver,
          stamper: stamper(),
          gallery: GalleryService(storage),
          autoStamp: () => true,
          config: () => const WatermarkConfig(),
          temporaryDirectory: () async => cache,
        ).run();

        expect(recovered, isTrue);
        expect(await (await storage.recordingJournalFile()).exists(), isFalse);
        final photos = (await storage.photosDirectory())
            .listSync()
            .map((f) => f.uri.pathSegments.last)
            .where((n) => n.endsWith('.mp4'))
            .toList();
        expect(photos, hasLength(1));
        expect(photos.single, startsWith('VID_'));
        expect(video.stamps, 1);
        final copies = (await storage.watermarkedDirectory()).listSync().map(
          (f) => f.uri.pathSegments.last,
        );
        expect(copies, contains(photos.single.replaceFirst('.mp4', '_wm.mp4')));
      });
    });

    test('the stamp keeps how fresh the GPS was at each second', () {
      final stale = LocationSnapshot.stale(
        fixtureFix(),
        const Duration(minutes: 2),
      );
      final metadata = _videoMetadata().withVideo(
        VideoDetails(
          durationMs: 2000,
          width: 720,
          height: 1280,
          hasAudio: false,
          track: [VideoTrackPoint(atMs: 1000, location: stale)],
        ),
      );
      expect(metadata.atVideoTime(1500).location.status, stale.status);
    });
  });
}
