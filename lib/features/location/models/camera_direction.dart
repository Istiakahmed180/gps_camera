import 'package:get/get.dart';

/// Which way the camera faced when a photo was taken, from the phone's
/// compass.
class CameraDirection {
  const CameraDirection({
    required this.degrees,
    this.accuracy,
    this.trueNorth = true,
    this.flat = false,
  });

  factory CameraDirection.fromJson(Map<String, dynamic> json) =>
      CameraDirection(
        degrees: (json['degrees'] as num).toDouble(),
        accuracy: (json['accuracy'] as num?)?.toDouble(),
        trueNorth: json['trueNorth'] != false,
        flat: json['flat'] == true,
      );

  /// 0–360, clockwise from north.
  final double degrees;

  /// Estimated error in degrees, when the phone reports one.
  final double? accuracy;

  /// False when only magnetic north was known (no location for the
  /// declination correction).
  final bool trueNorth;

  /// The phone was held nearly flat, so this is the direction of its top
  /// edge rather than of the lens.
  final bool flat;

  /// Errors above this are shown as approximate.
  static const double preciseWithin = 20;

  bool get isApproximate => accuracy != null && accuracy! > preciseWithin;

  static const List<String> _points = [
    'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', //
  ];

  /// `N`, `NE`, … for [degrees].
  String get cardinal => _points[((normalize(degrees) + 22.5) ~/ 45) % 8];

  /// `45° NE`, or `≈45° NE` when approximate.
  String get label =>
      '${isApproximate ? '≈' : ''}${normalize(degrees).round() % 360}° $cardinal';

  /// `45° NE (true north, ±12°)`, noting magnetic north or a flat phone.
  String get description {
    final parts = [
      (trueNorth ? 'true north' : 'magnetic north').tr,
      if (accuracy != null) '±${accuracy!.round()}°',
      if (flat) 'phone held flat'.tr,
    ];
    return '$label (${parts.join(', ')})';
  }

  static double normalize(double value) {
    final v = value % 360;
    return v < 0 ? v + 360 : v;
  }

  Map<String, dynamic> toJson() => {
    'degrees': degrees,
    'accuracy': ?accuracy,
    'trueNorth': trueNorth,
    if (flat) 'flat': true,
  };

  @override
  bool operator ==(Object other) =>
      other is CameraDirection &&
      other.degrees == degrees &&
      other.accuracy == accuracy &&
      other.trueNorth == trueNorth &&
      other.flat == flat;

  @override
  int get hashCode => Object.hash(degrees, accuracy, trueNorth, flat);
}
