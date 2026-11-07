import 'package:gps_camera/features/gallery/models/gallery_photo.dart';

/// Stable photo keys stored in the database: paths relative to the
/// `GPSCamera/` folder, so they survive app container moves on iOS.
abstract final class PhotoRefs {
  static const String _photos = 'Photos';
  static const String _watermarked = 'Watermarked';

  static String original(String fileName) => '$_photos/$fileName';

  /// The file itself (original or watermarked copy), e.g. for covers.
  static String of(GalleryPhoto photo) => photo.isOriginal
      ? original(photo.fileName)
      : '$_watermarked/${photo.fileName}';

  /// The original whose project assignment applies to [photo]. For a
  /// watermarked copy this is its source; null if that is unknown.
  static String? assignmentKey(GalleryPhoto photo) {
    if (photo.isOriginal) return original(photo.fileName);
    final source = photo.sourceFileName;
    return source == null ? null : original(source);
  }

  /// Absolute path of [ref] under [rootPath].
  static String resolve(String rootPath, String ref) => '$rootPath/$ref';
}
