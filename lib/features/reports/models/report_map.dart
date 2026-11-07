import 'dart:math' as math;
import 'dart:typed_data';

import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/location/services/place_service.dart';
import 'package:gps_camera/features/reports/models/report_models.dart';

/// One numbered pin on the report's overview map. Photos within
/// [ReportMapPins.radiusMeters] share a pin, labelled with the first
/// photo's number.
class ReportMapPin {
  const ReportMapPin({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.entries,
    this.place,
  });

  final int label;
  final double latitude;
  final double longitude;

  /// Report entry numbers (#) at this pin, ascending.
  final List<int> entries;

  /// Place name of the first photo here, when known.
  final String? place;
}

/// The overview map image and the pins drawn on it.
class ReportMap {
  const ReportMap({required this.image, required this.pins, this.omitted = 0});

  final Uint8List image;
  final List<ReportMapPin> pins;

  /// Locations left off the map because there were too many.
  final int omitted;
}

abstract final class ReportMapPins {
  /// Photos closer than this share one pin.
  static const double radiusMeters = 30;

  /// Most pins drawn; more would not fit in the map request or be readable.
  static const int maxPins = 40;

  /// Pins for every entry with a usable location, in report order.
  static List<ReportMapPin> from(List<ReportEntry> entries) {
    final pins = <_Pin>[];
    for (final (i, entry) in entries.indexed) {
      final location = entry.metadata?.location;
      final fix = location?.fix;
      if (fix == null || location!.status == LocationRecordStatus.unavailable) {
        continue;
      }
      final near = pins.where(
        (p) =>
            PlaceService.distanceMeters(
              p.latitude,
              p.longitude,
              fix.latitude,
              fix.longitude,
            ) <=
            radiusMeters,
      );
      if (near.isEmpty) {
        pins.add(
          _Pin(fix.latitude, fix.longitude, entry.metadata?.place?.title)
            ..entries.add(i + 1),
        );
      } else {
        near.first.entries.add(i + 1);
      }
    }
    return [
      for (final p in pins)
        ReportMapPin(
          label: p.entries.first,
          latitude: p.latitude,
          longitude: p.longitude,
          entries: List.unmodifiable(p.entries),
          place: p.place,
        ),
    ];
  }
}

class _Pin {
  _Pin(this.latitude, this.longitude, this.place);

  final double latitude;
  final double longitude;
  final String? place;
  final List<int> entries = [];
}

/// Centre and zoom that show every pin with a margin, in Web Mercator.
class MapFit {
  const MapFit(this.latitude, this.longitude, this.zoom);

  final double latitude;
  final double longitude;
  final double zoom;

  /// Fits [pins] in a [width]×[height] map (logical pixels), leaving room
  /// at the edges and above each pin for its marker.
  static MapFit of(
    List<ReportMapPin> pins, {
    required int width,
    required int height,
    double maxZoom = 17,
    double minZoom = 2,
  }) {
    double x(double lng) => (lng + 180) / 360;
    double y(double lat) {
      final r = lat.clamp(-85.0, 85.0) * math.pi / 180;
      return (1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2;
    }

    final xs = [for (final p in pins) x(p.longitude)];
    final ys = [for (final p in pins) y(p.latitude)];
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final cx = (minX + maxX) / 2;
    // Shift up a little: markers rise above their point.
    final cy = (minY + maxY) / 2;

    var zoom = maxZoom;
    final dx = maxX - minX, dy = maxY - minY;
    if (dx > 0 || dy > 0) {
      final zx = dx == 0 ? maxZoom : _log2(width * 0.8 / (worldSize * dx));
      final zy = dy == 0
          ? maxZoom
          : _log2((height * 0.75 - 40) / (worldSize * dy));
      zoom = math.min(math.min(zx, zy), maxZoom);
      zoom = (zoom * 10).floorToDouble() / 10;
    }
    zoom = zoom.clamp(minZoom, maxZoom);

    final lng = cx * 360 - 180;
    final n = math.pi - 2 * math.pi * cy;
    final lat = 180 / math.pi * math.atan((math.exp(n) - math.exp(-n)) / 2);
    return MapFit(lat, lng, zoom);
  }

  /// The map service's world width at zoom 0, in logical pixels. Geoapify
  /// uses 512 px tiles, so each zoom level is twice that of 256 px maps.
  static const double worldSize = 512;

  static double _log2(double v) => math.log(v) / math.ln2;
}
