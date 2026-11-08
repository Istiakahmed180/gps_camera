import 'package:get/get.dart';
import 'package:gps_camera/app/i18n/ar/ar.dart';
import 'package:gps_camera/app/i18n/bn/bn.dart';
import 'package:gps_camera/app/i18n/es/es.dart';
import 'package:gps_camera/app/i18n/hi/hi.dart';
import 'package:gps_camera/app/i18n/id/id.dart';
import 'package:gps_camera/app/i18n/pt/pt.dart';

/// UI text. Keys are the English text itself, so English needs no table:
/// a key without a translation is shown as is.
///
/// Rules for adding text:
/// * Wrap every user-facing string: `'Open camera'.tr`.
/// * Values: `'Adding photo @done of @total'.trParams({...})`.
/// * Counts: `'@n photo'.trCount('@n photos', n, {'n': '$n'})`;
///   languages with one form map both keys to the same text.
/// * PDF reports are written in the app language (Bangla, Hindi and
///   Arabic text is drawn by Flutter, see `ReportTextShaper`). CSV exports
///   stay in English.
/// * Every new key needs an entry in each table below, and every new
///   count its Arabic forms in `arPlurals`.
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'bn_BD': bn,
    'hi_IN': hi,
    'id_ID': id,
    'es_ES': es,
    'pt_BR': pt,
    'ar_SA': ar,
  };
}
