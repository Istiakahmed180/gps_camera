import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/features/camera/models/video_details.dart';
import 'package:gps_camera/shared/widgets/media_thumbnail.dart';
import 'package:video_player/video_player.dart';

/// Plays a recorded video with play/pause and a seek bar. Shows its
/// thumbnail until the player is ready.
class VideoPreview extends StatefulWidget {
  const VideoPreview({super.key, required this.path, this.semanticLabel});

  final String path;
  final String? semanticLabel;

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  late final VideoPlayerController _player = VideoPlayerController.file(
    File(widget.path),
  );
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _player.addListener(_changed);
    unawaited(
      _player.initialize().then(
        (_) {
          if (mounted) setState(() {});
        },
        onError: (Object _) {
          if (mounted) setState(() => _failed = true);
        },
      ),
    );
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _player.removeListener(_changed);
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    final value = _player.value;
    if (value.isPlaying) {
      await _player.pause();
    } else {
      if (value.position >= value.duration) await _player.seekTo(Duration.zero);
      await _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _player.value;
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              color: AppColors.onViewfinderMuted,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              'This video cannot be played.'.tr,
              style: const TextStyle(color: AppColors.onViewfinderMuted),
            ),
          ],
        ),
      );
    }
    return Semantics(
      label: widget.semanticLabel,
      child: Stack(
        children: [
          Center(
            child: value.isInitialized
                ? AspectRatio(
                    aspectRatio: value.aspectRatio,
                    child: GestureDetector(
                      onTap: _toggle,
                      child: VideoPlayer(_player),
                    ),
                  )
                : MediaThumbnail(
                    widget.path,
                    fit: BoxFit.contain,
                    showPlayMark: false,
                  ),
          ),
          if (!value.isPlaying)
            Center(
              child: IconButton.filled(
                iconSize: 40,
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
                tooltip: 'Play'.tr,
                onPressed: value.isInitialized ? _toggle : null,
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              ),
            ),
          if (value.isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Controls(player: _player, onToggle: _toggle),
            ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.player, required this.onToggle});

  final VideoPlayerController player;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final value = player.value;
    final total = value.duration.inMilliseconds.toDouble();
    final at = value.position.inMilliseconds.clamp(0, total).toDouble();
    return Container(
      color: Colors.black38,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Directionality(
        // Time runs left to right in every language.
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            IconButton(
              tooltip: value.isPlaying ? 'Pause'.tr : 'Play'.tr,
              onPressed: onToggle,
              icon: Icon(
                value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
            ),
            Text(
              formatVideoDuration(value.position),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Expanded(
              child: Slider(
                value: total == 0 ? 0 : at,
                max: total == 0 ? 1 : total,
                onChanged: total == 0
                    ? null
                    : (v) => player.seekTo(Duration(milliseconds: v.round())),
              ),
            ),
            Text(
              formatVideoDuration(value.duration),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
