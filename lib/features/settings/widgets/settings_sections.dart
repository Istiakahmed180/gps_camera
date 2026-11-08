import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/i18n/count_text.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/core/settings/display_format.dart';
import 'package:gps_camera/features/camera/models/photo_quality.dart';
import 'package:gps_camera/features/gallery/utils/photo_info_formatter.dart';
import 'package:gps_camera/features/settings/controllers/settings_controller.dart';

void _snack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? context.colors.error : null,
    ),
  );
}

/// Photo quality and the automatic watermarked copy.
class CameraSettings extends StatelessWidget {
  const CameraSettings({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text('Photo quality'.tr, style: context.text.titleMedium),
          ),
          RadioGroup<PhotoQuality>(
            groupValue: controller.photoQuality.value,
            onChanged: (value) {
              if (value != null) controller.setPhotoQuality(value);
            },
            child: Column(
              children: [
                for (final option in PhotoQuality.values)
                  RadioListTile<PhotoQuality>(
                    value: option,
                    title: Text(option.label.tr),
                    subtitle: Text(option.description.tr),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.branding_watermark_outlined),
            title: Text('Save watermarked copy'.tr),
            subtitle: Text(
              ('Also save a copy with the location overlay for every photo. '
                      'The original is always kept.')
                  .tr,
            ),
            value: controller.autoWatermark.value,
            onChanged: controller.setAutoWatermark,
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: Text('Volume buttons take photos'.tr),
            subtitle: Text(
              ('While the camera is open. Volume works normally everywhere '
                      'else.')
                  .tr,
            ),
            value: controller.volumeShutter.value,
            onChanged: controller.setVolumeShutter,
          ),
        ],
      ),
    );
  }
}

/// Time format and units for the watermark, camera, details and reports.
class DisplaySettings extends StatelessWidget {
  const DisplaySettings({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Obx(() {
        final format = controller.displayFormat.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ('Used on new watermarks, the camera screen, photo details and '
                      'reports. Saved values are not changed.')
                  .tr,
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Time'.tr, style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text('12-hour · 2:25 PM'.tr),
                ),
                ButtonSegment(value: true, label: Text('24-hour · 14:25'.tr)),
              ],
              selected: {format.use24Hour},
              onSelectionChanged: (s) => controller.setUse24Hour(s.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Accuracy and altitude'.tr, style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<UnitSystem>(
              showSelectedIcon: false,
              segments: [
                for (final unit in UnitSystem.values)
                  ButtonSegment(
                    value: unit,
                    label: Text('${unit.label.tr} (${unit.symbol})'),
                  ),
              ],
              selected: {format.units},
              onSelectionChanged: (s) => controller.setUnits(s.first),
            ),
          ],
        );
      }),
    );
  }
}

/// Adding the address and map to photos taken without internet.
class LocationDetailsSettings extends StatelessWidget {
  const LocationDetailsSettings({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final running = controller.fillingDetails.value;
      return ListTile(
        leading: const Icon(Icons.travel_explore_rounded),
        title: Text('Add missing addresses and maps'.tr),
        subtitle: Text(
          running
              ? 'Checking photos…'.tr
              : ('Photos taken without internet get them automatically when '
                        'the phone is online. Automatic watermarked copies are '
                        'made again with the new details.')
                    .tr,
        ),
        trailing: running
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        enabled: controller.canFillDetails && !running,
        onTap: () => _run(context),
      );
    });
  }

  Future<void> _run(BuildContext context) async {
    final result = await controller.fillMissingDetails();
    if (!context.mounted || result == null) return;
    if (result.updatedPhotos > 0) {
      _snack(
        context,
        [
          'Updated @n photo'.trCount(
            'Updated @n photos',
            result.updatedPhotos,
            {'n': '${result.updatedPhotos}'},
          ),
          if (result.replacedCopies > 0)
            'remade @n watermarked copy'.trCount(
              'remade @n watermarked copies',
              result.replacedCopies,
              {'n': '${result.replacedCopies}'},
            ),
          if (result.remaining > 0)
            '@n still waiting'.trParams({'n': '${result.remaining}'}),
        ].join(' · '),
      );
    } else if (result.remaining > 0) {
      _snack(
        context,
        ('@n photo still need details. Check the internet connection and '
                'try again.')
            .trCount(
              '@n photos still need details. Check the internet connection '
              'and try again.',
              result.remaining,
              {'n': '${result.remaining}'},
            ),
      );
    } else {
      _snack(context, 'All photos have their address and map.'.tr);
    }
  }
}

/// Space used per kind of data, and clearing the map cache.
class StorageSettings extends StatelessWidget {
  const StorageSettings({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final u = controller.usage.value;
      if (u == null) {
        return ListTile(title: Text('Measuring…'.tr));
      }
      String size(int bytes) => PhotoInfoFormatter.fileSize(bytes);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text('Total'.tr),
            trailing: Text(size(u.total), style: context.text.titleMedium),
          ),
          const Divider(height: 1),
          _row(
            // Videos are originals too.
            'Originals'.tr,
            '@n file'.trCount('@n files', u.photoCount, {
              'n': '${u.photoCount}',
            }),
            size(u.photos),
          ),
          _row(
            'Watermarked copies'.tr,
            '@n copy'.trCount('@n copies', u.watermarkedCount, {
              'n': '${u.watermarkedCount}',
            }),
            size(u.watermarked),
          ),
          _row('Maps saved with photos'.tr, null, size(u.maps)),
          _row(
            'Reports'.tr,
            '@n PDF'.trCount('@n PDFs', u.reportCount, {
              'n': '${u.reportCount}',
            }),
            size(u.reports),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: Text('Map cache'.tr),
            subtitle: Text(
              ('@n map kept so places you visit again need no download. '
                      'Clearing it never affects your photos.')
                  .trCount(
                    '@n maps kept so places you visit again need no '
                    'download. Clearing it never affects your photos.',
                    u.mapCacheCount,
                    {'n': '${u.mapCacheCount}'},
                  ),
            ),
            trailing: TextButton(
              onPressed: u.mapCacheCount == 0
                  ? null
                  : () async {
                      await controller.clearMapCache();
                      if (context.mounted) {
                        _snack(context, 'Map cache cleared'.tr);
                      }
                    },
              child: Text('Clear @size'.trParams({'size': size(u.mapCache)})),
            ),
          ),
        ],
      );
    });
  }

  Widget _row(String title, String? detail, String size) => ListTile(
    dense: true,
    title: Text(title),
    subtitle: detail == null ? null : Text(detail),
    trailing: Text(size),
  );
}
