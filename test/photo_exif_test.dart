import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/camera/services/photo_exif.dart';
import 'package:gps_camera/features/export/models/gallery_save_mode.dart';
import 'package:gps_camera/features/export/services/gallery_export_service.dart';
import 'package:gps_camera/features/export/services/phone_gallery.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/services/image_processor.dart';
import 'package:gps_camera/features/watermark/services/watermark_painter.dart';
import 'package:gps_camera/features/watermark/services/watermark_renderer.dart';
import 'package:image/image.dart' as img;

import 'helpers/test_env.dart';
import 'helpers/watermark_fixtures.dart';

double _decimal(img.IfdValue? dms, String? ref) {
  final d = dms!.toRational().toDouble();
  final m = dms.toRational(1).toDouble();
  final s = dms.toRational(2).toDouble();
  final v = d + m / 60 + s / 3600;
  return ref == 'S' || ref == 'W' ? -v : v;
}

String? _ascii(img.IfdValue? v) => v?.toString().replaceAll('\u0000', '');

/// Records the bytes of each file handed to the gallery.
class _RecordingGallery extends PhoneGallery {
  final Map<String, Uint8List> saved = {};

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<PhoneGallerySave> save(File file, {DateTime? takenAt}) async {
    saved[file.uri.pathSegments.last] = file.readAsBytesSync();
    return PhoneGallerySave.saved;
  }
}

