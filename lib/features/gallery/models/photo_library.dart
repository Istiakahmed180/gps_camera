import 'package:get/get.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/projects/models/project.dart';

/// A set of photos a details screen was opened from: the whole gallery or
/// one project. Lets photo details work the same from both.
abstract interface class PhotoLibrary {
  Rx<GalleryIndex> get index;

  /// The project [photo] belongs to. Watermarked copies resolve through
  /// their original.
  ProjectRef? projectOf(GalleryPhoto photo);

  /// Rescans files and reloads project assignments.
  Future<void> reload();

  /// Reloads project assignments only, without rescanning files.
  Future<void> reloadAssignments();

  Future<void> openPhoto(GalleryPhoto photo);
}

/// Route arguments for the photo details screen.
class PhotoDetailsArgs {
  const PhotoDetailsArgs({required this.photo, required this.library});

  final GalleryPhoto photo;
  final PhotoLibrary library;
}
