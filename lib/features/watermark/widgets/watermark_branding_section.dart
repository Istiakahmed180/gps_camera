import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/services/logo_service.dart';
import 'package:gps_camera/shared/widgets/section_header.dart';

/// Heading text, an extra line and the logo.
class WatermarkBrandingSection extends StatefulWidget {
  const WatermarkBrandingSection({
    super.key,
    required this.config,
    required this.onChanged,
    this.logo,
  });

  final WatermarkConfig config;
  final ValueChanged<WatermarkConfig> onChanged;

  /// Null hides the logo controls (e.g. in tests).
  final LogoService? logo;

  @override
  State<WatermarkBrandingSection> createState() =>
      _WatermarkBrandingSectionState();
}

class _WatermarkBrandingSectionState extends State<WatermarkBrandingSection> {
  late final TextEditingController _brand = TextEditingController(
    text: widget.config.brandText,
  );
  late final TextEditingController _custom = TextEditingController(
    text: widget.config.customText,
  );
  bool _picking = false;

  @override
  void dispose() {
    _brand.dispose();
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Branding'.tr),
        TextField(
          controller: _brand,
          maxLength: WatermarkConfig.maxBrandLength,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Heading'.tr,
            hintText: 'Company or app name'.tr,
            helperText: 'Leave empty to hide it.'.tr,
            border: const OutlineInputBorder(),
            suffixIcon: config.brandText == WatermarkConfig.defaultBrand
                ? null
                : IconButton(
                    tooltip: 'Use “@brand”'.trParams({
                      'brand': WatermarkConfig.defaultBrand,
                    }),
                    icon: const Icon(Icons.restart_alt_rounded),
                    onPressed: () {
                      _brand.text = WatermarkConfig.defaultBrand;
                      widget.onChanged(
                        config.copyWith(
                          brandText: WatermarkConfig.defaultBrand,
                        ),
                      );
                    },
                  ),
          ),
          onChanged: (v) => widget.onChanged(config.copyWith(brandText: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _custom,
          maxLength: WatermarkConfig.maxCustomTextLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Extra line'.tr,
            hintText: 'e.g. Site: Block C · Inspector: Rahim'.tr,
            helperText: 'Shown under the heading on every photo.'.tr,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => widget.onChanged(config.copyWith(customText: v)),
        ),
        if (widget.logo != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _logoTile(context, widget.logo!),
        ],
      ],
    );
  }

  Widget _logoTile(BuildContext context, LogoService logo) {
    return Obx(() {
      final image = logo.image.value;
      final config = widget.config;
      return Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            ListTile(
              leading: SizedBox.square(
                dimension: 44,
                child: image == null
                    ? const Icon(Icons.image_outlined)
                    : RawImage(image: image, fit: BoxFit.contain),
              ),
              title: Text('Logo'.tr),
              subtitle: Text(
                image == null
                    ? 'PNG or JPEG. A transparent PNG looks best.'.tr
                    : 'Shown beside the heading (not in Minimal).'.tr,
              ),
              trailing: _picking
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : image == null
                  ? TextButton(
                      onPressed: () => _pick(logo),
                      child: Text('Choose'.tr),
                    )
                  : PopupMenuButton<String>(
                      tooltip: 'Logo options'.tr,
                      onSelected: (v) =>
                          v == 'change' ? _pick(logo) : _remove(logo),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'change',
                          child: Text('Change'.tr),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove'.tr),
                        ),
                      ],
                    ),
            ),
            if (image != null)
              SwitchListTile(
                title: Text('Show logo'.tr),
                value: config.showLogo,
                onChanged: (v) =>
                    widget.onChanged(config.copyWith(showLogo: v)),
              ),
          ],
        ),
      );
    });
  }

  Future<void> _pick(LogoService logo) async {
    setState(() => _picking = true);
    try {
      final picked = await logo.pick();
      if (picked && mounted) {
        widget.onChanged(widget.config.copyWith(showLogo: true));
      }
    } on LogoException catch (e) {
      if (mounted) _snack(e.message.tr);
    } catch (_) {
      if (mounted) _snack('The logo could not be saved.'.tr);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _remove(LogoService logo) async {
    try {
      await logo.remove();
      if (mounted) widget.onChanged(widget.config.copyWith(showLogo: false));
    } catch (_) {
      if (mounted) _snack('The logo could not be removed.'.tr);
    }
  }

  void _snack(String message) {
    unawaited(
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: context.colors.error,
            ),
          )
          .closed,
    );
  }
}
