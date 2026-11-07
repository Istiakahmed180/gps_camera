import 'package:gps_camera/features/watermark/models/watermark_template.dart';

enum WatermarkPosition {
  bottomLeft('Left'),
  bottomCenter('Center'),
  bottomRight('Right');

  const WatermarkPosition(this.label);

  final String label;
}

enum WatermarkTextSize {
  small('S', 0.8),
  medium('M', 1),
  large('L', 1.25);

  const WatermarkTextSize(this.label, this.scale);

  final String label;
  final double scale;
}

/// User-selected watermark settings. Persisted as JSON.
class WatermarkConfig {
  const WatermarkConfig({
    this.template = WatermarkTemplate.classic,
    this.showDate = true,
    this.showTime = true,
    this.showCoordinates = true,
    this.showAccuracy = true,
    this.showAddress = true,
    this.textSize = WatermarkTextSize.medium,
    this.opacity = 1,
    this.position = WatermarkPosition.bottomLeft,
  });

  /// Restores saved settings. Unknown or invalid values fall back to the
  /// defaults instead of failing, so an old or corrupted entry never blocks
  /// the editor.
  factory WatermarkConfig.fromJson(Map<String, dynamic> json) {
    const fallback = WatermarkConfig();
    T pick<T extends Enum>(List<T> values, Object? name, T orElse) =>
        values.firstWhere((v) => v.name == name, orElse: () => orElse);
    bool flag(String key, bool orElse) => switch (json[key]) {
      final bool value => value,
      _ => orElse,
    };
    final opacity = json['opacity'];

    return WatermarkConfig(
      template: pick(
        WatermarkTemplate.values,
        json['template'],
        fallback.template,
      ),
      showDate: flag('showDate', fallback.showDate),
      showTime: flag('showTime', fallback.showTime),
      showCoordinates: flag('showCoordinates', fallback.showCoordinates),
      showAccuracy: flag('showAccuracy', fallback.showAccuracy),
      showAddress: flag('showAddress', fallback.showAddress),
      textSize: pick(
        WatermarkTextSize.values,
        json['textSize'],
        fallback.textSize,
      ),
      opacity: opacity is num
          ? clampOpacity(opacity.toDouble())
          : fallback.opacity,
      position: pick(
        WatermarkPosition.values,
        json['position'],
        fallback.position,
      ),
    );
  }

  static const double minOpacity = 0.4;

  static double clampOpacity(double value) =>
      value.clamp(minOpacity, 1).toDouble();

  final WatermarkTemplate template;
  final bool showDate;
  final bool showTime;
  final bool showCoordinates;
  final bool showAccuracy;
  final bool showAddress;
  final WatermarkTextSize textSize;

  /// Applies to the whole watermark, between [minOpacity] and 1.
  final double opacity;
  final WatermarkPosition position;

  WatermarkConfig copyWith({
    WatermarkTemplate? template,
    bool? showDate,
    bool? showTime,
    bool? showCoordinates,
    bool? showAccuracy,
    bool? showAddress,
    WatermarkTextSize? textSize,
    double? opacity,
    WatermarkPosition? position,
  }) {
    return WatermarkConfig(
      template: template ?? this.template,
      showDate: showDate ?? this.showDate,
      showTime: showTime ?? this.showTime,
      showCoordinates: showCoordinates ?? this.showCoordinates,
      showAccuracy: showAccuracy ?? this.showAccuracy,
      showAddress: showAddress ?? this.showAddress,
      textSize: textSize ?? this.textSize,
      opacity: opacity == null ? this.opacity : clampOpacity(opacity),
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() => {
    'template': template.name,
    'showDate': showDate,
    'showTime': showTime,
    'showCoordinates': showCoordinates,
    'showAccuracy': showAccuracy,
    'showAddress': showAddress,
    'textSize': textSize.name,
    'opacity': opacity,
    'position': position.name,
  };

  @override
  bool operator ==(Object other) =>
      other is WatermarkConfig &&
      other.template == template &&
      other.showDate == showDate &&
      other.showTime == showTime &&
      other.showCoordinates == showCoordinates &&
      other.showAccuracy == showAccuracy &&
      other.showAddress == showAddress &&
      other.textSize == textSize &&
      other.opacity == opacity &&
      other.position == position;

  @override
  int get hashCode => Object.hash(
    template,
    showDate,
    showTime,
    showCoordinates,
    showAccuracy,
    showAddress,
    textSize,
    opacity,
    position,
  );
}
