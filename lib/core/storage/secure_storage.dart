import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../oauth/codex_oauth.dart';

/// OAuth 토큰 + Gemini API 키를 OS 시큐어 스토리지에 저장.
///
/// - macOS: Keychain
/// - Android: EncryptedSharedPreferences
///
/// ⚠️ 여기에 저장되는 값은 민감정보(Bearer 토큰, API 키).
/// 로그에 출력하거나 파일로 덤프하지 말 것.
class SecureStorage {
  static const _keyAccess = 'codex.access';
  static const _keyRefresh = 'codex.refresh';
  static const _keyExpires = 'codex.expires_at_ms';
  static const _keyAccountId = 'codex.account_id';
  static const _keyGemini = 'ai.gemini_key';

  final FlutterSecureStorage _s;

  SecureStorage([FlutterSecureStorage? storage])
    : _s =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            // macOS: ad-hoc signing 환경(무료 dev)에서는 Data Protection Keychain
            // 을 쓰려면 Apple Team ID 기반 access group 이 필요해 -34018 에러 발생.
            // legacy login keychain 을 사용해서 entitlement/team 없이도 동작시킨다.
            // entitlements 에 keychain-access-groups 도 추가되어 있어 team ID 가
            // 생기면 data protection keychain 으로 쉽게 전환 가능.
            mOptions: MacOsOptions(
              accessibility: KeychainAccessibility.unlocked,
              useDataProtectionKeyChain: false,
            ),
          );

  // ──────────────── Codex tokens ────────────────

  Future<CodexTokens?> readCodexTokens() async {
    try {
      final access = await _s.read(key: _keyAccess);
      final refresh = await _s.read(key: _keyRefresh);
      final expires = await _s.read(key: _keyExpires);
      final accountId = await _s.read(key: _keyAccountId);
      debugPrint(
        '[Storage] readCodexTokens: '
        'access=${access == null ? "NULL" : "present(len=${access.length})"} '
        'refresh=${refresh == null ? "NULL" : "present(len=${refresh.length})"} '
        'expires=${expires ?? "NULL"} '
        'accountId=${accountId == null ? "NULL" : "present(len=${accountId.length})"}',
      );
      return CodexTokens.fromMap({
        'access': access,
        'refresh': refresh,
        'expires_at_ms': expires,
        'account_id': accountId,
      });
    } catch (e, st) {
      debugPrint('[Storage] readCodexTokens THREW: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> writeCodexTokens(CodexTokens t) async {
    try {
      await _s.write(key: _keyAccess, value: t.access);
      await _s.write(key: _keyRefresh, value: t.refresh);
      await _s.write(key: _keyExpires, value: t.expiresAtMs.toString());
      await _s.write(key: _keyAccountId, value: t.accountId);
      debugPrint(
        '[Storage] writeCodexTokens OK: access.len=${t.access.length} '
        'refresh.len=${t.refresh.length} expiresAtMs=${t.expiresAtMs} '
        'accountId.len=${t.accountId.length}',
      );
    } catch (e, st) {
      debugPrint('[Storage] writeCodexTokens THREW: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> clearCodexTokens() async {
    await _s.delete(key: _keyAccess);
    await _s.delete(key: _keyRefresh);
    await _s.delete(key: _keyExpires);
    await _s.delete(key: _keyAccountId);
  }

  // ──────────────── Gemini key ────────────────

  Future<String?> readGeminiKey() => _s.read(key: _keyGemini);
  Future<void> writeGeminiKey(String key) =>
      _s.write(key: _keyGemini, value: key);
  Future<void> clearGeminiKey() => _s.delete(key: _keyGemini);

  // ──────────────── 디버그 전용: 토큰 만료 강제 ────────────────

  /// 개발 중 토큰 만료 플로우(401 → refresh) 테스트용.
  /// `expires_at_ms`를 과거로 덮어쓴다. 토큰 값은 그대로.
  Future<void> debugExpireCodexToken() async {
    final current = await _s.read(key: _keyExpires);
    if (current == null) return;
    await _s.write(key: _keyExpires, value: '0');
  }
}
