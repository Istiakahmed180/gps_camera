import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/backup/services/backup_service.dart';
import 'package:gps_camera/features/backup/services/drive_store.dart';
import 'package:path_provider/path_provider.dart';

/// What one backup run did.
class DriveBackupResult {
  const DriveBackupResult({required this.uploaded, required this.unchanged});

  /// Files sent to Drive (new or changed).
  final int uploaded;

  /// Files already in Drive as they are on the phone.
  final int unchanged;
}

/// What one restore run added.
class DriveRestoreResult {
  const DriveRestoreResult({
    required this.addedFiles,
    required this.addedPhotos,
    required this.addedProjects,
  });

  final int addedFiles;

  /// Original photos and videos among [addedFiles].
  final int addedPhotos;
  final int addedProjects;
}

/// A backup stopped because it may no longer continue (left Wi-Fi).
class DriveBackupPaused implements Exception {
  const DriveBackupPaused();
}

/// The signed-in Google account has no Locaproof backup to restore.
class DriveNoBackup implements Exception {
  const DriveNoBackup();
}

/// Keeps a copy of every photo, video, watermarked copy, map, report,
/// project and watermark setting in a "Locaproof Backup" folder in the
/// user's Google Drive, laid out like the app's own folders.
///
/// Only new or changed files are sent. Nothing in Drive is ever deleted,
/// so a photo removed from the phone stays in the backup. Restoring adds
/// what the phone lacks and never replaces what it has.
class DriveBackupService {
  DriveBackupService(
    this._backup,
    this._storage, {
    Future<Directory> Function()? tempDirectory,
  }) : _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  final BackupService _backup;
  final PhotoStorageService _storage;
  final Future<Directory> Function() _tempDirectory;

  Future<Directory> _scratch() async =>
      (await _tempDirectory()).createTemp('drive_');

  /// A ZIP or Drive backup or restore is running.
  bool get isBusy => _backup.isBusy.value;

  static const String rootFolder = 'Locaproof Backup';
  static const String manifestName = 'backup.json';

  /// Sends what Drive lacks. [onProgress] gets files checked so far and
  /// the total. [canContinue] is asked before each upload (e.g. still on
  /// Wi-Fi); when it says no the run stops with [DriveBackupPaused].
  /// Never runs alongside a ZIP backup or restore.
  Future<DriveBackupResult> backUp(
    DriveStore store, {
    void Function(int done, int total)? onProgress,
    Future<bool> Function()? canContinue,
  }) => _backup.exclusive(() async {
    final root = (await _storage.rootDirectory()).path;
    final refs = await _backup.listFiles();
    final rootId = await store.folder(rootFolder);

    // Projects and settings go first too, so a run that stops halfway
    // still saves them. Restoring skips any photo not in Drive yet.
    await _uploadManifest(store, rootId, refs.length);

    var uploaded = 0;
    var unchanged = 0;
    var done = 0;
    onProgress?.call(0, refs.length);
    for (final folder in BackupService.folders) {
      final names = [
        for (final ref in refs)
          if (ref.startsWith('$folder/')) ref.substring(folder.length + 1),
      ];
      if (names.isEmpty) continue;
      final folderId = await store.folder(folder, parentId: rootId);
      final remote = {
        for (final entry in await store.files(folderId)) entry.name: entry,
      };
      for (final name in names) {
        final file = File('$root/$folder/$name');
        final existing = remote[name];
        if (existing != null && await _same(file, existing)) {
          unchanged++;
        } else if (await file.exists()) {
          if (canContinue != null && !await canContinue()) {
            throw const DriveBackupPaused();
          }
          await store.upload(file, name, folderId, replaceId: existing?.id);
          uploaded++;
        }
        onProgress?.call(++done, refs.length);
      }
    }

    // Again, now naming every photo that is in Drive.
    if (uploaded > 0) await _uploadManifest(store, rootId, refs.length);
    return DriveBackupResult(uploaded: uploaded, unchanged: unchanged);
  });

  Future<void> _uploadManifest(
    DriveStore store,
    String rootId,
    int fileCount,
  ) async {
    final dir = await _scratch();
    try {
      final manifest = File('${dir.path}/$manifestName');
      await manifest.writeAsString(
        jsonEncode(await _backup.buildManifest(fileCount: fileCount)),
      );
      final existing = (await store.files(rootId))
          .where((e) => e.name == manifestName)
          .firstOrNull;
      await store.upload(
        manifest,
        manifestName,
        rootId,
        replaceId: existing?.id,
      );
    } finally {
      await _deleteQuietly(dir);
    }
  }

  /// Brings back from Drive what this phone does not have. Throws
  /// [DriveNoBackup] when this Google account has no Locaproof backup.
  /// Never runs alongside a ZIP backup or restore.
  Future<DriveRestoreResult> restore(
    DriveStore store, {
    void Function(int done, int total)? onProgress,
  }) => _backup.exclusive(() async {
    final root = (await _storage.rootDirectory()).path;
    // Looked up only: restoring never creates folders in Drive.
    final rootId = await store.findFolder(rootFolder);
    if (rootId == null) throw const DriveNoBackup();

    // Everything first, so progress has a total.
    final wanted = <(String ref, DriveEntry entry)>[];
    for (final folder in BackupService.folders) {
      final folderId = await store.findFolder(folder, parentId: rootId);
      if (folderId == null) continue;
      for (final entry in await store.files(folderId)) {
        final ref = '$folder/${entry.name}';
        if (!BackupService.isSafeRef(ref)) continue;
        if (await File('$root/$ref').exists()) continue;
        wanted.add((ref, entry));
      }
    }

    final added = <String>[];
    var done = 0;
    onProgress?.call(0, wanted.length);
    for (final (ref, entry) in wanted) {
      final target = File('$root/$ref');
      await target.parent.create(recursive: true);
      final partial = File('${target.path}.drive.tmp');
      try {
        await store.download(entry.id, partial);
        // Something may have appeared meanwhile; it is never replaced.
        if (await target.exists()) {
          await _deleteQuietly(partial);
        } else {
          await partial.rename(target.path);
          added.add(ref);
        }
      } catch (_) {
        await _deleteQuietly(partial);
        rethrow;
      }
      onProgress?.call(++done, wanted.length);
    }

    var projects = 0;
    final manifestEntry = (await store.files(rootId))
        .where((e) => e.name == manifestName)
        .firstOrNull;
    if (manifestEntry != null) {
      final temp = await _scratch();
      try {
        final file = File('${temp.path}/$manifestName');
        await store.download(manifestEntry.id, file);
        final json = jsonDecode(await file.readAsString());
        if (json is Map<String, dynamic>) {
          (projects, _, _) = await _backup.mergeManifest(json);
        }
      } finally {
        await _deleteQuietly(temp);
      }
    }
    return DriveRestoreResult(
      addedFiles: added.length,
      addedPhotos: added.where(BackupService.isOriginalRef).length,
      addedProjects: projects,
    );
  });

  /// Photos, videos and maps never change after they are saved, so the
  /// size is enough. Details files (`.json`) do change (notes, addresses
  /// added later), so their content is compared.
  static Future<bool> _same(File file, DriveEntry remote) async {
    if (!await file.exists()) return true;
    final size = await file.length();
    if (remote.size != null && remote.size != size) return false;
    if (!file.path.endsWith('.json')) return remote.size == size;
    final hash = md5.convert(await file.readAsBytes()).toString();
    return hash == remote.md5;
  }

  static Future<void> _deleteQuietly(FileSystemEntity entity) async {
    try {
      await entity.delete(recursive: true);
    } catch (_) {}
  }
}
