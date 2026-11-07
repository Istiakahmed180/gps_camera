import 'dart:io';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

enum ShareOutcome {
  /// The user picked a target.
  shared,

  /// The user closed the sheet.
  dismissed,

  /// The sheet opened; the platform does not report what happened next.
  opened,
  missingFile,
  failed,
}

typedef ShareInvoker = Future<ShareResult> Function(ShareParams params);

/// Shares files through the native share sheet. share_plus hands the file
/// to other apps through a content URI, so no private path is exposed.
class ShareService extends GetxService {
  ShareService({this._share});

  final ShareInvoker? _share;

  Future<ShareOutcome> shareImage(File file, {Rect? origin}) =>
      shareFile(file, mimeType: 'image/jpeg', origin: origin);

  /// Shares several photos in one share sheet. Missing files are skipped;
  /// [ShareOutcome.missingFile] only when none are left.
  Future<ShareOutcome> shareImages(List<File> files, {Rect? origin}) async {
    final present = [
      for (final f in files)
        if (await f.exists()) f,
    ];
    if (present.isEmpty) return ShareOutcome.missingFile;
    try {
      final params = ShareParams(
        files: [for (final f in present) XFile(f.path, mimeType: 'image/jpeg')],
        sharePositionOrigin: origin,
      );
      final result = await (_share ?? SharePlus.instance.share)(params);
      return switch (result.status) {
        ShareResultStatus.success => ShareOutcome.shared,
        ShareResultStatus.dismissed => ShareOutcome.dismissed,
        ShareResultStatus.unavailable => ShareOutcome.opened,
      };
    } catch (_) {
      return ShareOutcome.failed;
    }
  }

  /// Shares exactly [file] (no text), e.g. a report PDF.
  Future<ShareOutcome> shareFile(
    File file, {
    required String mimeType,
    Rect? origin,
  }) async {
    if (!await file.exists()) return ShareOutcome.missingFile;

    try {
      final params = ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        sharePositionOrigin: origin,
      );
      final result = await (_share ?? SharePlus.instance.share)(params);
      return switch (result.status) {
        ShareResultStatus.success => ShareOutcome.shared,
        ShareResultStatus.dismissed => ShareOutcome.dismissed,
        ShareResultStatus.unavailable => ShareOutcome.opened,
      };
    } catch (_) {
      return ShareOutcome.failed;
    }
  }
}
