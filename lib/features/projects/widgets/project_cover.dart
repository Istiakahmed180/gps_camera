import 'package:flutter/material.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/shared/widgets/media_thumbnail.dart';

/// A project's cover image, or a folder placeholder.
class ProjectCover extends StatelessWidget {
  const ProjectCover({super.key, required this.path, this.iconSize = 32});

  final String? path;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: context.colors.secondaryContainer,
      child: Center(
        child: Icon(
          Icons.folder_outlined,
          size: iconSize,
          color: context.colors.onSecondaryContainer,
        ),
      ),
    );
    final current = path;
    if (current == null) return placeholder;

    return LayoutBuilder(
      builder: (context, constraints) => MediaThumbnail(
        current,
        cacheWidth: constraints.maxWidth.isFinite
            ? (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                  .round()
            : 400,
        showPlayMark: false,
      ),
    );
  }
}
