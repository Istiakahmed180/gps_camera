import 'package:camera/camera.dart';

/// Capture resolution. Higher values give sharper photos and larger files.
enum PhotoQuality {
  standard(
    'Standard',
    'Full HD, about 2 MP · smallest files',
    ResolutionPreset.veryHigh,
  ),
  high('High', '4K, about 8 MP · recommended', ResolutionPreset.ultraHigh),
  maximum(
    'Maximum',
    'Full camera resolution · largest files, slower to process',
    ResolutionPreset.max,
  );

  const PhotoQuality(this.label, this.description, this.preset);

  final String label;
  final String description;
  final ResolutionPreset preset;

  static const PhotoQuality fallback = PhotoQuality.high;

  static PhotoQuality parse(String? name) => PhotoQuality.values.firstWhere(
    (q) => q.name == name,
    orElse: () => fallback,
  );
}
