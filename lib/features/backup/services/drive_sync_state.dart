import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Google Drive backup state shared by the app and the background job.
///
/// Kept in its own small files rather than the settings store: the
/// background job runs in a separate isolate, and two writers of the
/// settings file could overwrite each other's settings.
class DriveSyncState {
  DriveSyncState({
    Future<Directory> Function()? directory,
    DateTime Function()? clock,
    bool Function(int pid)? isAlive,
  }) : _directory = directory ?? getApplicationSupportDirectory,
       _clock = clock ?? DateTime.now,
       _isAlive = isAlive ?? _processAlive;

  final Future<Directory> Function() _directory;
  final DateTime Function() _clock;

  /// A lock older than this is from a run that was killed.
  static const Duration staleLock = Duration(hours: 1);

  Future<File> _file(String name) async =>
      File('${(await _directory()).path}/$name');

  /// When the last backup finished, from the app or the background job.
  Future<DateTime?> lastBackup() async {
    try {
      final json = jsonDecode(
        await (await _file('drive_state.json')).readAsString(),
      );
      return json is Map<String, dynamic>
          ? DateTime.tryParse(json['lastBackup'] as String? ?? '')
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> setLastBackup(DateTime at) async {
    final file = await _file('drive_state.json');
    final partial = File('${file.path}.tmp');
    await partial.writeAsString(
      jsonEncode({'lastBackup': at.toUtc().toIso8601String()}),
      flush: true,
    );
    await partial.rename(file.path);
  }

  /// Takes the backup lock, so the app and the background job never back
  /// up at the same time (they would upload the same new file twice).
  /// False when another run holds it. A lock whose app process has died
  /// (Android closed the app mid-backup) or that is older than [staleLock]
  /// no longer counts.
  Future<bool> lock() async {
    final file = await _file('drive_backup.lock');
    final mine = jsonEncode({
      'pid': pid,
      'at': _clock().toUtc().toIso8601String(),
    });
    try {
      await file.create(exclusive: true);
      await file.writeAsString(mine, flush: true);
      return true;
    } on FileSystemException {
      if (await _held(file)) return false;
      try {
        await file.writeAsString(mine, flush: true);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<bool> _held(File file) async {
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return false;
      final at = DateTime.tryParse(json['at'] as String? ?? '');
      if (at == null || _clock().difference(at) >= staleLock) return false;
      final owner = json['pid'];
      return owner is! int || _isAlive(owner);
    } catch (_) {
      // Unreadable (cut off mid-write): not a lock anyone holds.
      return false;
    }
  }

  /// Whether the process that took a lock is still running. Both the app
  /// and the background job run in the app's process, so a dead process
  /// means its backup stopped for good.
  final bool Function(int pid) _isAlive;

  static bool _processAlive(int owner) =>
      owner == pid || Directory('/proc/$owner').existsSync();

  Future<void> unlock() async {
    try {
      await (await _file('drive_backup.lock')).delete();
    } catch (_) {}
  }
}
