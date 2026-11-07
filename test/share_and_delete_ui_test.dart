import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/core/services/share_service.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/gallery/widgets/photo_action_menu.dart';
import 'package:share_plus/share_plus.dart';

GalleryPhoto _photo(String name, GalleryPhotoKind kind) => GalleryPhoto(
  path: '/x/$name',
  kind: kind,
  sizeBytes: 1,
  modifiedAt: DateTime.utc(2026),
);

void main() {
  group('ShareService', () {
    late File image;
    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('share');
      image = File('${dir.path}/IMG_1.jpg')..writeAsBytesSync([1, 2, 3]);
    });

    test('shares exactly the selected file as a JPEG, with no text', () async {
      ShareParams? sent;
      final service = ShareService(
        share: (params) async {
          sent = params;
          return const ShareResult('ok', ShareResultStatus.success);
        },
      );

      expect(await service.shareImage(image), ShareOutcome.shared);
      expect(sent!.files!.single.path, image.path);
      expect(sent!.files!.single.mimeType, 'image/jpeg');
      expect(sent!.text, isNull);
    });

    test('a missing file never opens the sheet', () async {
      var calls = 0;
      final service = ShareService(
        share: (_) async {
          calls++;
          return const ShareResult('', ShareResultStatus.dismissed);
        },
      );
      image.deleteSync();

      expect(await service.shareImage(image), ShareOutcome.missingFile);
      expect(calls, 0);
    });

    test('maps dismissal, unknown result and errors', () async {
      Future<ShareOutcome> run(ShareInvoker invoker) =>
          ShareService(share: invoker).shareImage(image);

      expect(
        await run(
          (_) async => const ShareResult('', ShareResultStatus.dismissed),
        ),
        ShareOutcome.dismissed,
      );
      expect(
        await run(
          (_) async => const ShareResult('', ShareResultStatus.unavailable),
        ),
        ShareOutcome.opened,
      );
      expect(
        await run((_) => throw StateError('no activity')),
        ShareOutcome.failed,
      );
    });
  });

  group('delete confirmation', () {
    final original = _photo('IMG_1.jpg', GalleryPhotoKind.original);
    final copies = [
      _photo('IMG_1_wm.jpg', GalleryPhotoKind.watermarked),
      _photo('IMG_1_wm_1.jpg', GalleryPhotoKind.watermarked),
    ];

    testWidgets('related copies are kept unless the user opts in', (
      tester,
    ) async {
      final answer = await _answer(
        tester,
        DeletePlan(target: original, related: copies),
        expectText: 'will be kept',
      );
      expect(answer, isFalse);
    });

    testWidgets('opting in includes related copies', (tester) async {
      final answer = await _answer(
        tester,
        DeletePlan(target: original, related: copies),
        tick: true,
      );
      expect(answer, isTrue);
    });

    testWidgets('cancel deletes nothing', (tester) async {
      final answer = await _answer(
        tester,
        DeletePlan(target: original, related: copies),
        cancel: true,
      );
      expect(answer, isNull);
    });

    testWidgets('a watermarked copy says the original is unaffected', (
      tester,
    ) async {
      await _answer(
        tester,
        DeletePlan(target: copies.first),
        cancel: true,
        expectText: 'The original photo is not affected',
      );
      expect(find.byType(CheckboxListTile), findsNothing);
    });
  });
}

Future<bool?> _answer(
  WidgetTester tester,
  DeletePlan plan, {
  bool tick = false,
  bool cancel = false,
  String? expectText,
}) async {
  bool? result = true;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await confirmDelete(context, plan),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  if (expectText != null) {
    expect(find.textContaining(expectText), findsOneWidget);
  }
  if (plan.hasRelated) {
    expect(
      find.text('Also delete ${plan.related.length} watermarked copies'),
      findsOneWidget,
    );
  }
  if (tick) {
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(find.textContaining('will be permanently deleted'), findsOneWidget);
  }
  await tester.tap(find.text(cancel ? 'Cancel' : 'Delete'));
  await tester.pumpAndSettle();
  return result;
}
