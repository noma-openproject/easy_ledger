// ignore_for_file: implementation_imports

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:googleapis_auth/src/access_credentials.dart';
import 'package:googleapis_auth/src/access_token.dart';
import 'package:http/http.dart' as http;

import 'google_oauth_config.dart';

class GoogleAuthService {
  static const spreadsheetsScope =
      'https://www.googleapis.com/auth/spreadsheets';

  final GoogleSignIn _signIn;
  auth.AuthClient? _client;

  GoogleAuthService({GoogleSignIn? signIn})
    : _signIn =
          signIn ??
          GoogleSignIn(
            clientId: GoogleOAuthConfig.clientId,
            scopes: const [spreadsheetsScope],
          );

  bool get isSignedIn => _signIn.currentUser != null;

  String? get userEmail => _signIn.currentUser?.email;

  Future<auth.AuthClient?> signIn() async {
    final account = await _signIn.signIn();
    if (account == null) return null;
    return _clientFor(account);
  }

  Future<auth.AuthClient?> currentAuthClient() async {
    final account = _signIn.currentUser ?? await _signIn.signInSilently();
    if (account == null) return null;
    return _clientFor(account);
  }

  Future<void> signOut() async {
    _client?.close();
    _client = null;
    await _signIn.signOut();
  }

  Future<auth.AuthClient> _clientFor(GoogleSignInAccount account) async {
    _client?.close();
    final authentication = await account.authentication;
    final accessToken = authentication.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Google access token을 받을 수 없습니다.');
    }
    final credentials = AccessCredentials(
      AccessToken(
        'Bearer',
        accessToken,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      null,
      const [spreadsheetsScope],
      idToken: authentication.idToken,
    );
    _client = auth.authenticatedClient(http.Client(), credentials);
    return _client!;
  }
}
