abstract final class AppRoutes {
  static const String home = '/';
  static const String camera = '/camera';
  static const String gallery = '/gallery';

  /// Argument: a `GalleryPhoto`.
  static const String photoDetails = '/gallery/photo';
  static const String projects = '/projects';

  /// Argument: project id.
  static const String projectDetails = '/projects/details';

  /// Argument: the `Project` to edit, or null to create one.
  static const String projectEdit = '/projects/edit';

  /// Argument: project id.
  static const String projectAddPhotos = '/projects/add-photos';
  static const String settings = '/settings';

  /// Argument: the original photo's file path.
  static const String watermark = '/watermark';
}
