import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wrapper around google_sign_in v7 that works on Android, iOS and web.
///
/// .env keys:
///   GOOGLE_WEB_CLIENT_ID  (required) - same value as backend GOOGLE_CLIENT_ID
///   GOOGLE_IOS_CLIENT_ID  (optional) - only if you ship iOS
///
/// Mobile: call [signInAndGetIdToken] (opens the native account picker).
/// Web:    render the Google button (see google_web_button.dart) and listen
///         to [webIdTokens]; web does not support authenticate().
class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  static String get _webClientId {
    final id = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    if (id == null || id.isEmpty) {
      throw 'GOOGLE_WEB_CLIENT_ID is missing from .env';
    }
    return id;
  }

  static String? get _iosClientId {
    final id = dotenv.env['GOOGLE_IOS_CLIENT_ID'];
    return (id == null || id.isEmpty) ? null : id;
  }

  final GoogleSignIn _signIn = GoogleSignIn.instance;

  Future<void>? _initFuture;

  Future<void> _ensureInitialized() => _initFuture ??= _initOnce();

  Future<void> _initOnce() async {
    try {
      if (kIsWeb) {
        // Web takes the Web client ID as clientId (serverClientId is unsupported).
        await _signIn.initialize(clientId: _webClientId);
      } else {
        // Android/iOS: serverClientId makes the ID token's audience the
        // Web client ID, which is what the backend verifies.
        await _signIn.initialize(
          clientId: _iosClientId,
          serverClientId: _webClientId,
        );
      }
    } on StateError catch (e) {
      // Already initialized (e.g. after a hot restart) - safe to continue.
      debugPrint('GoogleSignIn already initialized: $e');
    } catch (e) {
      _initFuture = null; // allow retry if init genuinely failed
      rethrow;
    }
  }

  /// WEB: emits an ID token each time the user signs in with the Google button.
  Stream<String> webIdTokens() async* {
    await _ensureInitialized();
    await for (final event in _signIn.authenticationEvents) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        final token = event.user.authentication.idToken;
        if (token != null) yield token;
      }
    }
  }

  /// MOBILE: returns the Google ID token, or null if the user closed the
  /// picker. Throws a String message for any other failure.
  Future<String?> signInAndGetIdToken() async {
    if (kIsWeb) {
      throw 'On web, use the Google button instead of this method.';
    }

    await _ensureInitialized();

    if (!_signIn.supportsAuthenticate()) {
      throw 'Google Sign-In isn\'t supported on this platform yet.';
    }

    try {
      final GoogleSignInAccount account = await _signIn.authenticate();
      final String? idToken = account.authentication.idToken;
      if (idToken == null) {
        throw 'Google didn\'t return an ID token. Double-check that GOOGLE_WEB_CLIENT_ID is your Web client ID.';
      }
      return idToken;
    } on GoogleSignInException catch (e) {
      debugPrint(
          'Google sign-in: code=${e.code} description=${e.description} details=${e.details}');
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      throw 'Google sign-in failed: ${e.description ?? e.code}';
    }
  }

  /// Normal logout. Does NOT revoke the app's access.
  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await _signIn.signOut();
    } catch (e) {
      debugPrint('Google signOut error: $e');
    }
  }

  /// Revokes access. Only for "unlink Google" / "delete account".
  Future<void> disconnect() async {
    try {
      await _ensureInitialized();
      await _signIn.disconnect();
    } catch (e) {
      debugPrint('Google disconnect error: $e');
    }
  }
}