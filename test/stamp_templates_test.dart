import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/location/services/location_service.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_content.dart';
import 'package:gps_camera/features/watermark/models/watermark_template.dart';
import 'package:gps_camera/features/watermark/services/watermark_painter.dart';
import 'package:gps_camera/features/watermark/widgets/watermark_template_list.dart';

import 'helpers/test_env.dart';
import 'helpers/watermark_fixtures.dart';

LocationFix _seaLevelFix() =>
    fixtureFix().withAltitude(32.4, AltitudeReference.meanSeaLevel);

void main() {
  group('sea-level altitude', () {
    test('an ellipsoid height is converted', () async {
      final calls = <List<double>>[];
      final service = LocationService(
        FakePermissionService(),
        seaLevel: (lat, lon, alt) async {
          calls.add([lat, lon, alt]);
          return alt + 58.5;
        },
      );
      final fix = await service.withSeaLevel(fixtureFix());
      expect(calls.single, [23.910908, 90.401005, -26.1]);
      expect(fix.altitude, closeTo(32.4, 1e-9));
      expect(fix.altitudeReference, AltitudeReference.meanSeaLevel);
      expect(fix.latitude, 23.910908);
      expect(fix.accuracy, 6.75);
    });

    test('kept as recorded when the phone cannot convert', () async {
      for (final answer in <Future<double?> Function()>[
        () async => null,
        () async => double.nan,
        () async => throw Exception('no geoid'),
      ]) {
        final service = LocationService(
          FakePermissionService(),
          seaLevel: (_, _, _) => answer(),
        );
        final fix = await service.withSeaLevel(fixtureFix());
        expect(fix.altitude, -26.1);
        expect(fix.altitudeReference, AltitudeReference.wgs84Ellipsoid);
      }
    });

    test('a sea-level height is not converted again', () async {
      var called = false;
      final service = LocationService(
        FakePermissionService(),
        seaLevel: (_, _, _) async {
          called = true;
          return 0;
        },
      );
      final fix = await service.withSeaLevel(_seaLevelFix());
      expect(called, isFalse);
      expect(fix.altitude, 32.4);
    });
  });

  group('altitude on the stamp', () {
    test('only a sea-level height is shown', () {
      const config = WatermarkConfig();
      final ellipsoid = WatermarkContent.from(fixtureMetadata(), config);
      expect(ellipsoid.altitude, isNull);

      final seaLevel = WatermarkContent.from(
        fixtureMetadata(
          location: LocationSnapshot.current(
            _seaLevelFix(),
            const Duration(seconds: 2),
          ),
        ),
        config,
      );
      expect(seaLevel.altitude, '32 m');
      expect(seaLevel.altitudeLine, 'Alt 32 m');
    });

    test('can be hidden, and old settings show it', () {
      final metadata = fixtureMetadata(
        location: LocationSnapshot.current(
          _seaLevelFix(),
          const Duration(seconds: 2),
        ),
      );
      final hidden = WatermarkContent.from(
        metadata,
        const WatermarkConfig(showAltitude: false),
      );
      expect(hidden.altitude, isNull);

      final old = WatermarkConfig.fromJson({'template': 'classic'});
      expect(old.showAltitude, isTrue);
      final saved = WatermarkConfig.fromJson(
        const WatermarkConfig(showAltitude: false).toJson(),
      );
      expect(saved.showAltitude, isFalse);
    });
  });

  test('altitude alone still shows, with the last-known caveat', () {
    const config = WatermarkConfig(
      showCoordinates: false,
      showAccuracy: false,
      showAddress: false,
    );
    final current = WatermarkContent.from(
      fixtureMetadata(
        location: LocationSnapshot.current(
          _seaLevelFix(),
          const Duration(seconds: 2),
        ),
      ),
      config,
    );
    expect(current.altitude, '32 m');
    expect(current.locationNotice, isNull);

    final stale = WatermarkContent.from(
      fixtureMetadata(
        location: LocationSnapshot.stale(
          _seaLevelFix(),
          const Duration(minutes: 5),
        ),
      ),
      config,
    );
    expect(stale.altitude, '32 m');
    expect(stale.locationNotice, isNotNull);
  });

  group('card templates', () {
    const photo = Size(1080, 1920);
    final content = WatermarkContent.from(
      fixtureMetadata(
        location: LocationSnapshot.current(
          _seaLevelFix(),
          const Duration(seconds: 2),
        ),
      ),
      const WatermarkConfig(),
    );

    WatermarkPainter paint(WatermarkTemplate template, {bool rtl = false}) =>
        WatermarkPainter(
          content: content,
          config: WatermarkConfig(
            template: template,
            position: WatermarkPosition.bottomRight,
          ),
          imageSize: photo,
          reserveMapSlot: true,
          rtl: rtl,
        );

    test('span the photo width whatever the position', () {
      for (final template in WatermarkTemplate.values.where((t) => t.isCard)) {
        final p = paint(template);
        final margin = photo.width * 0.035;
        expect(p.bounds.left, closeTo(margin, 0.01), reason: template.name);
        expect(
          p.bounds.right,
          closeTo(photo.width - margin, 0.01),
          reason: template.name,
        );
        p.dispose();
      }
    });

    test('map shape and side', () {
      final card = paint(WatermarkTemplate.mapCard);
      expect(card.mapIsRound, isFalse);
      expect(card.mapRect!.center.dx, lessThan(card.bounds.center.dx));
      card.dispose();

      final round = paint(WatermarkTemplate.roundMap);
      expect(round.mapIsRound, isTrue);
      expect(round.mapRect!.width, closeTo(round.mapRect!.height, 1e-6));
      round.dispose();

      final right = paint(WatermarkTemplate.mapRight);
      expect(right.mapRect!.center.dx, greaterThan(right.bounds.center.dx));
      right.dispose();

      // Mirrored for right-to-left languages.
      final rightRtl = paint(WatermarkTemplate.mapRight, rtl: true);
      expect(rightRtl.mapRect!.center.dx, lessThan(rightRtl.bounds.center.dx));
      rightRtl.dispose();

      final banner = paint(WatermarkTemplate.banner);
      expect(banner.mapRect, isNull);
      banner.dispose();
    });

    test('the map is about as tall as the details', () {
      final p = paint(WatermarkTemplate.mapCard);
      final unit = photo.width / 1000;
      expect(p.mapRect!.height, inInclusiveRange(150 * unit, 240 * unit));
      expect(p.mapRect!.height, lessThanOrEqualTo(p.bounds.height));
      p.dispose();
    });

    test('new photos use the map card; saved choices are kept', () {
      expect(const WatermarkConfig().template, WatermarkTemplate.mapCard);
      expect(
        WatermarkConfig.fromJson({'template': 'professional'}).template,
        WatermarkTemplate.professional,
      );
    });
  });

  testWidgets('template list shows every template and picks one', (
    tester,
  ) async {
    WatermarkTemplate? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WatermarkTemplateList(
              selected: WatermarkTemplate.mapCard,
              content: WatermarkContent.from(
                fixtureMetadata(),
                const WatermarkConfig(),
              ),
              config: const WatermarkConfig(),
              onSelected: (t) => picked = t,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(WatermarkTemplateTile), findsNWidgets(8));
    await tester.ensureVisible(find.text('Banner'));
    await tester.tap(find.text('Banner'));
    expect(picked, WatermarkTemplate.banner);
  });
}
