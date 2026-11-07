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

  int get total => photos + watermarked + maps + reports + mapCache;
}

class StorageUsage {
  StorageUsage(this._storage, this._mapCache);

  final PhotoStorageService _storage;
  final MapCache _mapCache;

  Future<StorageUsageReport> measure() async {
    final photos = await _folder(await _storage.photosDirectory(), '.jpg');
    final copies = await _folder(await _storage.watermarkedDirectory(), '.jpg');
    final maps = await _folder(await _storage.mapsDirectory(), '.png');
    final reports = await _folder(await _storage.reportsDirectory(), '.pdf');
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
    );
  }

  Future<void> clearMapCache() => _mapCache.clear();

  /// Total bytes in [dir], and how many files end with [countSuffix].
  static Future<(int, int)> _folder(Directory dir, String countSuffix) async {
    var bytes = 0;
    var count = 0;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        bytes += await entity.length();
        if (entity.path.endsWith(countSuffix)) count++;
      }
    } on FileSystemException {
      // An unreadable folder counts as empty.
    }
    return (bytes, count);
  }
}
