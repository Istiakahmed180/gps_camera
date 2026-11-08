import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/features/camera/models/video_details.dart';
import 'package:gps_camera/features/video/services/video_service.dart';

/// A photo, or a frame of a video with a play mark, sized for a tile.
class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail(
    this.path, {
    super.key,
    this.cacheWidth,
    this.cacheHeight,
    this.fit = BoxFit.cover,
    this.duration,
    this.showPlayMark = true,
  });

  final String path;
  final int? cacheWidth;
  final int? cacheHeight;
  final BoxFit fit;

  /// Shown on video thumbnails, e.g. `0:42`.
  final Duration? duration;
  final bool showPlayMark;

  @override
  Widget build(BuildContext context) {
    if (!isVideoPath(path)) return _image(File(path));
    final service = Get.isRegistered<VideoService>()
        ? Get.find<VideoService>()
        : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (service == null)
          const _Placeholder()
        else
          FutureBuilder<File?>(
            future: service.thumbnail(path),
            builder: (context, snap) {
              final file = snap.data;
              if (file == null) return const _Placeholder();
              return _image(file);
            },
          ),
        if (showPlayMark) _PlayMark(duration: duration),
      ],
    );
  }

  Widget _image(File file) => Image.file(
    file,
    fit: fit,
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => const _Placeholder(broken: true),
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.broken = false});

  final bool broken;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black26,
    child: Center(
      child: Icon(
        broken ? Icons.broken_image_outlined : Icons.videocam_outlined,
        color: Colors.white70,
      ),
    ),
  );
}

class _PlayMark extends StatelessWidget {
  const _PlayMark({this.duration});

  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.bottomEnd,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
            if (duration != null) ...[
              const SizedBox(width: 2),
              Text(
                formatVideoDuration(duration!),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
