import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/services/gallery_scanner.dart';
import 'package:gps_camera/features/gallery/utils/photo_info_formatter.dart';
import 'package:gps_camera/features/location/models/gps_accuracy_level.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/location/models/place_info.dart';
import 'package:gps_camera/features/watermark/utils/capture_time_formatter.dart';
import 'package:gps_camera/shared/widgets/section_header.dart';

/// Metadata sections for one photo. Values are shown as stored; nothing is
/// estimated or filled in.
class PhotoDetailsPanel extends StatelessWidget {
  const PhotoDetailsPanel({
    super.key,
    required this.photo,
    required this.dimensions,
    required this.related,
  });

  final GalleryPhoto photo;
  final ImageDimensions? dimensions;

  /// Related photos section, built by the caller.
  final Widget related;

  @override
  Widget build(BuildContext context) {
    final metadata = photo.metadata;
    final record = photo.record;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: 'Capture',
          rows: metadata == null
              ? [_Row('Status', _missingMetadata(photo))]
              : [
                  _Row('Taken', PhotoInfoFormatter.captureFull(metadata)),
                  _Row('Time zone', metadata.timeZoneName),
                ],
        ),
        if (metadata != null)
          _LocationSection(location: metadata.location, place: metadata.place),
        if (metadata?.direction != null)
          _Section(
            title: 'Camera direction',
            rows: [_Row('Facing', metadata!.direction!.description)],
          ),
        if (record != null)
          _Section(
            title: 'Watermark',
            rows: [
              _Row('Template', record.config.template.label.tr),
              _Row('Rendered', PhotoInfoFormatter.instant(record.renderedAt)),
            ],
          ),
        _Section(
          title: 'File',
          rows: [
            _Row('Name', photo.fileName),
            _Row(
              'Dimensions',
              dimensions == null
                  ? '—'
                  : '${dimensions!.width} × ${dimensions!.height} px',
            ),
            _Row('Size', PhotoInfoFormatter.fileSize(photo.sizeBytes)),
          ],
        ),
        related,
      ],
    );
  }

  static String _missingMetadata(GalleryPhoto photo) => switch (photo.issue) {
    GalleryIssue.metadataUnreadable => 'Metadata file is damaged'.tr,
    GalleryIssue.recordUnreadable => 'Render record is damaged'.tr,
    GalleryIssue.recordMissing => 'Render record is missing'.tr,
    _ when photo.isWatermarked => 'Capture data not available'.tr,
    _ => 'No metadata was saved for this photo'.tr,
  };
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.location, required this.place});

  final LocationSnapshot location;
  final PlaceInfo? place;

  @override
  Widget build(BuildContext context) {
    final fix = location.fix;
    final status = switch (location.status) {
      LocationRecordStatus.current => 'Current'.tr,
      LocationRecordStatus.stale => 'Stale (last known location)'.tr,
      LocationRecordStatus.unavailable => 'Unavailable · @reason'.trParams({
        'reason': _reason(location.reason),
      }),
    };

    return _Section(
      title: 'Location',
      rows: [
        _Row('Status', status),
        if (fix != null) ...[
          _Row('Latitude', '${fix.latitude}°'),
          _Row('Longitude', '${fix.longitude}°'),
          _Row(
            'Accuracy',
            '±${PhotoInfoFormatter.length(fix.accuracy)} · '
                '${_level(GpsAccuracyLevel.fromMeters(fix.accuracy))}',
          ),
          if (location.fixAge != null)
            _Row(
              'Fix age',
              '@age before capture'.trParams({
                'age': CaptureTimeFormatter.age(location.fixAge!),
              }),
            ),
          if (fix.altitude != null) _Row('Altitude', _altitude(fix)),
          if (fix.heading != null)
            _Row(
              'Direction of travel',
              '${PhotoInfoFormatter.measured(fix.heading!, maxDecimals: 1)}°',
            ),
          ..._placeRows(place, fix),
          if (fix.isMocked) _Row('Source', 'Mock location provider'.tr),
        ],
      ],
    );
  }

  /// Address rows only when stored; the Plus Code is always derivable.
  static List<_Row> _placeRows(PlaceInfo? place, LocationFix fix) {
    if (place == null) {
      return [if (fix.address != null) _Row('Address', fix.address!)];
    }
    return [
      if (place.title != null) _Row('Place', place.title!),
      _Row('Address', place.addressLine ?? 'Unavailable (no address found)'.tr),
      _Row('Plus Code', place.plusCode),
      _Row(
        'Address source',
        'Device geocoder · @time'.trParams({
          'time': PhotoInfoFormatter.instant(place.resolvedAt),
        }),
      ),
    ];
  }

  static String _altitude(LocationFix fix) {
    final reference = switch (fix.altitudeReference) {
      AltitudeReference.wgs84Ellipsoid => 'above WGS84 ellipsoid'.tr,
      AltitudeReference.meanSeaLevel => 'above mean sea level'.tr,
      null => 'reference unknown'.tr,
    };
    final accuracy = fix.altitudeAccuracy == null
        ? ''
        : ' (±${PhotoInfoFormatter.length(fix.altitudeAccuracy!)})';
    return '${PhotoInfoFormatter.length(fix.altitude!)} $reference'
        '$accuracy';
  }

  static String _level(GpsAccuracyLevel level) => switch (level) {
    GpsAccuracyLevel.good => 'Good'.tr,
    GpsAccuracyLevel.moderate => 'Moderate'.tr,
    GpsAccuracyLevel.poor => 'Poor'.tr,
  };

  static String _reason(LocationUnavailableReason? reason) => switch (reason) {
    LocationUnavailableReason.permissionDenied => 'permission denied'.tr,
    LocationUnavailableReason.locationServicesDisabled =>
      'location services off'.tr,
    LocationUnavailableReason.noFixYet => 'no GPS fix yet'.tr,
    LocationUnavailableReason.gpsUnavailable => 'GPS unavailable'.tr,
    null => 'not recorded'.tr,
  };
}

class _Row {
  const _Row(this.label, this.value);

  final String label;
  final String value;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title.tr),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  for (final (i, row) in rows.indexed) ...[
                    if (i > 0) const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              row.label.tr,
                              style: context.text.bodyMedium?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SelectableText(
                              row.value,
                              style: context.text.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
