import 'package:gps_camera/features/gallery/models/gallery_filter.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';

/// Everything found in app storage, with original ↔ watermarked links.
class GalleryIndex {
  GalleryIndex({required List<GalleryPhoto> photos, this.orphanSidecars = 0})
    : photos = _newestFirst(photos) {
    for (final photo in this.photos) {
      if (photo.isOriginal) {
        _originals[photo.fileName] = photo;
      } else if (photo.sourceFileName != null) {
        (_variants[photo.sourceFileName!] ??= []).add(photo);
      }
    }
  }

  static final GalleryIndex empty = GalleryIndex(photos: const []);

  /// Newest first.
  final List<GalleryPhoto> photos;

  /// JSON files whose image is missing. They are never shown.
  final int orphanSidecars;

  final Map<String, GalleryPhoto> _originals = {};
  final Map<String, List<GalleryPhoto>> _variants = {};

  bool get isEmpty => photos.isEmpty;

  int count(GalleryFilter filter) => photos.where(filter.matches).length;

  List<GalleryPhoto> view(GalleryFilter filter, GallerySort sort) {
    final matching = photos.where(filter.matches);
    return switch (sort) {
      GallerySort.newestFirst => matching.toList(),
      GallerySort.oldestFirst => matching.toList().reversed.toList(),
    };
  }

  /// Watermarked copies made from [original], newest first.
  List<GalleryPhoto> variantsOf(GalleryPhoto original) => original.isOriginal
      ? List.unmodifiable(_variants[original.fileName] ?? const [])
      : const [];

  /// The original a watermarked copy was made from, if it still exists.
  GalleryPhoto? sourceOf(GalleryPhoto photo) =>
      photo.isWatermarked && photo.sourceFileName != null
      ? _originals[photo.sourceFileName]
      : null;

  GalleryPhoto? byId(String id) {
    for (final photo in photos) {
      if (photo.id == id) return photo;
    }
    return null;
  }

  static List<GalleryPhoto> _newestFirst(List<GalleryPhoto> photos) {
    final sorted = List<GalleryPhoto>.of(photos)
      ..sort((a, b) => _compare(b, a));
    return List.unmodifiable(sorted);
  }

  static int _compare(GalleryPhoto a, GalleryPhoto b) {
    final byTime = a.savedAt.compareTo(b.savedAt);
    return byTime != 0 ? byTime : a.fileName.compareTo(b.fileName);
  }
}
