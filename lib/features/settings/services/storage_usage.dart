import 'dart:io';

import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/location/services/map_cache.dart';

/// Space used by each kind of app data.
class StorageUsageReport {
  const StorageUsageReport({
    required this.photos,
    required this.photoCount,
    required this.watermarked,
    required this.watermarkedCount,
    required this.maps,
    required this.reports,
    required this.reportCount,
    required this.mapCache,
    required this.mapCacheCount,
    this.thumbnails = 0,
  });

  /// Originals with their metadata.
  final int photos;
  final int photoCount;
  final int watermarked;
  final int watermarkedCount;

  /// Map snapshots saved with photos.
  final int maps;
  final int reports;
  final int reportCount;

  /// Maps kept to avoid downloading again; safe to clear.
  final int mapCache;
  final int mapCacheCount;

  /// Video thumbnails; made again when needed.
  final int thumbnails;

  int get total =>
      photos + watermarked + maps + reports + mapCache + thumbnails;
}

class StorageUsage {
  StorageUsage(this._storage, this._mapCache);

  final PhotoStorageService _storage;
  final MapCache _mapCache;

  Future<StorageUsageReport> measure() async {
    final photos = await _folder(await _storage.photosDirectory(), const [
      '.jpg',
      '.mp4',
    ]);
    final copies = await _folder(await _storage.watermarkedDirectory(), const [
      '.jpg',
      '.mp4',
    ]);
    final maps = await _folder(await _storage.mapsDirectory(), const ['.png']);
    final reports = await _folder(await _storage.reportsDirectory(), const [
      '.pdf',
    ]);
    // Not created just to be measured; missing counts as empty.
    final thumbnails = await _folder(
      Directory('${(await _storage.rootDirectory()).path}/Thumbnails'),
      const [],
    );
    final (cacheBytes, cacheCount) = await _mapCache.usage();
    return StorageUsageReport(
      photos: photos.$1,
      photoCount: photos.$2,
      watermarked: copies.$1,
      watermarkedCount: copies.$2,
      maps: maps.$1,
      reports: reports.$1,
      reportCount: reports.$2,
      mapCache: cacheBytes,
      mapCacheCount: cacheCount,
      thumbnails: thumbnails.$1,
    );
  }

  Future<void> clearMapCache() => _mapCache.clear();

  /// Bytes of every file in [dir], and how many end with one of
  /// [countSuffixes].
  static Future<(int, int)> _folder(
    Directory dir,
    List<String> countSuffixes,
  ) async {
    var bytes = 0;
    var count = 0;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        bytes += await entity.length();
        if (countSuffixes.any(entity.path.endsWith)) count++;
      }
    } on FileSystemException {
      // An unreadable folder counts as empty.
    }
    return (bytes, count);
  }
}
