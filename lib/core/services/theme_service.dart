import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/services/storage_service.dart';

class ThemeService extends GetxService {
  ThemeService(this._storage);

  final StorageService _storage;

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;

  @override
  void onInit() {
    super.onInit();
    themeMode.value = _readStoredMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == themeMode.value) return;
    themeMode.value = mode;
    Get.changeThemeMode(mode);
    await _storage.write(StorageKeys.themeMode, mode.name);
  }

  ThemeMode _readStoredMode() {
    final stored = _storage.read<String>(StorageKeys.themeMode);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }
}
