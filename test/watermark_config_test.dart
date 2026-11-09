import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_template.dart';
import 'package:gps_camera/features/watermark/services/watermark_settings_store.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const custom = WatermarkConfig(
    template: WatermarkTemplate.professional,
    showTime: false,
    showAddress: false,
    textSize: WatermarkTextSize.large,
    opacity: 0.7,
    position: WatermarkPosition.bottomRight,
  );

  test('round-trips through JSON', () {
    expect(WatermarkConfig.fromJson(custom.toJson()), custom);
  });

  test('invalid or missing values fall back to defaults', () {
    final restored = WatermarkConfig.fromJson({
      'template': 'neon',
      'showDate': 'yes',
      'opacity': 9,
      'position': null,
    });
    expect(restored.template, WatermarkTemplate.mapCard);
    expect(restored.showDate, isTrue);
    expect(restored.opacity, 1);
    expect(restored.position, WatermarkPosition.bottomLeft);
  });

  test('opacity is clamped to a readable minimum', () {
    expect(const WatermarkConfig().copyWith(opacity: 0.05).opacity, 0.4);
  });

  test('template selection changes only the template', () {
    final next = custom.copyWith(template: WatermarkTemplate.minimal);
    expect(next.template, WatermarkTemplate.minimal);
    expect(next.copyWith(template: custom.template), custom);
  });

  test('settings persist in local storage', () async {
    await mockPathProvider();
    await GetStorage.init('watermark_test');
    final store = WatermarkSettingsStore(
      StorageService(GetStorage('watermark_test')),
    );

    expect(store.load(), const WatermarkConfig());
    await store.save(custom);
    expect(store.load(), custom);
  });
}
