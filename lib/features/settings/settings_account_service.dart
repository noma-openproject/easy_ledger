import 'package:url_launcher/url_launcher.dart';

import '../../core/oauth/codex_oauth.dart';
import '../../core/storage/secure_storage.dart';

class SettingsAccountService {
  final SecureStorage _storage;
  final CodexOAuth _oauth;

  SettingsAccountService({
    required SecureStorage storage,
    required CodexOAuth oauth,
  }) : _storage = storage,
       _oauth = oauth;

  Future<String> loginCodex() async {
    final tokens = await _oauth.login(
      onOpenBrowser: (uri) async {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok) {
          throw StateError('외부 브라우저를 열 수 없습니다. URL: $uri');
        }
      },
    );
    await _storage.writeCodexTokens(tokens);
    return _short(tokens.accountId);
  }

  Future<void> logoutCodex() => _storage.clearCodexTokens();

  Future<void> debugExpireCodexToken() => _storage.debugExpireCodexToken();

  Future<bool> saveGeminiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await _storage.clearGeminiKey();
      return false;
    }
    await _storage.writeGeminiKey(trimmed);
    return true;
  }

  static String shortAccountId(String id) => _short(id);

  static String _short(String id) =>
      id.length <= 10 ? id : '${id.substring(0, 10)}…';
}
