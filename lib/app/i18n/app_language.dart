import 'dart:ui';

import 'package:get/get.dart';
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/services/storage_service.dart';

/// The app's display language. [system] follows the phone.
enum AppLanguage {
  system('System', 'System', null),
  english('English', 'English', Locale('en', 'US')),
  bangla('বাংলা', 'Bangla', Locale('bn', 'BD')),
  hindi('हिन्दी', 'Hindi', Locale('hi', 'IN')),
  indonesian('Bahasa Indonesia', 'Indonesian', Locale('id', 'ID')),
  spanish('Español', 'Spanish', Locale('es', 'ES')),
  portuguese('Português (Brasil)', 'Portuguese', Locale('pt', 'BR')),
  arabic('العربية', 'Arabic', Locale('ar', 'SA'));

  const AppLanguage(this.label, this.englishName, this.locale);

  /// Shown in its own language, so anyone can find theirs.
  final String label;

  /// The language's name in English, shown under [label].
  final String englishName;
  final Locale? locale;

  /// Right-to-left scripts.
  bool get isRtl => locale?.languageCode == 'ar';

  static const Locale fallback = Locale('en', 'US');

  static List<Locale> get supported => [
    for (final l in values)
      if (l.locale != null) l.locale!,
  ];

  /// The language for [locale], matched by language code; null if the app
  /// does not offer it.
  static AppLanguage? forLocale(Locale? locale) {
    for (final l in values) {
      if (l.locale != null && l.locale!.languageCode == locale?.languageCode) {
        return l;
      }
    }
    return null;
  }
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

  /// The locale to show now: the chosen one, or the phone's language when
  /// the app offers it, otherwise English.
  Locale get locale => resolve(language.value, Get.deviceLocale);

  static Locale resolve(AppLanguage language, Locale? device) {
    final chosen = language.locale;
    if (chosen != null) return chosen;
    return AppLanguage.forLocale(device)?.locale ?? AppLanguage.fallback;
  }

  /// What [AppLanguage.system] currently resolves to on this phone.
  AppLanguage get phoneLanguage =>
      AppLanguage.forLocale(Get.deviceLocale) ?? AppLanguage.english;

  Future<void> setLanguage(AppLanguage value) async {
    language.value = value;
    await _storage.write(StorageKeys.language, value.name);
    await Get.updateLocale(locale);
  }
}
