import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Fetches a small map image (PNG) centred on a point, with a marker, from
/// Geoapify's Static Maps API. Free plan: no credit card. Geoapify prints
/// its required attribution inside the image, so it must not be cropped.
class StaticMapService {
  StaticMapService(
    this._apiKey, {
    HttpClient? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? HttpClient();

  /// Square image side in logical pixels; the PNG is twice that.
  static const int side = 300;
  static const int zoom = 16;

  final String _apiKey;
  final HttpClient _client;
  final Duration timeout;

  Uri urlFor(double latitude, double longitude) {
    final point = 'lonlat:$longitude,$latitude';
    return Uri.https('maps.geoapify.com', '/v1/staticmap', {
      'style': 'osm-bright',
      'width': '$side',
      'height': '$side',
      'scaleFactor': '2',
      'format': 'png',
      'center': point,
      'zoom': '$zoom',
      'marker': '$point;color:#e53935;size:medium',
      'apiKey': _apiKey,
    });
  }

  /// PNG bytes, or null when offline, rate-limited or the key is invalid.
  Future<Uint8List?> fetch(double latitude, double longitude) async {
    try {
      final request = await _client
          .getUrl(urlFor(latitude, longitude))
          .timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await response.forEach(builder.add).timeout(timeout);
      final bytes = builder.takeBytes();
      return _isPng(bytes) ? bytes : null;
    } catch (_) {
      return null;
    }
  }

  static bool _isPng(Uint8List b) =>
      b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E;
}
