import 'dart:convert';
import 'dart:io';

import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_record.dart';

import 'watermark_fixtures.dart';

/// Builds `Photos/` and `Watermarked/` folders the way the app writes them.
class GalleryFixture {
  GalleryFixture(this.root)
    : photos = Directory('${root.path}/GPSCamera/Photos')
        ..createSync(recursive: true),
      outputs = Directory('${root.path}/GPSCamera/Watermarked')
        ..createSync(recursive: true);

  final Directory root;
  final Directory photos;
  final Directory outputs;

  File original(
    String name, {
    DateTime? capturedAt,
    bool sidecar = true,
    String? rawSidecar,
    LocationSnapshot? location,
  }) {
    final image = writeTestJpeg('${photos.path}/$name.jpg');
    if (rawSidecar != null) {
      File('${photos.path}/$name.json').writeAsStringSync(rawSidecar);
    } else if (sidecar) {
      final metadata = fixtureMetadata(
        capturedAt: capturedAt,
        location: location,
      );
      File('${photos.path}/$name.json')
          .writeAsStringSync(jsonEncode(metadata.toJson()));
    }
    return image;
  }

  File watermarked(
    String source,
    String outputName, {
    DateTime? renderedAt,
    bool record = true,
    bool embedMetadata = true,
    String? rawRecord,
  }) {
    final image = writeTestJpeg('${outputs.path}/$outputName.jpg');
    final recordFile = File('${outputs.path}/$outputName.json');
    if (rawRecord != null) {
      recordFile.writeAsStringSync(rawRecord);
    } else if (record) {
      final json = WatermarkRecord(
        outputFileName: '$outputName.jpg',
        sourceImageFileName: '$source.jpg',
        sourceMetadataFileName: '$source.json',
        renderedAt: renderedAt ?? DateTime.utc(2026, 11, 7, 6),
        imageWidth: 400,
        imageHeight: 300,
        config: const WatermarkConfig(),
        sourceMetadata: embedMetadata ? fixtureMetadata() : null,
      ).toJson();
      if (!embedMetadata) json.remove('sourceMetadata');
      recordFile.writeAsStringSync(jsonEncode(json));
    }
    return image;
  }
}
