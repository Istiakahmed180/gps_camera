import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/camera/services/photo_exif.dart';
import 'package:gps_camera/features/export/models/gallery_save_mode.dart';
import 'package:gps_camera/features/export/services/phone_gallery.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:path_provider/path_provider.dart';

/// Counts from copying photos to the phone gallery.
class GalleryExportSummary {
  const GalleryExportSummary({
    this.saved = 0,
    this.alreadyThere = 0,
    this.failed = 0,
  });

  final int saved;
  final int alreadyThere;
  final int failed;

  int get total => saved + alreadyThere + failed;

  GalleryExportSummary operator +(PhoneGallerySave outcome) =>
      GalleryExportSummary(
        saved: saved + (outcome == PhoneGallerySave.saved ? 1 : 0),
        alreadyThere:
            alreadyThere + (outcome == PhoneGallerySave.exists ? 1 : 0),
        failed:
            failed +
            (outcome == PhoneGallerySave.failed ||
                    outcome == PhoneGallerySave.unsupported
                ? 1
                : 0),
      );
}

/// Applies the user's [GallerySaveMode] to new and existing photos.
/// Gallery copies are never deleted or changed by the app afterwards.
class GalleryExportService {
  GalleryExportService(
    this._storage,
    this._gallery, {
    Future<Directory> Function()? tempDirectory,
  }) : _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  final StorageService _storage;
  final PhoneGallery _gallery;
  final Future<Directory> Function() _tempDirectory;

  late final Rx<GallerySaveMode> mode = GallerySaveMode.parse(
    _storage.read<String>(StorageKeys.gallerySaveMode),
  ).obs;

  Future<bool> isAvailable() => _gallery.isAvailable();

  Future<void> setMode(GallerySaveMode next) async {
    mode.value = next;
    await _storage.write(StorageKeys.gallerySaveMode, next.name);
  }

  /// Copies a new capture. [watermarked] is null when no copy was made.
  /// Returns false when a copy that should have been saved was not.
  Future<bool> exportCapture({
    required File original,
    File? watermarked,
    PhotoMetadata? metadata,
  }) async {
    final files = _filesFor(mode.value, original, [?watermarked]);
    var ok = true;
    for (final file in files) {
      // New watermarked copies already carry full EXIF.
      final outcome = identical(file, original)
          ? await _saveWithExif(file, metadata, upright: false)
          : await _gallery.save(file, takenAt: metadata?.capturedAt);
      if (outcome == PhoneGallerySave.failed) ok = false;
    }
    return ok;
  }

  /// Saves a gallery copy of [file] whose EXIF carries the capture time
  /// (with time zone) and GPS location, so the phone's gallery and Google
  /// Photos show when and where it was taken. The app's own file is only
  /// read. Falls back to a plain copy if the EXIF cannot be written.
  Future<PhoneGallerySave> _saveWithExif(
    File file,
    PhotoMetadata? metadata, {
    required bool upright,
  }) async {
    final takenAt = metadata?.capturedAt;
    if (metadata == null) return _gallery.save(file, takenAt: takenAt);
    File? temp;
    try {
      final dir = await Directory(
        '${(await _tempDirectory()).path}/gallery_export',
      ).create(recursive: true);
      final target = File('${dir.path}/${file.uri.pathSegments.last}');
      final spec = ExifSpec.from(metadata);
      final written = await Isolate.run(
        () => _writeWithExif(file.path, target.path, spec, upright),
      );
      if (written) temp = target;
    } catch (_) {
      temp = null;
    }
    if (temp == null) return _gallery.save(file, takenAt: takenAt);
    try {
      return await _gallery.save(temp, takenAt: takenAt);
    } finally {
      try {
        await temp.delete();
      } catch (_) {}
    }
  }

  /// Copies a watermarked copy made later in the editor, when the mode
  /// includes watermarked photos.
  Future<bool> exportEdited(File watermarked, {DateTime? takenAt}) async {
    if (!mode.value.savesWatermarked) return true;
    return await _gallery.save(watermarked, takenAt: takenAt) !=
        PhoneGallerySave.failed;
  }

  /// The files [exportExisting] would copy for [index] in the current mode.
  List<GalleryPhoto> plan(GalleryIndex index) {
    final current = mode.value;
    if (current == GallerySaveMode.off) return const [];
    final picked = <GalleryPhoto>[];
    for (final photo in index.photos.reversed) {
      if (photo.isOriginal) {
        final variants = index.variantsOf(photo);
        if (current.savesOriginalAlways || variants.isEmpty) picked.add(photo);
        if (current.savesWatermarked) picked.addAll(variants.reversed);
      } else if (index.sourceOf(photo) == null && current.savesWatermarked) {
        // A copy whose original was deleted.
        picked.add(photo);
      }
    }
    return picked;
  }

  /// Copies everything already in the app, oldest first. Photos this app
  /// put in the gallery before are skipped, so it is safe to run again.
  Future<GalleryExportSummary> exportExisting(
    GalleryIndex index, {
    void Function(int done, int total)? onProgress,
  }) async {
    final photos = plan(index);
    var summary = const GalleryExportSummary();
    for (var i = 0; i < photos.length; i++) {
      onProgress?.call(i, photos.length);
      final photo = photos[i];
      summary += await _saveWithExif(
        photo.file,
        photo.metadata,
        upright: photo.isWatermarked,
      );
    }
    onProgress?.call(photos.length, photos.length);
    return summary;
  }

  static List<File> _filesFor(
    GallerySaveMode mode,
    File original,
    List<File> watermarked,
  ) => [
    if (mode.savesOriginalAlways ||
        (mode == GallerySaveMode.watermarked && watermarked.isEmpty))
      original,
    if (mode.savesWatermarked) ...watermarked,
  ];
}

/// Copies [source] to [target] with fresh EXIF; the pixels are untouched.
bool _writeWithExif(String source, String target, ExifSpec spec, bool upright) {
  final Uint8List bytes = File(source).readAsBytesSync();
  final updated = PhotoExif.apply(bytes, spec, upright: upright);
  if (updated == null) return false;
  File(target).writeAsBytesSync(updated, flush: true);
  return true;
}
