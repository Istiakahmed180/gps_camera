import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
            child: Text('Photo quality', style: context.text.titleMedium),
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
                    title: Text(option.label),
                    subtitle: Text(option.description),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.branding_watermark_outlined),
            title: const Text('Save watermarked copy'),
            subtitle: const Text(
              'Also save a copy with the location overlay for every photo. '
              'The original is always kept.',
            ),
            value: controller.autoWatermark.value,
            onChanged: controller.setAutoWatermark,
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
              'Used on new watermarks, the camera screen, photo details and '
              'reports. Saved values are not changed.',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Time', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('12-hour · 2:25 PM')),
                ButtonSegment(value: true, label: Text('24-hour · 14:25')),
              ],
              selected: {format.use24Hour},
              onSelectionChanged: (s) => controller.setUse24Hour(s.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Accuracy and altitude', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<UnitSystem>(
              showSelectedIcon: false,
              segments: [
                for (final unit in UnitSystem.values)
                  ButtonSegment(
                    value: unit,
                    label: Text('${unit.label} (${unit.symbol})'),
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
        title: const Text('Add missing addresses and maps'),
        subtitle: Text(
          running
              ? 'Checking photos…'
              : 'Photos taken without internet get them automatically when '
                    'the phone is online. Automatic watermarked copies are '
                    'made again with the new details.',
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
    String plural(int n, String w) => '$n $w${n == 1 ? '' : 's'}';
    if (result.updatedPhotos > 0) {
      _snack(
        context,
        [
          'Updated ${plural(result.updatedPhotos, 'photo')}',
          if (result.replacedCopies > 0)
            'remade ${result.replacedCopies} watermarked '
                '${result.replacedCopies == 1 ? 'copy' : 'copies'}',
          if (result.remaining > 0) '${result.remaining} still waiting',
        ].join(' · '),
      );
    } else if (result.remaining > 0) {
      _snack(
        context,
        '${plural(result.remaining, 'photo')} still need details. Check the '
        'internet connection and try again.',
      );
    } else {
      _snack(context, 'All photos have their address and map.');
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
        return const ListTile(title: Text('Measuring…'));
      }
      String size(int bytes) => PhotoInfoFormatter.fileSize(bytes);
      String count(int n, String w) => '$n $w${n == 1 ? '' : 's'}';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: const Text('Total'),
            trailing: Text(size(u.total), style: context.text.titleMedium),
          ),
          const Divider(height: 1),
          _row('Original photos', count(u.photoCount, 'photo'), size(u.photos)),
          _row(
            'Watermarked copies',
            u.watermarkedCount == 1 ? '1 copy' : '${u.watermarkedCount} copies',
            size(u.watermarked),
          ),
          _row('Maps saved with photos', null, size(u.maps)),
          _row('Reports', count(u.reportCount, 'PDF'), size(u.reports)),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('Map cache'),
            subtitle: Text(
              '${count(u.mapCacheCount, 'map')} kept so places you visit '
              'again need no download. Clearing it never affects your '
              'photos.',
            ),
            trailing: TextButton(
              onPressed: u.mapCacheCount == 0
                  ? null
                  : () async {
                      await controller.clearMapCache();
                      if (context.mounted) _snack(context, 'Map cache cleared');
                    },
              child: Text('Clear ${size(u.mapCache)}'),
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
