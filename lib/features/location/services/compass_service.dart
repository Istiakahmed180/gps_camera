import 'dart:async';

import 'package:flutter/services.dart';

/// One raw reading from the phone: magnetic heading of the back camera.
class CompassReading {
  const CompassReading({
    required this.magneticDegrees,
    this.accuracy,
    this.flat = false,
  });

  final double magneticDegrees;

  /// Estimated error in degrees; null when the phone gives none.
  final double? accuracy;
  final bool flat;
}

/// The phone's compass. Readings stop when nobody listens, so the sensor
/// only runs while the camera screen is open.
class CompassService {
  CompassService({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('co.tdevs.gps_camera/native'),
      _events = events ?? const EventChannel('co.tdevs.gps_camera/compass');

  final MethodChannel _methods;
  final EventChannel _events;

  Future<bool> isAvailable() async {
    try {
      return await _methods.invokeMethod<bool>('compassAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  Stream<CompassReading> readings() =>
      _events.receiveBroadcastStream().map((event) {
        final map = event as Map<Object?, Object?>;
        final accuracy = (map['accuracy'] as num?)?.toDouble();
        return CompassReading(
          magneticDegrees: (map['degrees'] as num).toDouble(),
          accuracy: accuracy == null || accuracy < 0 ? null : accuracy,
          flat: map['flat'] == true,
        );
      });

  /// Degrees to add to a magnetic heading to get true north here, or null.
  Future<double?> declination(
    double latitude,
    double longitude, {
    double altitude = 0,
  }) async {
    try {
      return await _methods.invokeMethod<double>('declination', {
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
      });
    } catch (_) {
      return null;
    }
  }
}
