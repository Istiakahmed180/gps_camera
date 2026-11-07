import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/services/gallery_scanner.dart';
import 'package:gps_camera/features/gallery/utils/photo_info_formatter.dart';
import 'package:gps_camera/features/location/models/gps_accuracy_level.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
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
        if (metadata != null) _LocationSection(location: metadata.location),
        if (record != null)
          _Section(
            title: 'Watermark',
            rows: [
              _Row('Template', record.config.template.label),
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
    GalleryIssue.metadataUnreadable => 'Metadata file is damaged',
    GalleryIssue.recordUnreadable => 'Render record is damaged',
    GalleryIssue.recordMissing => 'Render record is missing',
    _ when photo.isWatermarked => 'Capture data not available',
    _ => 'No metadata was saved for this photo',
  };
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.location});

  final LocationSnapshot location;

  @override
  Widget build(BuildContext context) {
    final fix = location.fix;
    final status = switch (location.status) {
      LocationRecordStatus.current => 'Current',
      LocationRecordStatus.stale => 'Stale (last known location)',
      LocationRecordStatus.unavailable =>
        'Unavailable · ${_reason(location.reason)}',
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
            '±${PhotoInfoFormatter.measured(fix.accuracy)} m · '
                '${_level(GpsAccuracyLevel.fromMeters(fix.accuracy))}',
          ),
          if (location.fixAge != null)
            _Row(
              'Fix age',
              '${CaptureTimeFormatter.age(location.fixAge!)} before capture',
            ),
          if (fix.altitude != null) _Row('Altitude', _altitude(fix)),
          if (fix.heading != null)
            _Row(
              'Direction of travel',
              '${PhotoInfoFormatter.measured(fix.heading!, maxDecimals: 1)}°',
            ),
          if (fix.address != null) _Row('Address', fix.address!),
          if (fix.isMocked) const _Row('Source', 'Mock location provider'),
        ],
      ],
    );
  }

  static String _altitude(LocationFix fix) {
    final reference = switch (fix.altitudeReference) {
      AltitudeReference.wgs84Ellipsoid => 'above WGS84 ellipsoid',
      AltitudeReference.meanSeaLevel => 'above mean sea level',
      null => 'reference unknown',
    };
    final accuracy = fix.altitudeAccuracy == null
        ? ''
        : ' (±${PhotoInfoFormatter.measured(fix.altitudeAccuracy!)} m)';
    return '${PhotoInfoFormatter.measured(fix.altitude!)} m $reference'
        '$accuracy';
  }

  static String _level(GpsAccuracyLevel level) => switch (level) {
    GpsAccuracyLevel.good => 'Good',
    GpsAccuracyLevel.moderate => 'Moderate',
    GpsAccuracyLevel.poor => 'Poor',
  };

  static String _reason(LocationUnavailableReason? reason) => switch (reason) {
    LocationUnavailableReason.permissionDenied => 'permission denied',
    LocationUnavailableReason.locationServicesDisabled =>
      'location services off',
    LocationUnavailableReason.noFixYet => 'no GPS fix yet',
    LocationUnavailableReason.gpsUnavailable => 'GPS unavailable',
    null => 'not recorded',
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
          SectionHeader(title),
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
                              row.label,
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
