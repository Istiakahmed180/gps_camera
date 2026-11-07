import 'package:gps_camera/features/gallery/models/gallery_photo.dart';

enum GalleryFilter {
  all('All'),
  originals('Originals'),
  watermarked('Watermarked');

  const GalleryFilter(this.label);

  final String label;

  bool matches(GalleryPhoto photo) => switch (this) {
    GalleryFilter.all => true,
    GalleryFilter.originals => photo.isOriginal,
    GalleryFilter.watermarked => photo.isWatermarked,
  };
}

enum GallerySort {
  newestFirst('Newest first'),
  oldestFirst('Oldest first');

  const GallerySort(this.label);

  final String label;
}
