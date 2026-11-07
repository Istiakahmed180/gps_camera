import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/services/theme_service.dart';

class SettingsController extends GetxController {
  SettingsController(this._themeService);

  final ThemeService _themeService;

  Rx<ThemeMode> get themeMode => _themeService.themeMode;

  Future<void> changeThemeMode(ThemeMode mode) =>
      _themeService.setThemeMode(mode);
}
