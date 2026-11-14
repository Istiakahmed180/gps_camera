/// Google Cloud settings for Google Drive backup.
///
/// The *web* OAuth client ID of the Locaproof Google Cloud project. Built
/// in below; another one can be passed at build time:
///
/// ```sh
/// flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID=123-abc.apps.googleusercontent.com
/// ```
///
/// See `docs/google-drive-setup.md`.
abstract final class GoogleConfig {
  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: _locaproofWebClient,
  );

  /// The "Locaproof server" web client of the Google Cloud project
  /// `gps-camera-514006`. Not a secret; a build can still override it.
  static const String _locaproofWebClient =
      '623740008737-dr7s6adiqsuq4bou1sd5n1deui85b2pn.apps.googleusercontent.com';

  static bool get isConfigured => serverClientId.isNotEmpty;
}
