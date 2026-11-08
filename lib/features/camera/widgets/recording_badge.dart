import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/features/camera/models/video_details.dart';

/// "● 0:42" while recording, or how far the last video's stamp has got.
class RecordingBadge extends StatelessWidget {
  const RecordingBadge({
    super.key,
    required this.isRecording,
    required this.elapsed,
    required this.limit,
    this.stampProgress,
  });

  final bool isRecording;
  final Duration elapsed;
  final Duration limit;

  /// 0 to 1 while a finished video is being stamped.
  final double? stampProgress;

  @override
  Widget build(BuildContext context) {
    final stamping = stampProgress;
    if (!isRecording && stamping == null) return const SizedBox.shrink();
    final text = isRecording
        ? formatVideoDuration(elapsed)
        : 'Stamping video @percent%'.trParams({
            'percent': '${(stamping! * 100).round()}',
          });
    final nearLimit =
        isRecording && limit - elapsed < const Duration(minutes: 1);
    return Semantics(
      liveRegion: true,
      label: isRecording ? 'Recording @time'.trParams({'time': text}) : text,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isRecording ? AppColors.recording : Colors.black54,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRecording)
              const Icon(
                Icons.fiber_manual_record,
                size: 12,
                color: Colors.white,
              )
            else
              const SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            const SizedBox(width: 6),
            Text(
              nearLimit
                  ? '@time / @limit'.trParams({
                      'time': text,
                      'limit': formatVideoDuration(limit),
                    })
                  : text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
