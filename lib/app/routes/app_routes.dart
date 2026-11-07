abstract final class AppRoutes {
  static const String home = '/';
  static const String camera = '/camera';
  static const String gallery = '/gallery';

  /// Argument: a `GalleryPhoto`.
  static const String photoDetails = '/gallery/photo';
  static const String projects = '/projects';
  static const String settings = '/settings';

  /// Argument: the original photo's file path.
  static const String watermark = '/watermark';
}
