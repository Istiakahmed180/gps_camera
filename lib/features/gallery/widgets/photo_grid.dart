import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/widgets/photo_grid_item.dart';

/// Lazily built grid: only visible cells decode their thumbnails.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    super.key,
    required this.photos,
    required this.index,
    required this.onOpen,
  });

  static const double maxCellExtent = 180;

  final List<GalleryPhoto> photos;
  final GalleryIndex index;
  final ValueChanged<GalleryPhoto> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - AppSpacing.lg * 2;
        final columns = (available / maxCellExtent).ceil().clamp(2, 8);
        final cell = available / columns;
        final decodeWidth = (cell * MediaQuery.devicePixelRatioOf(context))
            .round();

        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
          ),
          itemCount: photos.length,
          itemBuilder: (_, i) {
            final photo = photos[i];
            return PhotoGridItem(
              key: ValueKey(photo.id),
              photo: photo,
              decodeWidth: decodeWidth,
              hasOriginal: photo.isOriginal || index.sourceOf(photo) != null,
              onTap: () => onOpen(photo),
            );
          },
        );
      },
    );
  }
}
