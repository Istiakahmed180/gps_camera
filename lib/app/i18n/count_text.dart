import 'package:get/get.dart';
import 'package:gps_camera/app/i18n/ar/ar_plurals.dart';

/// Count forms beyond singular/plural, per language code.
const Map<String, Map<String, Map<String, String>>> _extraForms = {
  'ar': arPlurals,
};

/// Arabic count form for [n]: `one` (1), `two` (2), `few` (3 to 10, also
/// 103 to 110 …) or `other` (0, 11 and up), which uses the singular noun.
String arabicCountForm(int n) {
  final m = n.abs() % 100;
  if (n.abs() == 1) return 'one';
  if (n.abs() == 2) return 'two';
  if (m >= 3 && m <= 10) return 'few';
  return 'other';
}

extension CountText on String {
  /// Like `trPluralParams`, but also uses a language's extra count forms
  /// (the Arabic dual, 3 to 10 and 11 and up). Use it for every count.
  String trCount(
    String pluralKey,
    int n, [
    Map<String, String> params = const {},
  ]) {
    final forms = _extraForms[Get.locale?.languageCode]?[pluralKey];
    if (forms != null && n.abs() != 1) {
      final text = forms[arabicCountForm(n)];
      if (text != null) {
        return params.entries.fold(
          text,
          (t, e) => t.replaceAll('@${e.key}', e.value),
        );
      }
    }
    return trPluralParams(pluralKey, n, params);
  }
}
