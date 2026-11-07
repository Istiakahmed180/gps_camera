import 'dart:io';

import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:image/image.dart' as img;

/// A sidecar exactly as Phase 3 writes it (captured on the OnePlus test
/// device).
const String phoneSidecarJson = '''
{
  "schemaVersion": 1,
  "imageFileName": "IMG_20261107_100209_588.jpg",
  "capturedAt": "2026-11-07T04:02:09.588231Z",
  "timeZoneOffsetMinutes": 360,
  "timeZoneName": "+06",
  "location": {
    "status": "current",
    "reason": null,
    "accuracyLevel": "good",
    "fixAgeMs": 5966,
    "fix": {
      "latitude": 23.910908,
      "longitude": 90.4010045,
      "accuracy": 6.752999782562256,
      "altitude": -26.100000381469727,
      "altitudeReference": "wgs84Ellipsoid",
      "altitudeAccuracy": 3.834149122238159,
      "heading": null,
      "timestamp": "2026-11-07T04:02:03.622Z",
      "isMocked": false,
      "address": null
    }
  }
}
''';

LocationFix fixtureFix({double accuracy = 6.75, String? address}) {
  return LocationFix(
    latitude: 23.910908,
    longitude: 90.401005,
    accuracy: accuracy,
    timestamp: DateTime.utc(2026, 11, 7, 4, 2, 3),
    altitude: -26.1,
    altitudeReference: AltitudeReference.wgs84Ellipsoid,
    address: address,
  );
}

PhotoMetadata fixtureMetadata({
  LocationSnapshot? location,
  DateTime? capturedAt,
  Duration offset = const Duration(hours: 6),
}) {
  return PhotoMetadata(
    imageFileName: 'IMG_test.jpg',
    capturedAt: capturedAt ?? DateTime.utc(2026, 11, 7, 4, 2, 9),
    timeZoneOffset: offset,
    timeZoneName: '+06',
    location:
        location ??
        LocationSnapshot.current(fixtureFix(), const Duration(seconds: 6)),
  );
}

/// Writes a grey JPEG whose top-left quarter is red, optionally tagged with
/// an EXIF orientation, and returns it.
File writeTestJpeg(
  String path, {
  int width = 400,
  int height = 300,
  int? orientation,
}) {
  final image = img.Image(width: width, height: height)
    ..clear(img.ColorRgb8(128, 128, 128));
  img.fillRect(
    image,
    x1: 0,
    y1: 0,
    x2: width ~/ 4,
    y2: height ~/ 4,
    color: img.ColorRgb8(220, 30, 30),
  );
  if (orientation != null) image.exif.imageIfd.orientation = orientation;
  return File(path)..writeAsBytesSync(img.encodeJpg(image, quality: 95));
}

bool isNear(img.Pixel p, int r, int g, int b, {int tolerance = 24}) =>
    (p.r - r).abs() <= tolerance &&
    (p.g - g).abs() <= tolerance &&
    (p.b - b).abs() <= tolerance;
