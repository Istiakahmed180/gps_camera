import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';

/// The JSON written next to each watermarked copy, linking it to its
/// original and recording how it was made.
///
/// From schema 2 it embeds a copy of the original's metadata, so the
/// watermarked copy keeps its capture and GPS data even if the original is
/// later deleted.
class WatermarkRecord {
  const WatermarkRecord({
    required this.outputFileName,
    required this.sourceImageFileName,
    required this.sourceMetadataFileName,
    required this.renderedAt,
    required this.imageWidth,
    required this.imageHeight,
    required this.config,
    this.sourceMetadata,
    this.automatic = false,
    this.schemaVersion = currentSchemaVersion,
  });

  factory WatermarkRecord.fromJson(Map<String, dynamic> json) {
    final metadata = json['sourceMetadata'];
    return WatermarkRecord(
      schemaVersion: json['schemaVersion'] as int,
      outputFileName: json['outputFileName'] as String,
      sourceImageFileName: json['sourceImageFileName'] as String,
      sourceMetadataFileName: json['sourceMetadataFileName'] as String,
      renderedAt: DateTime.parse(json['renderedAt'] as String),
      imageWidth: json['imageWidth'] as int,
      imageHeight: json['imageHeight'] as int,
      config: WatermarkConfig.fromJson(json['config'] as Map<String, dynamic>),
      sourceMetadata: metadata is Map<String, dynamic>
          ? PhotoMetadata.fromJson(metadata)
          : null,
      automatic: json['automatic'] == true,
    );
  }

  static const int currentSchemaVersion = 2;

  final int schemaVersion;
  final String outputFileName;
  final String sourceImageFileName;
  final String sourceMetadataFileName;

  /// When the copy was rendered (UTC).
  final DateTime renderedAt;
  final int imageWidth;
  final int imageHeight;
  final WatermarkConfig config;

  /// The original's metadata at render time. Null in schema 1 records.
  final PhotoMetadata? sourceMetadata;

  /// Made by the camera right after capture, not by the user in the
  /// editor. Only such copies are replaced when an address or map that was
  /// missing at capture becomes available.
  final bool automatic;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'outputFileName': outputFileName,
    'sourceImageFileName': sourceImageFileName,
    'sourceMetadataFileName': sourceMetadataFileName,
    'renderedAt': renderedAt.toUtc().toIso8601String(),
    'imageWidth': imageWidth,
    'imageHeight': imageHeight,
    'config': config.toJson(),
    'sourceMetadata': sourceMetadata?.toJson(),
    if (automatic) 'automatic': true,
  };
}
