import 'dart:ui';

import 'package:get/get.dart';
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/services/storage_service.dart';

/// The app's display language. [system] follows the phone.
enum AppLanguage {
  system('System', null),
  english('English', Locale('en', 'US')),
  bangla('বাংলা', Locale('bn', 'BD'));

  const AppLanguage(this.label, this.locale);

  /// Shown in its own language, so anyone can find theirs.
  final String label;
  final Locale? locale;

  static const Locale fallback = Locale('en', 'US');
  static const List<Locale> supported = [
    Locale('en', 'US'),
    Locale('bn', 'BD'),
  ];
}

/// Remembers and applies the chosen language.
class LanguageService extends GetxService {
  LanguageService(this._storage);

  final StorageService _storage;

  late final Rx<AppLanguage> language = AppLanguage.values
      .firstWhere(
        (l) => l.name == _storage.read<String>(StorageKeys.language),
        orElse: () => AppLanguage.system,
      )
      .obs;

  /// The locale to show now: the chosen one, or the phone's when it is
  /// Bangla, otherwise English.
  Locale get locale => resolve(language.value, Get.deviceLocale);

  static Locale resolve(AppLanguage language, Locale? device) {
    final chosen = language.locale;
    if (chosen != null) return chosen;
    return device?.languageCode == 'bn'
        ? AppLanguage.bangla.locale!
        : AppLanguage.fallback;
  }

  Future<void> setLanguage(AppLanguage value) async {
    language.value = value;
    await _storage.write(StorageKeys.language, value.name);
    await Get.updateLocale(locale);
  }
}
