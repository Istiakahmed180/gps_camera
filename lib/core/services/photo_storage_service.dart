import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

/// App-private photo storage under `<ApplicationDocuments>/GPSCamera/`:
///
/// * `Photos/IMG_<timestamp>.jpg` — original captures, never modified.
/// * `Photos/IMG_<timestamp>.json` — capture metadata sidecar.
/// * `Photos/VID_<timestamp>.mp4` — recorded videos, with the same `.json`
///   sidecar (plus video details).
/// * `Watermarked/IMG_<timestamp>_wm[_n].jpg` (or `VID_…_wm.mp4`) — stamped
///   copies, each with a `.json` render record naming its original.
/// * `Thumbnails/<video name>.jpg` — a frame of each video, made on demand
///   and safe to delete.
class PhotoStorageService extends GetxService {
  static const String _rootFolder = 'GPSCamera';
  static const String _photosFolder = 'Photos';
  static const String _watermarkedFolder = 'Watermarked';
  static const String _reportsFolder = 'Reports';
  static const String _mapsFolder = 'Maps';
  static const String _brandingFolder = 'Branding';
  static const String _thumbnailsFolder = 'Thumbnails';

  /// `<ApplicationDocuments>/GPSCamera`. Database rows store photo paths
  /// relative to this folder.
  Future<Directory> rootDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/$_rootFolder');
  }

  Future<Directory> photosDirectory() => _directory(_photosFolder);

  Future<Directory> watermarkedDirectory() => _directory(_watermarkedFolder);

  /// The watermark logo, `Branding/logo.png`, whether or not it exists.
  Future<File> logoFile() async =>
      File('${(await _directory(_brandingFolder)).path}/logo.png');

  /// The logo's PNG bytes, or null when none was chosen.
  Future<Uint8List?> readLogo() async {
    try {
      final file = await logoFile();
      return await file.exists() ? await file.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }

  /// Map snapshots taken at capture, `<photo base>_map.png`.
  Future<Directory> mapsDirectory() => _directory(_mapsFolder);

  /// Saves the capture-time map for [photo] (temp file, then rename).
  Future<File> saveMapImage(File photo, List<int> png) async {
    final directory = await mapsDirectory();
    final target = File('${directory.path}/${mapImageNameFor(photo.path)}');
    final temp = File('${target.path}.tmp');
    await temp.writeAsBytes(png, flush: true);
    return temp.rename(target.path);
  }

  /// `IMG_x.jpg` → `IMG_x_map.png`. Pure, usable from isolates.
  static String mapImageNameFor(String photoPath) {
    final name = photoPath.substring(photoPath.lastIndexOf('/') + 1);
    final dot = name.lastIndexOf('.');
    return '${dot > 0 ? name.substring(0, dot) : name}_map.png';
  }

  /// The map snapshot file for [photo], whether or not it exists.
  Future<File> mapImageFor(File photo) async =>
      File('${(await mapsDirectory()).path}/${mapImageNameFor(photo.path)}');

  /// Video thumbnails; a cache that is rebuilt when missing.
  Future<Directory> thumbnailsDirectory() => _directory(_thumbnailsFolder);

  /// The thumbnail for the video at [videoPath], whether or not it exists.
  Future<File> thumbnailFileFor(String videoPath) async => File(
    '${(await thumbnailsDirectory()).path}/'
    '${videoPath.substring(videoPath.lastIndexOf('/') + 1)}.jpg',
  );

  /// Generated PDF reports, each with a `.json` record.
  Future<Directory> reportsDirectory() => _directory(_reportsFolder);

  /// Claims a new, unused `<baseName>[_n].pdf` in the reports folder by
  /// creating it exclusively, so reports never overwrite each other.
  Future<File> reserveReportFile(String baseName) async {
    final directory = await reportsDirectory();
    for (var suffix = 0; ; suffix++) {
      final name = suffix == 0 ? baseName : '${baseName}_$suffix';
      final candidate = File('${directory.path}/$name.pdf');
      if (await metadataFileFor(candidate).exists()) continue;
      try {
        await candidate.create(exclusive: true);
        return candidate;
      } on FileSystemException {
        if (!await candidate.exists()) rethrow;
      }
    }
  }

  Future<Directory> _directory(String name) async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/$_rootFolder/$name')
        .create(recursive: true);
  }

  /// Copies the captured image into the photos directory and returns the
  /// saved file. The plugin's temporary file is removed only after the copy
  /// is verified. Throws [FileSystemException] if the photo cannot be stored.
  ///
  /// A copy is used instead of a rename so Android accounts the photo as app
  /// data rather than cache.
  Future<File> savePhoto(XFile capture, {DateTime? capturedAt}) async {
    final directory = await photosDirectory();
    final target = await _uniqueFile(directory, capturedAt ?? DateTime.now());
    return _copyCapture(capture, target);
  }

  /// Like [savePhoto], for a recorded video: `Photos/VID_<timestamp>.mp4`,
  /// named after the time recording started.
  Future<File> saveVideo(XFile capture, {required DateTime startedAt}) async {
    final directory = await photosDirectory();
    final target = await _uniqueFile(
      directory,
      startedAt,
      prefix: 'VID',
      extension: 'mp4',
    );
    return _copyCapture(capture, target);
  }

  /// While a video records: its start time, location and track, so it can
  /// be recovered if Android closes the app before it is saved.
  Future<File> recordingJournalFile() async =>
      File('${(await rootDirectory()).path}/recording.json');

  Future<File> _copyCapture(XFile capture, File target) async {
    final source = File(capture.path);

    await capture.saveTo(target.path);

    final sourceLength = await source.length();
    if (sourceLength == 0 ||
        !await target.exists() ||
        await target.length() != sourceLength) {
      throw FileSystemException('Capture was not written', target.path);
    }

    await _deleteTemporary(source);
    return target;
  }

  /// True when [file] lives in the `Watermarked/` folder. Such files are
  /// outputs and must never be used as a watermark source.
  bool isWatermarkedFile(File file) {
    final segments = file.absolute.uri.pathSegments;
    return segments.length >= 2 &&
        segments[segments.length - 2] == _watermarkedFolder;
  }

  /// The sidecar for [photo]: same folder and base name, `.json` extension.
  File metadataFileFor(File photo) => File(sidecarPathFor(photo.path));

  /// Pure path helper, usable from background isolates.
  static String sidecarPathFor(String imagePath) {
    final dot = imagePath.lastIndexOf('.');
    final base = dot > imagePath.lastIndexOf('/')
        ? imagePath.substring(0, dot)
        : imagePath;
    return '$base.json';
  }

  /// Writes [json] next to [photo] atomically (temp file, then rename), so a
  /// crash never leaves a half-written sidecar.
  Future<File> saveMetadata(File photo, Map<String, dynamic> json) =>
      writeJsonAtomic(metadataFileFor(photo), json);

  /// The decoded sidecar of [photo], or null when it has none.
  /// Throws [FormatException] if the file exists but is not a JSON object.
  Future<Map<String, dynamic>?> readMetadata(File photo) async {
    final file = metadataFileFor(photo);
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Metadata is not a JSON object');
    }
    return decoded;
  }

  Future<File> writeJsonAtomic(File target, Map<String, dynamic> json) async {
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
      flush: true,
    );
    return temp.rename(target.path);
  }

  /// Claims a new, unused output path for a watermarked copy of [original]
  /// by creating an empty placeholder exclusively, so two saves can never
  /// pick the same name. Callers replace the placeholder via rename, or call
  /// [releaseReservation] on failure.
  Future<File> reserveWatermarkedFile(File original) async {
    final directory = await watermarkedDirectory();
    final base = original.uri.pathSegments.last.replaceFirst(
      RegExp(r'\.[^.]*$'),
      '',
    );
    final name = original.uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    final extension = dot > 0 ? name.substring(dot + 1).toLowerCase() : 'jpg';
    for (var suffix = 0; ; suffix++) {
      final name = suffix == 0 ? '${base}_wm' : '${base}_wm_$suffix';
      final candidate = File('${directory.path}/$name.$extension');
      if (await metadataFileFor(candidate).exists()) continue;
      try {
        await candidate.create(exclusive: true);
        return candidate;
      } on FileSystemException {
        if (!await candidate.exists()) rethrow;
      }
    }
  }

  /// Removes an unused reservation and any temp file next to it.
  Future<void> releaseReservation(File reserved) async {
    for (final file in [reserved, File('${reserved.path}.tmp')]) {
      await _deleteTemporary(file);
    }
  }

  Future<void> _deleteTemporary(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // The OS clears the cache directory eventually.
    }
  }

  Future<File> _uniqueFile(
    Directory directory,
    DateTime time, {
    String prefix = 'IMG',
    String extension = 'jpg',
  }) async {
    final baseName = '${prefix}_${_timestamp(time)}';
    var candidate = File('${directory.path}/$baseName.$extension');
    var suffix = 1;
    while (await candidate.exists() ||
        await metadataFileFor(candidate).exists()) {
      candidate = File('${directory.path}/${baseName}_$suffix.$extension');
      suffix++;
    }
    return candidate;
  }

  String _timestamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    final date = '${t.year}${two(t.month)}${two(t.day)}';
    final time = '${two(t.hour)}${two(t.minute)}${two(t.second)}';
    return '${date}_${time}_${t.millisecond.toString().padLeft(3, '0')}';
  }
}