Future<OverlayBitmap?> _blank(WatermarkPainter painter) async {
  final b = painter.bounds;
  final w = b.width.ceil();
  final h = b.height.ceil();
  return OverlayBitmap(
    left: b.left.floor(),
    top: b.top.floor(),
    width: w,
    height: h,
    rgba: Uint8List(w * h * 4),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final metadata = fixtureMetadata().withNote('Pillar 3');

  group('ExifSpec', () {
    test('uses the capture zone, GPS and an ASCII note', () {
      final spec = ExifSpec.from(metadata);
      // fixtureMetadata: 04:02:09 UTC, +06:00.
      expect(spec.dateTime, '2026:11:07 10:02:09');
      expect(spec.offset, '+06:00');
      expect(spec.latitude, metadata.location.fix!.latitude);
      expect(spec.description, 'Pillar 3');
      expect(
        ExifSpec.exifOffset(const Duration(hours: -3, minutes: -30)),
        '-03:30',
      );
    });

    test('leaves out what is unknown or not ASCII', () {
      final none = ExifSpec.from(
        fixtureMetadata(
          location: const LocationSnapshot.unavailable(
            LocationUnavailableReason.noFixYet,
          ),
        ).withNote('পিলার ৩'),
      );
      expect(none.hasLocation, isFalse);
      expect(none.description, isNull);
    });
  });

  group('PhotoExif', () {
    late Uint8List camera;

    setUp(() {
      final image = img.Image(width: 64, height: 48)
        ..exif.imageIfd.make = 'OnePlus'
        ..exif.imageIfd.model = 'CPH2605'
        ..exif.imageIfd.orientation = 6;
      image.exif.exifIfd[0x829D] = img.IfdValueRational(18, 10); // FNumber
      image.exif.exifIfd[0x927C] = img.IfdValueUndefined.list([1, 2, 3]);
      camera = img.encodeJpg(image);
    });

    test('writes time, zone, GPS and keeps camera details losslessly', () {
      final spec = ExifSpec.from(metadata);
      final out = PhotoExif.apply(camera, spec, upright: false)!;
      final exif = img.decodeJpgExif(out)!;

      expect(_ascii(exif.imageIfd[0x0131]), 'GPS Camera');
      expect(exif.imageIfd.make, 'OnePlus');
      expect(exif.imageIfd.orientation, 6, reason: 'pixels not rotated');
      expect(_ascii(exif.exifIfd[0x9003]), '2026:11:07 10:02:09');
      expect(_ascii(exif.exifIfd[0x9011]), '+06:00');
      expect(exif.exifIfd[0x829D]!.toRational().toDouble(), 1.8);
      expect(exif.exifIfd.containsKey(0x927C), isFalse, reason: 'no makernote');
      expect(_ascii(exif.imageIfd[0x010E]), 'Pillar 3');

      final fix = metadata.location.fix!;
      final gps = exif.gpsIfd;
      expect(
        _decimal(gps[0x02], _ascii(gps[0x01])),
        closeTo(fix.latitude, 1e-6),
      );
      expect(
        _decimal(gps[0x04], _ascii(gps[0x03])),
        closeTo(fix.longitude, 1e-6),
      );
      expect(_ascii(gps[0x12]), 'WGS-84');

      // Image data is unchanged.
      final a = img.decodeJpg(camera)!;
      final b = img.decodeJpg(out)!;
      expect(b.width, a.width);
      expect(b.getPixel(10, 10), a.getPixel(10, 10));
    });

    test('southern and western coordinates keep their sign', () {
      const spec = ExifSpec(latitude: -33.8688, longitude: -151.2093);
      final exif = img.decodeJpgExif(
        PhotoExif.apply(camera, spec, upright: true)!,
      )!;
      expect(_ascii(exif.gpsIfd[0x01]), 'S');
      expect(
        _decimal(exif.gpsIfd[0x04], _ascii(exif.gpsIfd[0x03])),
        closeTo(-151.2093, 1e-6),
      );
      expect(exif.imageIfd.orientation, 1);
    });
  });

  group('in use', () {
    late Directory root;
    late PhotoStorageService storage;

    setUpAll(() async {
      await mockPathProvider();
      await GetStorage.init('exif_test');
    });

    setUp(() async {
      root = await mockPathProvider();
      storage = PhotoStorageService();
    });

    test('watermarked copies carry EXIF; the original is untouched', () async {
      final photos = await storage.photosDirectory();
      final original = writeTestJpeg('${photos.path}/IMG_x.jpg');
      final before = original.readAsBytesSync();
      final result = await WatermarkRenderer(storage, rasterize: _blank).render(
        original: original,
        metadata: metadata,
        config: const WatermarkConfig(),
        imageSize: const Size(400, 300),
      );
      final exif = img.decodeJpgExif(result.output.readAsBytesSync())!;
      expect(_ascii(exif.exifIfd[0x9003]), '2026:11:07 10:02:09');
      expect(exif.gpsIfd.containsKey(0x02), isTrue);
      expect(exif.imageIfd.orientation, 1);
      expect(exif.exifIfd[0xA002]!.toInt(), 400);
      expect(original.readAsBytesSync(), before);
    });

    test(
      'gallery copies of originals get EXIF; app files stay the same',
      () async {
        final box = GetStorage('exif_test');
        await box.erase();
        final gallery = _RecordingGallery();
        final export = GalleryExportService(
          StorageService(box),
          gallery,
          tempDirectory: () async => root,
        );
        await export.setMode(GallerySaveMode.original);

        final photos = await storage.photosDirectory();
        final original = writeTestJpeg('${photos.path}/IMG_y.jpg');
        final before = original.readAsBytesSync();
        expect(
          await export.exportCapture(original: original, metadata: metadata),
          isTrue,
        );

        final copy = gallery.saved['IMG_y.jpg']!;
        final exif = img.decodeJpgExif(copy)!;
        expect(_ascii(exif.exifIfd[0x9011]), '+06:00');
        expect(exif.gpsIfd.containsKey(0x04), isTrue);
        expect(original.readAsBytesSync(), before);
        expect(
          Directory('${root.path}/gallery_export').listSync(),
          isEmpty,
          reason: 'temporary copy removed',
        );

        // Without metadata the file is sent as it is.
        gallery.saved.clear();
        await export.exportCapture(original: original);
        expect(gallery.saved['IMG_y.jpg'], before);
      },
    );
  });

  test('PhotoMetadata note is not needed for EXIF', () {
    final spec = ExifSpec.from(fixtureMetadata());
    expect(spec.description, isNull);
    expect(PhotoMetadata.cleanNote(null), isNull);
  });
}
