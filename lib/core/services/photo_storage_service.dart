import 'dart:io';

import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

/// Stores original captures in app-private storage:
/// `<ApplicationDocuments>/GPSCamera/Photos/IMG_yyyyMMdd_HHmmss_SSS.jpg`.
class PhotoStorageService extends GetxService {
  static const String _rootFolder = 'GPSCamera';
  static const String _photosFolder = 'Photos';

  Future<Directory> photosDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documents.path}/$_rootFolder/$_photosFolder',
    );
    return directory.create(recursive: true);
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
    final source = File(capture.path);

    await capture.saveTo(target.path);

    final sourceLength = await source.length();
    if (sourceLength == 0 ||
        !await target.exists() ||
        await target.length() != sourceLength) {
      throw FileSystemException('Captured photo was not written', target.path);
    }

    await _deleteTemporary(source);
    return target;
  }

  Future<void> _deleteTemporary(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // The OS clears the cache directory eventually.
    }
  }

  Future<File> _uniqueFile(Directory directory, DateTime time) async {
    final baseName = 'IMG_${_timestamp(time)}';
    var candidate = File('${directory.path}/$baseName.jpg');
    var suffix = 1;
    while (await candidate.exists()) {
      candidate = File('${directory.path}/${baseName}_$suffix.jpg');
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
