import 'dart:typed_data';

import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:image/image.dart' as img;
// Rational is used by the public EXIF API but not exported by the package.
// ignore: implementation_imports
import 'package:image/src/util/rational.dart' show Rational;

/// The EXIF values a photo should carry, taken from its metadata. Plain
/// data, so it can be sent to a background isolate.
class ExifSpec {
  const ExifSpec({
    this.dateTime,
    this.offset,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.heading,
    this.fixTimeUtc,
    this.description,
    this.direction,
    this.directionTrueNorth = true,
  });

  factory ExifSpec.from(PhotoMetadata metadata) {
    final wall = metadata.capturedAt.toUtc().add(metadata.timeZoneOffset);
    final fix = metadata.location.status == LocationRecordStatus.unavailable
        ? null
        : metadata.location.fix;
    final note = metadata.note;
    return ExifSpec(
      dateTime: exifDateTime(wall),
      offset: exifOffset(metadata.timeZoneOffset),
      latitude: fix?.latitude,
      longitude: fix?.longitude,
      accuracy: fix?.accuracy,
      heading: fix?.heading,
      fixTimeUtc: fix?.timestamp.toUtc(),
      // EXIF text is ASCII; non-ASCII notes stay in the app's own data.
      description: note != null && note.codeUnits.every((c) => c < 0x80)
          ? note
          : null,
      // A flat phone's top edge is not where the lens looked.
      direction: metadata.direction?.flat == false
          ? metadata.direction!.degrees
          : null,
      directionTrueNorth: metadata.direction?.trueNorth ?? true,
    );
  }

  /// `2026:11:07 15:11:17`, the capture's own wall-clock time.
  final String? dateTime;

  /// `+06:00`
  final String? offset;
  final double? latitude;
  final double? longitude;

  /// Horizontal accuracy in metres.
  final double? accuracy;

  /// Direction of travel in degrees, when the phone reported it.
  final double? heading;
  final DateTime? fixTimeUtc;
  final String? description;

  /// Which way the camera faced, degrees from north.
  final double? direction;
  final bool directionTrueNorth;

  bool get hasLocation => latitude != null && longitude != null;

  static String exifDateTime(DateTime wall) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${wall.year.toString().padLeft(4, '0')}:${two(wall.month)}:'
        '${two(wall.day)} ${two(wall.hour)}:${two(wall.minute)}:'
        '${two(wall.second)}';
  }

  static String exifOffset(Duration offset) {
    final sign = offset.isNegative ? '-' : '+';
    final minutes = offset.inMinutes.abs();
    String two(int v) => v.toString().padLeft(2, '0');
    return '$sign${two(minutes ~/ 60)}:${two(minutes % 60)}';
  }
}

/// Builds clean EXIF from the camera's and the photo's metadata.
///
/// Only well-known camera tags are carried over. Maker notes, the embedded
/// thumbnail (which would show the photo without its watermark) and
/// interoperability data are dropped.
abstract final class PhotoExif {
  static const String software = 'GPS Camera';

  /// Camera tags copied from the original's EXIF IFD.
  static const List<int> _cameraTags = [
    0x829A, // ExposureTime
    0x829D, // FNumber
    0x8822, // ExposureProgram
    0x8827, // ISO
    0x9201, // ShutterSpeedValue
    0x9202, // ApertureValue
    0x9204, // ExposureBiasValue
    0x9205, // MaxApertureValue
    0x9207, // MeteringMode
    0x9208, // LightSource
    0x9209, // Flash
    0x920A, // FocalLength
    0xA402, // ExposureMode
    0xA403, // WhiteBalance
    0xA404, // DigitalZoomRatio
    0xA405, // FocalLengthIn35mmFilm
    0xA406, // SceneCaptureType
  ];

  /// [jpeg] with its EXIF replaced. [upright] is true when the pixels are
  /// already rotated (watermarked copies), so the orientation is normal;
  /// otherwise the source orientation is kept. Returns null when the JPEG
  /// could not be updated.
  static Uint8List? apply(
    Uint8List jpeg,
    ExifSpec spec, {
    required bool upright,
    img.ExifData? source,
    int? width,
    int? height,
  }) {
    final from = source ?? img.decodeJpgExif(jpeg);
    final exif = build(
      spec,
      source: from,
      upright: upright,
      width: width,
      height: height,
    );
    return img.injectJpgExif(jpeg, exif);
  }

