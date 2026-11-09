enum WatermarkTemplate {
  /// Full-width dark card: square map, place name, address, time,
  /// coordinates and altitude, each detail line with a small icon.
  mapCard(
    label: 'Map card',
    description: 'Full-width card with a map, place name and details',
  ),

  /// [mapCard] with a round map.
  roundMap(label: 'Round map', description: 'Full-width card with a round map'),

  /// [mapCard] with a round map on the other side.
  mapRight(
    label: 'Map right',
    description: 'Full-width card with the map on the right',
  ),

  /// [mapCard] without a map.
  banner(label: 'Banner', description: 'Full-width card without a map'),

  /// Map snapshot beside the address, coordinates and time.
  map(label: 'Map', description: 'Map, address, coordinates and time'),

  /// White text on a dark translucent panel, compact.
  classic(label: 'Classic', description: 'Compact panel with clean white text'),

  /// Labelled rows with an accent bar, for field documentation.
  professional(
    label: 'Professional',
    description: 'Structured details for inspections and site records',
  ),

  /// Small text with a soft shadow and no panel.
  minimal(label: 'Minimal', description: 'Small, unobtrusive text');

  const WatermarkTemplate({required this.label, required this.description});

  final String label;
  final String description;

  bool get showsMap =>
      this == map || this == mapCard || this == roundMap || this == mapRight;

  /// Spans the photo's width; the position setting does not apply.
  bool get isCard =>
      this == mapCard || this == roundMap || this == mapRight || this == banner;

  bool get roundMapShape => this == roundMap || this == mapRight;

  /// The map sits after the text (on the right in left-to-right languages).
  bool get mapAtEnd => this == mapRight;
}
