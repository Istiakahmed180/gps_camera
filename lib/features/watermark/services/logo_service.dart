import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/watermark/services/watermark_renderer.dart';
import 'package:image/image.dart' as img;

class LogoException implements Exception {
  const LogoException(this.message);

  final String message;
}

/// The watermark logo: chosen once, stored as a small PNG in
/// `GPSCamera/Branding/` and drawn by every watermark that enables it.
class LogoService extends GetxService {
  LogoService(this._storage, {MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.locaproof.app/native');

  /// Longest side kept. Larger logos are scaled down; the watermark draws
  /// it at most a few hundred pixels tall even on full-resolution photos.
  static const int maxSide = 512;

  final PhotoStorageService _storage;
  final MethodChannel _channel;

  /// The decoded logo for previews; null when none is set.
  final Rxn<ui.Image> image = Rxn<ui.Image>();

  @override
  void onInit() {
    super.onInit();
    unawaited(_init());
  }

  Future<void> _init() async {
    await reload();
    await _recoverPending();
  }

  /// When Android stops the app while the picker is open (low memory), the
  /// chosen image arrives after a restart. Use it, so the choice isn't lost.
  Future<void> _recoverPending() async {
    String? path;
    try {
      path = await _channel.invokeMethod<String>('pendingImage');
    } catch (_) {
      return;
    }
    if (path == null) return;
    final file = File(path);
    try {
      await setFrom(file);
      onRecovered?.call();
    } catch (_) {
      // Not a usable image; the user can pick again.
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  /// Called after a logo picked before a restart was applied.
  VoidCallback? onRecovered;

  @override
  void onClose() {
    image.value?.dispose();
    super.onClose();
  }

  Future<void> reload() async {
    final bytes = await _storage.readLogo();
    final decoded = bytes == null ? null : await decodeMapImage(bytes);
    final old = image.value;
    image.value = decoded;
    old?.dispose();
  }

  /// Opens the system picker. Returns false when nothing was chosen.
  /// Throws [LogoException] when the chosen file is not a usable image.
  Future<bool> pick() async {
    String? path;
    try {
      path = await _channel.invokeMethod<String>('pickImage');
    } on PlatformException {
      throw const LogoException('The image could not be opened.');
    }
    if (path == null) return false;
    if (path == 'failed') {
      throw const LogoException('The image could not be read.');
    }
    final source = File(path);
    try {
      await setFrom(source);
    } finally {
      try {
        await source.delete();
      } catch (_) {}
    }
    return true;
  }

  /// Stores [source] as the logo, scaled down and converted to PNG.
  Future<void> setFrom(File source) async {
    final Uint8List? png = await Isolate.run(() => _toPng(source.path));
    if (png == null) {
      throw const LogoException(
        'That file is not a supported image. Use a PNG or JPEG.',
      );
    }
    final target = await _storage.logoFile();
    final temp = File('${target.path}.tmp');
    await temp.writeAsBytes(png, flush: true);
    await temp.rename(target.path);
    await reload();
  }

  Future<void> remove() async {
    final file = await _storage.logoFile();
    if (await file.exists()) await file.delete();
    await reload();
  }
}

Uint8List? _toPng(String path) {
  final decoded = img.decodeImage(File(path).readAsBytesSync());
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final longest = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  final resized = longest <= LogoService.maxSide
      ? oriented
      : img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? LogoService.maxSide : null,
          height: oriented.height > oriented.width ? LogoService.maxSide : null,
          interpolation: img.Interpolation.average,
        );
  return img.encodePng(resized);
}