  static img.ExifData build(
    ExifSpec spec, {
    img.ExifData? source,
    required bool upright,
    int? width,
    int? height,
  }) {
    final exif = img.ExifData();
    final ifd0 = exif.imageIfd;
    final camera0 = source?.imageIfd;
    final cameraExif =
        source == null || !source.imageIfd.sub.containsKey('exif')
        ? null
        : source.exifIfd;

    void copy(img.IfdDirectory? from, img.IfdDirectory to, int tag) {
      final value = from?[tag];
      if (value != null) to[tag] = value.clone();
    }

    copy(camera0, ifd0, 0x010F); // Make
    copy(camera0, ifd0, 0x0110); // Model
    ifd0[0x0131] = img.IfdValueAscii(software);
    final orientation = upright ? 1 : (camera0?.orientation ?? 1);
    ifd0[0x0112] = img.IfdValueShort(orientation < 1 ? 1 : orientation);
    if (spec.dateTime != null) {
      ifd0[0x0132] = img.IfdValueAscii(spec.dateTime!);
    }
    if (spec.description != null) {
      ifd0[0x010E] = img.IfdValueAscii(spec.description!);
    }

    final ex = exif.exifIfd;
    ex[0x9000] = img.IfdValueUndefined.list('0232'.codeUnits);
    for (final tag in _cameraTags) {
      copy(cameraExif, ex, tag);
    }
    if (spec.dateTime != null) {
      ex[0x9003] = img.IfdValueAscii(spec.dateTime!); // DateTimeOriginal
      ex[0x9004] = img.IfdValueAscii(spec.dateTime!); // DateTimeDigitized
    }
    if (spec.offset != null) {
      ex[0x9010] = img.IfdValueAscii(spec.offset!);
      ex[0x9011] = img.IfdValueAscii(spec.offset!);
      ex[0x9012] = img.IfdValueAscii(spec.offset!);
    }
    if (width != null && height != null) {
      ex[0xA002] = img.IfdValueLong(width);
      ex[0xA003] = img.IfdValueLong(height);
    } else {
      copy(cameraExif, ex, 0xA002);
      copy(cameraExif, ex, 0xA003);
    }

    if (spec.hasLocation) _writeGps(exif.gpsIfd, spec);
    return exif;
  }

  static void _writeGps(img.IfdDirectory gps, ExifSpec spec) {
    final lat = spec.latitude!;
    final lng = spec.longitude!;
    gps[0x00] = img.IfdByteValue.list(Uint8List.fromList([2, 3, 0, 0]));
    gps[0x01] = img.IfdValueAscii(lat >= 0 ? 'N' : 'S');
    gps[0x02] = img.IfdValueRational.list(_dms(lat.abs()));
    gps[0x03] = img.IfdValueAscii(lng >= 0 ? 'E' : 'W');
    gps[0x04] = img.IfdValueRational.list(_dms(lng.abs()));
    final time = spec.fixTimeUtc;
    if (time != null) {
      gps[0x07] = img.IfdValueRational.list([
        Rational(time.hour, 1),
        Rational(time.minute, 1),
        Rational(time.second * 1000 + time.millisecond, 1000),
      ]);
      gps[0x1D] = img.IfdValueAscii(
        ExifSpec.exifDateTime(time).substring(0, 10),
      );
    }
    gps[0x12] = img.IfdValueAscii('WGS-84');
    if (spec.heading != null) {
      gps[0x0E] = img.IfdValueAscii('T');
      gps[0x0F] = img.IfdValueRational((spec.heading! * 100).round(), 100);
    }
    if (spec.direction != null) {
      // GPSImgDirectionRef / GPSImgDirection.
      gps[0x10] = img.IfdValueAscii(spec.directionTrueNorth ? 'T' : 'M');
      gps[0x11] = img.IfdValueRational((spec.direction! * 100).round(), 100);
    }
    if (spec.accuracy != null) {
      // GPSHPositioningError, metres.
      gps[0x1F] = img.IfdValueRational((spec.accuracy! * 100).round(), 100);
    }
  }

  /// Degrees, minutes and seconds (to 1/10000 s) as EXIF rationals.
  static List<Rational> _dms(double value) {
    final degrees = value.floor();
    final minutesFull = (value - degrees) * 60;
    final minutes = minutesFull.floor();
    final seconds = (minutesFull - minutes) * 60;
    return [
      Rational(degrees, 1),
      Rational(minutes, 1),
      Rational((seconds * 10000).round(), 10000),
    ];
  }
}
