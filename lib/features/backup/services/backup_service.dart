import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/database/app_database.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:path_provider/path_provider.dart';

class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => 'BackupException: $message';
}

/// Files handled so far while creating or restoring a backup.
class BackupProgress {
  const BackupProgress(this.done, this.total);

  final int done;
  final int total;

  double get fraction => total == 0 ? 1 : done / total;
}

class BackupFile {
  const BackupFile({
    required this.file,
    required this.fileCount,
    required this.photoCount,
  });

  final File file;
  final int fileCount;

  /// Original photos in the backup.
  final int photoCount;

  String get name => file.uri.pathSegments.last;
}

enum BackupSaveOutcome { saved, cancelled, noApp, failed }

/// What a restore added. Nothing already on the phone is replaced.
class RestoreSummary {
  const RestoreSummary({
    required this.addedPhotos,
    required this.addedFiles,
    required this.skippedFiles,
    required this.addedProjects,
    required this.addedAssignments,
    required this.restoredSettings,
  });

  /// Original photos added.
  final int addedPhotos;

  /// All files added: photos, sidecars, copies, maps and reports.
  final int addedFiles;

  /// Files left alone because a file with that name already exists.
  final int skippedFiles;
  final int addedProjects;
  final int addedAssignments;

  /// Watermark settings were taken from the backup (only when this phone
  /// had none of its own).
  final bool restoredSettings;
}

/// One ZIP holding every photo, watermarked copy, map, report, project and
/// watermark setting. Restoring merges it into the app: files and projects
/// that already exist are kept as they are.
class BackupService {
  BackupService(
    this._storage,
    this._db,
    this._settings, {
    MethodChannel? channel,
    Future<Directory> Function()? tempDirectory,
    DateTime Function()? clock,
  }) : _channel = channel ?? const MethodChannel('co.tdevs.gps_camera/native'),
       _tempDirectory = tempDirectory ?? getTemporaryDirectory,
       _clock = clock ?? DateTime.now;

  static const String format = 'gps_camera_backup';
  static const int version = 1;
  static const String manifestName = 'backup.json';
  static const List<String> folders = [
    'Photos',
    'Watermarked',
    'Maps',
    'Reports',
    'Branding',
  ];

  final PhotoStorageService _storage;
  final AppDatabase _db;
  final StorageService _settings;
  final MethodChannel _channel;
  final Future<Directory> Function() _tempDirectory;
  final DateTime Function() _clock;

  final RxBool isBusy = false.obs;
  final Rxn<BackupProgress> progress = Rxn<BackupProgress>();

  /// Builds a backup ZIP in the app's cache. Pass it to [saveToDevice],
  /// then [discard] it.
  Future<BackupFile> create() => _exclusive(() async {
    final root = (await _storage.rootDirectory()).path;
    final refs = await _listRefs(root);
    final manifest = jsonEncode({
      'format': format,
      'version': version,
      'createdAt': _clock().toUtc().toIso8601String(),
      'fileCount': refs.length,
      'settings': {
        for (final key in _settingKeys) key: ?_settings.read<Object>(key),
      },
      'projects': [
        for (final row in await _db.select(_db.projects).get()) row.toJson(),
      ],
      'projectPhotos': [
        for (final row in await _db.select(_db.projectPhotos).get())
          row.toJson(),
      ],
    });

    final dir = await _cacheFolder(clear: true);
    final zip = File('${dir.path}/${_fileName(_clock())}');
    progress.value = BackupProgress(0, refs.length);
    try {
      await _withProgress(
        (port) => _zipInBackground(zip.path, root, refs, manifest, port),
      );
    } catch (e) {
      await _delete(zip);
      throw const BackupException(
        'The backup could not be created. Check that the phone has free '
        'space and try again.',
      );
    }
    return BackupFile(
      file: zip,
      fileCount: refs.length,
      photoCount: refs.where(_isOriginalPhoto).length,
    );
  });

  /// Asks the user where to save [backup] (Files, Drive, USB, …).
  Future<BackupSaveOutcome> saveToDevice(BackupFile backup) async {
    try {
      final outcome = await _channel.invokeMethod<String>('saveBackup', {
        'path': backup.file.path,
      });
      return switch (outcome) {
        'saved' => BackupSaveOutcome.saved,
        'cancelled' => BackupSaveOutcome.cancelled,
        'noApp' => BackupSaveOutcome.noApp,
        _ => BackupSaveOutcome.failed,
      };
    } on PlatformException {
      return BackupSaveOutcome.failed;
    } on MissingPluginException {
      return BackupSaveOutcome.failed;
    }
  }

  /// Lets the user choose a backup file. Returns a private copy, or null
  /// when nothing was chosen.
  Future<File?> pick() async {
    await _cacheFolder(clear: true);
    try {
      final path = await _channel.invokeMethod<String>('pickBackup');
      if (path == null) return null;
      if (!path.endsWith('.zip')) {
        throw const BackupException('The file could not be read.');
      }
      return File(path);
    } on PlatformException {
      throw const BackupException('The file could not be read.');
    }
  }

