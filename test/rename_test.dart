import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/services/watermark_settings_store.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await mockPathProvider();
    await GetStorage.init();
  });

  setUp(() => GetStorage().erase());

  WatermarkSettingsStore store() =>
      WatermarkSettingsStore(StorageService(GetStorage()));

  Future<void> saveHeading(String heading) => GetStorage().write(
    StorageKeys.watermarkConfig,
    const WatermarkConfig().copyWith(brandText: heading).toJson(),
  );

  test('the old default heading becomes the new app name', () async {
    await saveHeading('GPS CAMERA');
    expect(store().load().brandText, 'LOCAPROOF');
    expect(WatermarkConfig.defaultBrand, 'LOCAPROOF');
  });

  test('a heading the user typed is kept', () async {
    await saveHeading('ACME BUILDERS');
    expect(store().load().brandText, 'ACME BUILDERS');
    await saveHeading('');
    expect(store().load().brandText, '');
  });
}
