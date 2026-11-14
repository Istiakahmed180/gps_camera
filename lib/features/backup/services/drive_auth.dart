import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:gps_camera/core/config/google_config.dart';
import 'package:gps_camera/features/backup/services/drive_store.dart';
import 'package:http/http.dart' as http;

/// Why Google Drive could not be reached.
enum DriveAuthProblem {
  /// This build has no Google client ID (see [GoogleConfig]).
  notConfigured,

  /// The user closed the Google sign-in or permission screen.
  cancelled,

  /// Signed out, or permission withdrawn: sign in again.
  signedOut,

  /// Google refused the app (wrong package or signing key in the Google
  /// Cloud project), or another error.
  failed,
}

class DriveAuthException implements Exception {
  const DriveAuthException(this.problem, [this.detail]);

  final DriveAuthProblem problem;
  final String? detail;

  @override
  String toString() => 'DriveAuthException(${problem.name}): $detail';
}

/// Signing in to Google Drive, so tests can stand in for Google.
abstract interface class DriveConnector {
  /// Whether this build can sign in at all.
  bool get isConfigured;

  /// Shows Google's sign-in; returns the account's email.
  Future<String> signIn();

  /// Drive for [email]; shows Google screens only when [interactive].
  Future<DriveStore> open(String email, {bool interactive = false});

  /// The email of a user who already allowed Drive access, without showing
  /// anything; null when there is none. Finishes a sign-in that Android
  /// interrupted by closing the app behind Google's screens.
  Future<String?> restoreSignIn();

  Future<void> signOut();
}

/// Signs in with Google and opens the user's Drive with access to the
/// files this app creates only (`drive.file`), not the rest of their Drive.
class DriveAuth implements DriveConnector {
  /// Android only for now: iOS needs its own Google client set up first.
  @override
  bool get isConfigured =>
      GoogleConfig.isConfigured &&
      defaultTargetPlatform == TargetPlatform.android;

  static const List<String> scopes = [drive.DriveApi.driveFileScope];

  /// The plugin is set up once per isolate.
  static Future<void>? _platformReady;

  Future<void>? _ready;

  Future<void> _init() {
    if (!GoogleConfig.isConfigured) {
      throw const DriveAuthException(DriveAuthProblem.notConfigured);
    }
    return _ready ??= GoogleSignIn.instance.initialize(
      serverClientId: GoogleConfig.serverClientId,
    );
  }

  /// Shows Google's account picker and permission screen. Returns the
  /// signed-in email.
  @override
  Future<String> signIn() async {
    await _init();
    // Already allowed (e.g. the app was closed behind Google's screen last
    // time): no need to show anything again.
    final existing = await restoreSignIn();
    if (existing != null) return existing;
    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: scopes,
      );
      await account.authorizationClient.authorizeScopes(scopes);
      return account.email;
    } on GoogleSignInException catch (e) {
      throw _problem(e);
    }
  }

  @override
  Future<String?> restoreSignIn() async {
    await _init();
    try {
      final account = await GoogleSignIn.instance
          .attemptLightweightAuthentication();
      if (account == null) return null;
      final authorization = await account.authorizationClient
          .authorizationForScopes(scopes);
      return authorization == null ? null : account.email;
    } on GoogleSignInException {
      return null;
    }
  }

  /// Drive for [email]. Without [interactive] nothing is shown to the
  /// user, so it can run on its own; it then fails with
  /// [DriveAuthProblem.signedOut] when Google wants the user to confirm.
  /// Asks Google for that account's token directly: no sign-in check, which
  /// would briefly open Google's own screen and take over the phone.
  @override
  Future<DriveStore> open(String email, {bool interactive = false}) =>
      openForAccount(email, interactive: interactive);

  /// Drive for [email] with no screen at all, for the background job:
  /// works only while that user's permission is still in place.
  static Future<DriveStore> openForAccount(
    String email, {
    bool interactive = false,
  }) async {
    if (!GoogleConfig.isConfigured) {
      throw const DriveAuthException(DriveAuthProblem.notConfigured);
    }
    final platform = GoogleSignInPlatform.instance;
    await (_platformReady ??= platform.init(
      const InitParameters(serverClientId: GoogleConfig.serverClientId),
    ));
    Future<String?> token({bool prompt = false}) async =>
        (await platform.clientAuthorizationTokensForScopes(
          ClientAuthorizationTokensForScopesParameters(
            request: AuthorizationRequestDetails(
              scopes: scopes,
              userId: null,
              email: email,
              promptIfUnauthorized: prompt,
            ),
          ),
        ))?.accessToken;
    final String? first;
    try {
      first = await token(prompt: interactive);
    } on GoogleSignInException catch (e) {
      throw _problem(e);
    }
    if (first == null) {
      throw const DriveAuthException(DriveAuthProblem.signedOut);
    }
    return GoogleDriveStore(
      _FreshTokenClient(first, (stale) async {
        try {
          await platform.clearAuthorizationToken(
            ClearAuthorizationTokenParams(accessToken: stale),
          );
        } catch (_) {}
        return token();
      }),
    );
  }

  /// Signs out and withdraws Drive access. Files already in Drive stay.
  @override
  Future<void> signOut() async {
    try {
      await _init();
      await GoogleSignIn.instance.disconnect();
    } catch (_) {
      // Signed out locally either way.
    }
  }

  static DriveAuthException _problem(GoogleSignInException e) =>
      DriveAuthException(switch (e.code) {
        GoogleSignInExceptionCode.canceled ||
        GoogleSignInExceptionCode.interrupted => DriveAuthProblem.cancelled,
        GoogleSignInExceptionCode.uiUnavailable => DriveAuthProblem.signedOut,
        _ => DriveAuthProblem.failed,
      }, e.description);
}

/// Sends Drive requests with the user's access token, fetching a new one
/// when Google says it expired (tokens last about an hour, a first backup
/// can take longer) and repeating that request once.
class _FreshTokenClient extends http.BaseClient {
  _FreshTokenClient(this._token, this._renewWith);

  /// Gets a new token, given the one that stopped working; null when the
  /// user's permission is gone.
  final Future<String?> Function(String stale) _renewWith;
  final http.Client _inner = http.Client();
  String _token;

  Future<String> _renew() async {
    final next = await _renewWith(_token);
    if (next == null) {
      throw const DriveAuthException(DriveAuthProblem.signedOut);
    }
    return _token = next;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Only a request whose body is in memory can be sent twice.
    final again = request is http.Request ? _copy(request) : null;
    request.headers['Authorization'] = 'Bearer $_token';
    final response = await _inner.send(request);
    if (response.statusCode != 401 || again == null) return response;
    await response.stream.drain<void>();
    again.headers['Authorization'] = 'Bearer ${await _renew()}';
    return _inner.send(again);
  }

  static http.Request _copy(http.Request original) =>
      http.Request(original.method, original.url)
        ..headers.addAll(original.headers)
        ..bodyBytes = original.bodyBytes
        ..followRedirects = original.followRedirects
        ..maxRedirects = original.maxRedirects
        ..persistentConnection = original.persistentConnection;

  @override
  void close() => _inner.close();
}