  /// Backup work that finished after Android restarted the app while a
  /// file picker was open: a chosen backup waiting to be restored, and/or
  /// whether a backup reached the chosen place.
  Future<({File? restore, BackupSaveOutcome? saved})> pendingWork() async {
    try {
      final map = await _channel.invokeMapMethod<String, String>(
        'pendingBackup',
      );
      if (map == null) return (restore: null, saved: null);
      final path = map['restorePath'];
      return (
        restore: path == null ? null : File(path),
        saved: switch (map['saveResult']) {
          'saved' => BackupSaveOutcome.saved,
          null => null,
          _ => BackupSaveOutcome.failed,
        },
      );
    } catch (_) {
      return (restore: null, saved: null);
    }
  }

  /// Adds everything in [zip] that this phone does not have yet.
  Future<RestoreSummary> restore(File zip) => _exclusive(() async {
    final root = (await _storage.rootDirectory()).path;
    progress.value = null;

    final _Extracted extracted;
    try {
      extracted = await _withProgress(
        (port) => _extractInBackground(zip.path, root, port),
      );
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException(
        'The backup could not be read. It may be damaged or incomplete.',
      );
    }

    final manifest = extracted.manifest;
    final (projects, assignments) = await _mergeProjects(manifest, root);
    final restoredSettings = await _mergeSettings(manifest['settings']);
    return RestoreSummary(
      addedPhotos: extracted.added.where(_isOriginalPhoto).length,
      addedFiles: extracted.added.length,
      skippedFiles: extracted.skipped,
      addedProjects: projects,
      addedAssignments: assignments,
      restoredSettings: restoredSettings,
    );
  });

  /// Removes a backup ZIP from the app's cache.
  Future<void> discard(File file) => _delete(file);

  static const List<String> _settingKeys = [
    StorageKeys.watermarkConfig,
    StorageKeys.autoWatermark,
  ];

  Future<T> _exclusive<T>(Future<T> Function() work) async {
    if (isBusy.value) {
      throw const BackupException('A backup is already in progress.');
    }
    isBusy.value = true;
    try {
      return await work();
    } finally {
      isBusy.value = false;
      progress.value = null;
    }
  }

  Future<T> _withProgress<T>(Future<T> Function(SendPort port) run) async {
    final port = ReceivePort();
    port.listen((message) {
      if (message case [final int done, final int total]) {
        progress.value = BackupProgress(done, total);
      }
    });
    try {
      return await run(port.sendPort);
    } finally {
      port.close();
    }
  }

  Future<Directory> _cacheFolder({bool clear = false}) async {
    final dir = Directory('${(await _tempDirectory()).path}/backups');
    if (clear && await dir.exists()) {
      await for (final entity in dir.list()) {
        await _delete(entity);
      }
    }
    return dir.create(recursive: true);
  }

