import 'dart:async';
import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// A file or folder in the user's Google Drive, as far as backup cares.
class DriveEntry {
  const DriveEntry({required this.id, required this.name, this.md5, this.size});

  final String id;
  final String name;

  /// Content hash, for files; Drive computes it.
  final String? md5;
  final int? size;
}

/// The few Drive operations backup needs. Only files and folders this app
/// created are visible to it (the `drive.file` scope).
abstract interface class DriveStore {
  /// The folder called [name] inside [parentId] (or My Drive when null),
  /// created when missing.
  Future<String> folder(String name, {String? parentId});

  /// The folder called [name] inside [parentId], or null; never creates.
  Future<String?> findFolder(String name, {String? parentId});

  /// Files (not folders) directly inside [folderId].
  Future<List<DriveEntry>> files(String folderId);

  /// Uploads [file] as [name] into [folderId], or over [replaceId].
  Future<DriveEntry> upload(
    File file,
    String name,
    String folderId, {
    String? replaceId,
  });

  /// Writes the file [id] to [target].
  Future<void> download(String id, File target);

  /// Releases the connection.
  void close();
}

/// [DriveStore] backed by the Google Drive REST API.
class GoogleDriveStore implements DriveStore {
  GoogleDriveStore(this._client) : _api = drive.DriveApi(_client);

  final http.Client _client;
  final drive.DriveApi _api;

  static const String _folderType = 'application/vnd.google-apps.folder';

  /// Files over this size upload in resumable chunks (videos).
  static const int _resumableOver = 5 * 1024 * 1024;

  @override
  Future<String?> findFolder(String name, {String? parentId}) async {
    final parent = parentId ?? 'root';
    final found = await _api.files.list(
      q:
          "name = '${_quote(name)}' and mimeType = '$_folderType' and "
          "'$parent' in parents and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
      // The oldest one, so every run picks the same folder even if two
      // phones once created one each.
      orderBy: 'createdTime',
      pageSize: 1,
    );
    final existing = found.files;
    return existing != null && existing.isNotEmpty ? existing.first.id : null;
  }

  @override
  Future<String> folder(String name, {String? parentId}) async {
    final existing = await findFolder(name, parentId: parentId);
    if (existing != null) return existing;
    final parent = parentId ?? 'root';
    final created = await _api.files.create(
      drive.File()
        ..name = name
        ..mimeType = _folderType
        ..parents = [parent],
      $fields: 'id',
    );
    return created.id!;
  }

  @override
  Future<List<DriveEntry>> files(String folderId) async {
    final entries = <DriveEntry>[];
    String? page;
    do {
      final list = await _api.files.list(
        q:
            "'$folderId' in parents and mimeType != '$_folderType' and "
            'trashed = false',
        spaces: 'drive',
        $fields: 'nextPageToken, files(id, name, md5Checksum, size)',
        pageSize: 1000,
        pageToken: page,
      );
      for (final f in list.files ?? const <drive.File>[]) {
        if (f.id == null || f.name == null) continue;
        entries.add(
          DriveEntry(
            id: f.id!,
            name: f.name!,
            md5: f.md5Checksum,
            size: int.tryParse(f.size ?? ''),
          ),
        );
      }
      page = list.nextPageToken;
    } while (page != null);
    return entries;
  }

  @override
  Future<DriveEntry> upload(
    File file,
    String name,
    String folderId, {
    String? replaceId,
  }) async {
    final length = await file.length();
    final media = drive.Media(file.openRead(), length);
    final options = length > _resumableOver
        ? drive.UploadOptions.resumable
        : drive.UploadOptions.defaultOptions;
    const fields = 'id, name, md5Checksum, size';
    final result = replaceId == null
        ? await _api.files.create(
            drive.File()
              ..name = name
              ..parents = [folderId],
            uploadMedia: media,
            uploadOptions: options,
            $fields: fields,
          )
        : await _api.files.update(
            drive.File(),
            replaceId,
            uploadMedia: media,
            uploadOptions: options,
            $fields: fields,
          );
    return DriveEntry(
      id: result.id!,
      name: result.name ?? name,
      md5: result.md5Checksum,
      size: int.tryParse(result.size ?? ''),
    );
  }

  @override
  Future<void> download(String id, File target) async {
    final media = await _api.files.get(
      id,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final sink = target.openWrite();
    try {
      await media.stream.pipe(sink);
    } catch (_) {
      await sink.close();
      rethrow;
    }
  }

  @override
  void close() => _client.close();

  static String _quote(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
}
