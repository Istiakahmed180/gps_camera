import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/utils/photo_info_formatter.dart';

/// Matches photos against a typed search, e.g. "tongi pillar" or "07 nov".
/// Every word must appear somewhere: note, place, address, Plus Code, date,
/// file name or project.
abstract final class PhotoSearch {
  static List<String> words(String query) => query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  static bool matches(
    GalleryPhoto photo,
    List<String> words, {
    String? projectName,
  }) {
    if (words.isEmpty) return true;
    final text = haystack(photo, projectName: projectName);
    return words.every(text.contains);
  }

  /// Everything searchable about [photo], lower-cased.
  static String haystack(GalleryPhoto photo, {String? projectName}) {
    final m = photo.metadata;
    final place = m?.place;
    final fix = m?.location.fix;
    return [
      photo.fileName,
      ?m?.note,
      ?place?.title,
      ?place?.addressLine,
      ?place?.subLocality,
      ?place?.locality,
      ?place?.subAdministrativeArea,
      ?place?.postalCode,
      ?place?.plusCode,
      ?fix?.address,
      if (m != null) PhotoInfoFormatter.captureShort(m),
      ?projectName,
    ].join('\n').toLowerCase();
  }
}
