/// Which files are copied to the phone's gallery (Pictures/GPS Camera).
enum GallerySaveMode {
  /// Nothing leaves app storage.
  off('Don’t save', 'Photos stay inside the app only.'),

  /// The watermarked copy, or the original when there is no copy.
  watermarked(
    'Watermarked photo',
    'The watermarked copy, or the original if no copy was made.',
  ),

  original('Original photo', 'The untouched original only.'),

  both('Both', 'The original and every watermarked copy.');

  const GallerySaveMode(this.label, this.description);

  final String label;
  final String description;

  static const GallerySaveMode fallback = GallerySaveMode.watermarked;

  static GallerySaveMode parse(String? name) => GallerySaveMode.values
      .firstWhere((m) => m.name == name, orElse: () => fallback);

  bool get savesOriginalAlways => this == original || this == both;

  bool get savesWatermarked => this == watermarked || this == both;
}
