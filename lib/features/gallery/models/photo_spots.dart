import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:latlong2/latlong.dart';

/// Photos taken at (about) the same place, shown as one map pin.
class PhotoSpot {
  PhotoSpot(this.point, this.photos);

  final LatLng point;

  /// Newest first.
  final List<GalleryPhoto> photos;

  /// The place name of the newest photo, if it has one.
  String? get title {
    for (final p in photos) {
      final t = p.metadata?.place?.title;
      if (t != null) return t;
    }
    return null;
  }
}

abstract final class PhotoSpots {
  /// Photos closer than this share a pin. Phone GPS is rarely better than
  /// this, so separate pins closer together would only overlap.
  static const double radiusMeters = 30;

  /// Groups [photos] into spots, newest photo first in each. One pin per
  /// capture: a watermarked copy is shown only when its original is not in
  /// the list. Photos without a usable GPS fix are left out.
  static List<PhotoSpot> from(List<GalleryPhoto> photos) {
    final originals = {
      for (final p in photos)
        if (p.isOriginal) p.fileName,
    };
    final located = <(GalleryPhoto, LatLng)>[];
    for (final photo in photos) {
      if (photo.isWatermarked && originals.contains(photo.sourceFileName)) {
        continue;
      }
      final location = photo.metadata?.location;
      final fix = location?.fix;
      if (fix == null || location!.status == LocationRecordStatus.unavailable) {
        continue;
      }
      located.add((photo, LatLng(fix.latitude, fix.longitude)));
    }
    // Newest first, so each spot is anchored at its newest photo.
    located.sort((a, b) => b.$1.savedAt.compareTo(a.$1.savedAt));

    const distance = Distance();
    final spots = <PhotoSpot>[];
    for (final (photo, point) in located) {
      PhotoSpot? near;
      for (final spot in spots) {
        if (distance.as(LengthUnit.Meter, spot.point, point) <= radiusMeters) {
          near = spot;
          break;
        }
      }
      if (near == null) {
        spots.add(PhotoSpot(point, [photo]));
      } else {
        near.photos.add(photo);
      }
    }
    return spots;
  }
}
