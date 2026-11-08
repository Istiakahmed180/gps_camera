import 'package:get/get.dart';
import 'package:gps_camera/app/i18n/bn/bn.dart';

/// UI text. Keys are the English text itself, so English needs no table:
/// a key without a translation is shown as is.
///
/// Rules for adding text:
/// * Wrap every user-facing string: `'Open camera'.tr`.
/// * Values: `'Adding photo @done of @total'.trParams({...})`.
/// * Counts: `'@n photo'.trPluralParams('@n photos', n, {'n': '$n'})`;
///   Bangla has one form, so both keys map to the same text.
/// * PDF reports and CSV exports stay in English (the PDF library cannot
///   shape Bangla script), so never translate text used only there.
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {'bn_BD': bn};
}
