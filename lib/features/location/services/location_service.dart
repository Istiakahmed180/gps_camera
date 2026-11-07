import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';

enum LocationErrorKind { serviceDisabled, permissionDenied, unavailable }

class LocationException implements Exception {
  const LocationException(this.kind, [this.message]);

  final LocationErrorKind kind;
  final String? message;

  @override
  String toString() => 'LocationException(${kind.name}): $message';
}

/// Platform access for GPS: service status, permission and fixes.
///
/// Stateless: callers own subscriptions and cancel them to stop updates.
class LocationService extends GetxService {
  LocationService(this._permissions);

  /// Android delivers a fix about this often while the stream is open.
  static const Duration updateInterval = Duration(seconds: 2);

  final PermissionService _permissions;

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  /// Emits true/false when the user toggles device location.
  Stream<bool> serviceStatusChanges() => Geolocator.getServiceStatusStream()
      .map((status) => status == ServiceStatus.enabled);

  Future<PermissionAccess> checkPermission() => _permissions.locationStatus();

  Future<PermissionAccess> requestPermission() =>
      _permissions.requestLocation();

  Future<bool> openAppSettings() => _permissions.openSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// A single fresh fix. Throws [LocationException] on failure or timeout.
  Future<LocationFix> currentFix({
    Duration timeLimit = const Duration(seconds: 20),
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _settings(timeLimit: timeLimit),
      );
      final fix = toFix(position);
      if (fix == null) {
        throw const LocationException(
          LocationErrorKind.unavailable,
          'The fix did not include valid coordinates and accuracy.',
        );
      }
      return fix;
    } on TimeoutException {
      throw const LocationException(
        LocationErrorKind.unavailable,
        'No GPS fix within the time limit.',
      );
    } catch (error) {
      throw mapError(error);
    }
  }

  /// Continuous fixes while subscribed. Invalid fixes are dropped and
  /// platform errors are converted to [LocationException].
  Stream<LocationFix> fixes() {
    return Geolocator.getPositionStream(locationSettings: _settings())
        .map(toFix)
        .where((fix) => fix != null)
        .cast<LocationFix>()
        .handleError(
          (Object error) => throw mapError(error),
          test: (error) => error is! LocationException,
        );
  }

  @visibleForTesting
  static LocationFix? toFix(Position position) {
    final valid =
        position.hasAccuracy &&
        position.accuracy.isFinite &&
        position.accuracy >= 0 &&
        position.latitude.isFinite &&
        position.longitude.isFinite &&
        position.latitude.abs() <= 90 &&
        position.longitude.abs() <= 180;
    if (!valid) return null;

    return LocationFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp.toUtc(),
      altitude: position.hasAltitude ? position.altitude : null,
      altitudeReference: position.hasAltitude ? _altitudeReference : null,
      altitudeAccuracy: position.hasAltitudeAccuracy
          ? position.altitudeAccuracy
          : null,
      heading: position.hasHeading ? position.heading : null,
      isMocked: position.isMocked,
    );
  }

  @visibleForTesting
  static LocationException mapError(Object error) {
    return switch (error) {
      LocationException() => error,
      LocationServiceDisabledException() => const LocationException(
        LocationErrorKind.serviceDisabled,
      ),
      PermissionDeniedException() => const LocationException(
        LocationErrorKind.permissionDenied,
      ),
      _ => LocationException(LocationErrorKind.unavailable, '$error'),
    };
  }

  static AltitudeReference get _altitudeReference =>
      switch (defaultTargetPlatform) {
        TargetPlatform.iOS ||
        TargetPlatform.macOS => AltitudeReference.meanSeaLevel,
        _ => AltitudeReference.wgs84Ellipsoid,
      };

  LocationSettings _settings({Duration? timeLimit}) {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
        accuracy: LocationAccuracy.high,
        intervalDuration: updateInterval,
        timeLimit: timeLimit,
      ),
      TargetPlatform.iOS || TargetPlatform.macOS => AppleSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeLimit,
        allowBackgroundLocationUpdates: false,
      ),
      _ => LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeLimit,
      ),
    };
  }
}
