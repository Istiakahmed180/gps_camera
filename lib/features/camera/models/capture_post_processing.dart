import 'dart:typed_data';

import 'package:gps_camera/features/camera/models/capture_feedback.dart';
import 'package:gps_camera/features/camera/services/capture_saver.dart';

/// Work done after a photo is safely saved: map snapshot, address lookup
/// and the automatic watermarked copy. Never blocks or fails a capture.
abstract interface class CapturePostProcessor {
  /// Grabs the live map at the moment of capture.
  Future<Uint8List?> grabMap();

  /// Adds place and map to the photo and, if enabled, saves a watermarked
  /// copy. Returns a short message for the user, or null.
  Future<CaptureFeedback?> process(SavedCapture saved, Uint8List? map);
}
