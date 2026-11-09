import 'dart:io';

import 'package:flutter/services.dart';

enum PhoneGallerySave {
  saved,

  /// This app already added a gallery photo with that name.
  exists,

  /// Needs Android 10 or later.
  unsupported,
  failed,
}

/// Copies app photos into the phone's shared Pictures/Locaproof folder.
/// No storage permission is used: Android 10+ lets apps add their own media.
class PhoneGallery {
  PhoneGallery([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('co.tdevs.gps_camera/native');

  final MethodChannel _channel;
  bool? _available;

  Future<bool> isAvailable() async {
    if (_available != null) return _available!;
    try {
      _available =
          await _channel.invokeMethod<bool>('galleryAvailable') ?? false;
    } on PlatformException {
      _available = false;
    } on MissingPluginException {
      _available = false;
    }
    return _available!;
  }

  /// Saves [file] under its own name. The app's file is only read.
  Future<PhoneGallerySave> save(File file, {DateTime? takenAt}) async {
    if (!await isAvailable()) return PhoneGallerySave.unsupported;
    try {
      final outcome = await _channel.invokeMethod<String>('saveToGallery', {
        'path': file.path,
        'name': file.uri.pathSegments.last,
        'takenAt': ?takenAt?.millisecondsSinceEpoch,
      });
      return switch (outcome) {
        'saved' => PhoneGallerySave.saved,
        'exists' => PhoneGallerySave.exists,
        'unsupported' => PhoneGallerySave.unsupported,
        _ => PhoneGallerySave.failed,
      };
    } on PlatformException {
      return PhoneGallerySave.failed;
    } on MissingPluginException {
      return PhoneGallerySave.failed;
    }
  }
}