  Future<List<String>> _listRefs(String root) async {
    final refs = <String>[];
    for (final folder in folders) {
      final dir = Directory('$root/$folder');
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        // Skip half-written files and empty name reservations.
        if (name.endsWith('.tmp') || await entity.length() == 0) continue;
        refs.add('$folder/$name');
      }
    }
    refs.sort();
    return refs;
  }

  Future<(int, int)> _mergeProjects(
    Map<String, dynamic> manifest,
    String root,
  ) => _db.transaction(() async {
    final local = await _db.select(_db.projects).get();
    final ids = {for (final p in local) p.id};
    final names = {for (final p in local) p.name.toLowerCase()};

    var projects = 0;
    for (final json in _list(manifest['projects'])) {
      final ProjectRow row;
      try {
        row = ProjectRow.fromJson(json);
      } catch (_) {
        continue;
      }
      if (ids.contains(row.id)) continue;
      final name = _freeName(row.name, names);
      await _db
          .into(_db.projects)
          .insert(row.copyWith(name: name), mode: InsertMode.insertOrIgnore);
      ids.add(row.id);
      names.add(name.toLowerCase());
      projects++;
    }

    final assigned = {
      for (final a in await _db.select(_db.projectPhotos).get())
        a.originalPhotoPath,
    };
    var assignments = 0;
    for (final json in _list(manifest['projectPhotos'])) {
      final ProjectPhotoRow row;
      try {
        row = ProjectPhotoRow.fromJson(json);
      } catch (_) {
        continue;
      }
      final ref = row.originalPhotoPath;
      if (assigned.contains(ref) ||
          !ids.contains(row.projectId) ||
          !_isOriginalPhoto(ref) ||
          !await File('$root/$ref').exists()) {
        continue;
      }
      await _db
          .into(_db.projectPhotos)
          .insert(
            ProjectPhotosCompanion.insert(
              projectId: row.projectId,
              originalPhotoPath: ref,
              assignedAt: row.assignedAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      assigned.add(ref);
      assignments++;
    }
    return (projects, assignments);
  });

  /// Settings come back only on a phone that has none of its own, so a
  /// restore never changes how an existing setup looks.
  Future<bool> _mergeSettings(Object? saved) async {
    if (saved is! Map<String, dynamic>) return false;
    if (_settingKeys.any((key) => _settings.read<Object>(key) != null)) {
      return false;
    }
    var restored = false;
    for (final key in _settingKeys) {
      final value = saved[key];
      if (value is bool || value is Map<String, dynamic>) {
        await _settings.write(key, value as Object);
        restored = true;
      }
    }
    return restored;
  }

  static List<Map<String, dynamic>> _list(Object? value) => value is List
      ? value.whereType<Map<String, dynamic>>().toList()
      : const [];

  /// Keeps names unique the way the project editor requires.
  static String _freeName(String name, Set<String> taken) {
    if (!taken.contains(name.toLowerCase())) return name;
    for (var n = 1; ; n++) {
      final suffix = n == 1 ? ' (restored)' : ' (restored $n)';
      final base = name.length + suffix.length > 80
          ? name.substring(0, 80 - suffix.length).trimRight()
          : name;
      final candidate = '$base$suffix';
      if (!taken.contains(candidate.toLowerCase())) return candidate;
    }
  }

  /// An original photo or video (videos live in `Photos/` too).
  static bool _isOriginalPhoto(String ref) =>
      ref.startsWith('Photos/') &&
      (ref.endsWith('.jpg') || ref.endsWith('.mp4'));

  static String _fileName(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'GPSCamera_Backup_${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}.zip';
  }

  static Future<void> _delete(FileSystemEntity entity) async {
    try {
      await entity.delete(recursive: true);
    } on FileSystemException {
      // Leftovers in the cache are cleared before the next backup.
    }
  }

  /// Accepts only plain file names inside the backed-up folders, so a
  /// crafted ZIP cannot write anywhere else.
  static bool isSafeRef(String ref) {
    final slash = ref.indexOf('/');
    if (slash <= 0 || slash != ref.lastIndexOf('/')) return false;
    if (!folders.contains(ref.substring(0, slash))) return false;
    final name = ref.substring(slash + 1);
    return name.isNotEmpty &&
        !name.startsWith('.') &&
        !name.contains('\\') &&
        !name.endsWith('.tmp') &&
        !name.codeUnits.any((c) => c < 0x20);
  }
}

class _Extracted {
  const _Extracted(this.manifest, this.added, this.skipped);

  final Map<String, dynamic> manifest;
  final List<String> added;
  final int skipped;
}

// Top-level so the isolate closures capture only the plain values passed in.
Future<void> _zipInBackground(
  String zipPath,
  String root,
  List<String> refs,
  String manifest,
  SendPort port,
) => Isolate.run(() => _writeZip(zipPath, root, refs, manifest, port));

Future<_Extracted> _extractInBackground(
  String zipPath,
  String root,
  SendPort port,
) => Isolate.run(() => _extract(zipPath, root, port));

Future<void> _writeZip(
  String zipPath,
  String root,
  List<String> refs,
  String manifest,
  SendPort port,
) async {
  final encoder = ZipFileEncoder();
  // Photos are already compressed; storing them is much faster.
  encoder.create(zipPath, level: ZipFileEncoder.store);
  try {
    encoder.addArchiveFile(
      ArchiveFile.string(BackupService.manifestName, manifest),
    );
    for (var i = 0; i < refs.length; i++) {
      await encoder.addFile(File('$root/${refs[i]}'), refs[i]);
      port.send([i + 1, refs.length]);
    }
  } finally {
    await encoder.close();
  }
}

_Extracted _extract(String zipPath, String root, SendPort port) {
  final input = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final entry = archive.find(BackupService.manifestName);
    final bytes = entry?.readBytes();
    Object? manifest;
    try {
      manifest = bytes == null ? null : jsonDecode(utf8.decode(bytes));
    } on FormatException {
      manifest = null;
    }
    if (manifest is! Map<String, dynamic> ||
        manifest['format'] != BackupService.format) {
      throw const BackupException('This file is not a GPS Camera backup.');
    }
    final version = manifest['version'];
    if (version is! int || version > BackupService.version) {
      throw const BackupException(
        'This backup was made by a newer version of the app. Update the app '
        'and try again.',
      );
    }

    final files = archive.files
        .where((f) => f.isFile && f.name != BackupService.manifestName)
        .toList();
    final added = <String>[];
    var skipped = 0;
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final ref = file.name;
      if (!BackupService.isSafeRef(ref)) {
        skipped++;
      } else {
        final target = File('$root/$ref');
        if (target.existsSync()) {
          skipped++;
        } else {
          target.parent.createSync(recursive: true);
          final temp = File('${target.path}.tmp');
          final out = OutputFileStream(temp.path);
          try {
            file.writeContent(out);
          } finally {
            out.closeSync();
          }
          temp.renameSync(target.path);
          added.add(ref);
        }
      }
      port.send([i + 1, files.length]);
    }
    return _Extracted(manifest, added, skipped);
  } finally {
    input.closeSync();
  }
}
