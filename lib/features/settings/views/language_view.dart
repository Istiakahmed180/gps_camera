import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/i18n/app_language.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/shared/widgets/responsive_center.dart';

/// Every language the app offers, each written in its own script so anyone
/// can find theirs. Choosing one applies it at once.
class LanguageView extends StatelessWidget {
  const LanguageView({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Get.find<LanguageService>();
    return Scaffold(
      appBar: AppBar(title: Text('Language'.tr)),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: Obx(() {
            final selected = service.language.value;
            final phone = service.phoneLanguage;
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: [
                _LanguageTile(
                  title: 'Phone language'.tr,
                  subtitle: 'Follows the phone: now @language'.trParams({
                    'language': phone.label,
                  }),
                  icon: Icons.phone_android_rounded,
                  selected: selected == AppLanguage.system,
                  onTap: () => service.setLanguage(AppLanguage.system),
                ),
                const Divider(height: 1),
                for (final l in AppLanguage.values)
                  if (l != AppLanguage.system)
                    _LanguageTile(
                      title: l.label,
                      subtitle: l.englishName,
                      selected: selected == l,
                      // The name is in its own script; keep its own
                      // direction whatever the app's language is.
                      textDirection: l.isRtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      onTap: () => service.setLanguage(l),
                    ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Text(
                    'Text in the app, on new watermarks and in new PDF '
                            'reports.'
                        .tr,
                    style: context.text.bodySmall,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.icon,
    this.textDirection,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: icon == null ? null : Icon(icon),
      // Shaped in its own direction but lined up with the other names.
      title: Text(
        title,
        textDirection: textDirection,
        textAlign: Directionality.of(context) == TextDirection.rtl
            ? TextAlign.right
            : TextAlign.left,
      ),
      subtitle: Text(subtitle),
      selected: selected,
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: context.colors.primary)
          : null,
      onTap: onTap,
    );
  }
}
