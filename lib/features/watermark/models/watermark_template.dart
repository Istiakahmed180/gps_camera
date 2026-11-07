enum WatermarkTemplate {
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
}
