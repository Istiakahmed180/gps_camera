import 'package:gps_camera/app/i18n/bn/bn_camera.dart';
import 'package:gps_camera/app/i18n/bn/bn_common.dart';
import 'package:gps_camera/app/i18n/bn/bn_gallery_projects.dart';
import 'package:gps_camera/app/i18n/bn/bn_reports.dart';
import 'package:gps_camera/app/i18n/bn/bn_watermark_settings.dart';

/// All Bangla text, merged from the per-area tables.
final Map<String, String> bn = {
  ...bnCommon,
  ...bnCamera,
  ...bnGalleryProjects,
  ...bnWatermarkSettings,
  ...bnReports,
};
