import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Map images kept on disk so a place visited before needs no download,
/// which saves the free Geoapify quota and works offline at known spots.
///
/// Keyed by the point rounded to 4 decimals (about 11 m). At the map's zoom
/// that moves the marker by at most a few pixels. Oldest entries are removed
/// beyond [maxEntries]. It lives in the cache folder, so Android may also
/// clear it when storage runs low.
class MapCache {
  MapCache({Future<Directory> Function()? baseDirectory, this.maxEntries = 200})
    : _baseDirectory = baseDirectory ?? getApplicationCacheDirectory;

  final Future<Directory> Function() _baseDirectory;
  final int maxEntries;

  Future<Directory> _folder() async =>
      Directory('${(await _baseDirectory()).path}/map_cache')
          .create(recursive: true);

  static String keyFor(double latitude, double longitude, int zoom) =>
      'z${zoom}_${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}';

  Future<Uint8List?> read(double latitude, double longitude, int zoom) async {
    try {
      final file = File(
        '${(await _folder()).path}/${keyFor(latitude, longitude, zoom)}.png',
      );
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      // Mark as recently used so pruning removes stale places first.
      await file.setLastModified(DateTime.now());
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(
    double latitude,
    double longitude,
    int zoom,
    Uint8List png,
  ) async {
    try {
      final folder = await _folder();
      final target = File(
        '${folder.path}/${keyFor(latitude, longitude, zoom)}.png',
      );
      final temp = File('${target.path}.tmp');
      await temp.writeAsBytes(png, flush: true);
      await temp.rename(target.path);
      await _prune(folder);
    } catch (_) {
      // A cache that cannot be written just means another download later.
    }
  }

  /// Total bytes and number of cached maps.
  Future<(int, int)> usage() async {
    var bytes = 0;
    var count = 0;
    try {
      await for (final entity in (await _folder()).list()) {
        if (entity is File && entity.path.endsWith('.png')) {
          bytes += await entity.length();
          count++;
        }
      }
    } catch (_) {}
    return (bytes, count);
  }

  Future<void> clear() async {
    try {
      final folder = await _folder();
      await folder.delete(recursive: true);
    } catch (_) {}
  }

  Future<void> _prune(Directory folder) async {
    final files = <(File, DateTime)>[];
    await for (final entity in folder.list()) {
      if (entity is File && entity.path.endsWith('.png')) {
        files.add((entity, await entity.lastModified()));
      }
    }
    if (files.length <= maxEntries) return;
    files.sort((a, b) => a.$2.compareTo(b.$2));
    for (final (file, _) in files.take(files.length - maxEntries)) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}
