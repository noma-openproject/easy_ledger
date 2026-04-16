import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'jwt.dart';
import 'local_callback_server.dart';
import 'pkce.dart';

/// OpenAI Codex OAuth (PKCE authorization-code flow).
///
/// 참조: OpenClaw(noma_kr) pi-ai SDK `utils/oauth/openai-codex.js`.
///
/// ⚠️ 아키텍처 문서 v3의 "device flow" 표현은 오기. 실제로는
/// **PKCE authorization code flow + 로컬 HTTP 콜백 서버** 이다.
///
/// - CLIENT_ID는 OpenAI Codex CLI의 공개 ID이고 OpenClaw도 동일 사용.
/// - REDIRECT_URI가 localhost:1455 로 고정되어 있어 로컬 HTTP 서버 필요.
/// - Codex responses 요청 시 `chatgpt-account-id` 헤더가 필수이며,
///   JWT payload의 `https://api.openai.com/auth.chatgpt_account_id` 에서 추출.
class CodexOAuth {
  static const clientId = 'app_EMoamEEZ73f0CkXaXp7hrann';
  static const authorizeUrl = 'https://auth.openai.com/oauth/authorize';
  static const tokenUrl = 'https://auth.openai.com/oauth/token';
  static const redirectUri = 'http://localhost:1455/auth/callback';
  static const scope = 'openid profile email offline_access';
  static const originator = 'pi';

  final Dio _dio;
  CodexOAuth(this._dio);

  /// 로그인 플로우 전체.
  ///
  /// [onOpenBrowser]: authorize URL을 외부 브라우저로 여는 콜백.
  /// 호출 측에서 `url_launcher.launchUrl(..., mode: LaunchMode.externalApplication)` 등을 수행.
  Future<CodexTokens> login({
    required Future<void> Function(Uri authorizeUri) onOpenBrowser,
  }) async {
    debugPrint('[OAuth] CodexOAuth.login: start');
    final pkce = await generatePkce();
    final state = generateState();
    debugPrint(
      '[OAuth] pkce generated: verifier.len=${pkce.verifier.length} '
      'challenge.len=${pkce.challenge.length} state.len=${state.length}',
    );

    final server = LocalCallbackServer();
    final waitFuture = server.waitForCode(expectedState: state);
    debugPrint('[OAuth] local callback server listening on 127.0.0.1:1455');

    try {
      final authUri = Uri.parse(authorizeUrl).replace(
        queryParameters: {
          'response_type': 'code',
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'scope': scope,
          'code_challenge': pkce.challenge,
          'code_challenge_method': 'S256',
          'state': state,
          'id_token_add_organizations': 'true',
          'codex_cli_simplified_flow': 'true',
          'originator': originator,
        },
      );
      debugPrint('[OAuth] authorize URL: ${authUri.origin}${authUri.path}');

      await onOpenBrowser(authUri);
      debugPrint('[OAuth] browser launched, waiting for callback...');

      final result = await waitFuture;
      debugPrint(
        '[OAuth] code received: code.len=${result.code.length} '
        'state matches=${result.state == state}',
      );

      final tokens = await _exchangeCodeForTokens(result.code, pkce.verifier);
      debugPrint(
        '[OAuth] tokens built: access.len=${tokens.access.length} '
        'refresh.len=${tokens.refresh.length} '
        'expiresAtMs=${tokens.expiresAtMs} accountId.len=${tokens.accountId.length}',
      );
      return tokens;
    } catch (e, st) {
      debugPrint('[OAuth] CodexOAuth.login: EXCEPTION: $e');
      debugPrint('[OAuth] stack:\n$st');
      rethrow;
    } finally {
      await server.close();
      debugPrint('[OAuth] local callback server closed');
    }
  }

  /// refresh_token으로 새 access_token 받기.
  Future<CodexTokens> refresh(String refreshToken) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      tokenUrl,
      data: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': clientId,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.json,
        validateStatus: (_) => true,
      ),
    );
    if (resp.statusCode != 200) {
      throw CodexOAuthException(
        'refresh failed (${resp.statusCode}): ${resp.data}',
      );
    }
    final data = resp.data!;
    return _buildTokens(data);
  }

  Future<CodexTokens> _exchangeCodeForTokens(
    String code,
    String verifier,
  ) async {
    debugPrint('[OAuth] POST $tokenUrl (authorization_code)');
    final resp = await _dio.post<Map<String, dynamic>>(
      tokenUrl,
      data: {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'code': code,
        'code_verifier': verifier,
        'redirect_uri': redirectUri,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.json,
        validateStatus: (_) => true,
      ),
    );
    debugPrint('[OAuth] token exchange status=${resp.statusCode}');
    if (resp.statusCode != 200) {
      debugPrint('[OAuth] token exchange ERROR body: ${resp.data}');
      throw CodexOAuthException(
        'code→token exchange failed (${resp.statusCode}): ${resp.data}',
      );
    }
    debugPrint(
      '[OAuth] token exchange OK: response keys=${(resp.data ?? {}).keys.toList()}',
    );
    return _buildTokens(resp.data!);
  }

  CodexTokens _buildTokens(Map<String, dynamic> data) {
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    final expiresIn = data['expires_in'];

    debugPrint(
      '[OAuth] _buildTokens: access=${access == null ? "null" : "len=${access.length}"} '
      'refresh=${refresh == null ? "null" : "len=${refresh.length}"} '
      'expires_in=$expiresIn (${expiresIn.runtimeType})',
    );

    if (access == null || refresh == null || expiresIn is! num) {
      throw CodexOAuthException(
        'token response missing fields: keys=${data.keys.toList()}',
      );
    }

    // JWT payload 클레임 키 덤프 (값 없음)
    try {
      final parts = access.split('.');
      if (parts.length == 3) {
        var p = parts[1];
        final pad = p.length % 4;
        if (pad != 0) p = p + '=' * (4 - pad);
        final json = utf8.decode(base64Url.decode(p));
        final payload = jsonDecode(json) as Map<String, dynamic>;
        debugPrint(
          '[OAuth] JWT payload top-level keys=${payload.keys.toList()}',
        );
        final auth = payload['https://api.openai.com/auth'];
        if (auth is Map<String, dynamic>) {
          debugPrint(
            '[OAuth] JWT auth claim keys=${auth.keys.toList()} '
            'chatgpt_account_id=${auth['chatgpt_account_id'] != null ? "present" : "MISSING"}',
          );
        } else {
          debugPrint(
            '[OAuth] JWT payload has NO "https://api.openai.com/auth" claim',
          );
        }
      }
    } catch (e) {
      debugPrint('[OAuth] JWT inspect error: $e');
    }

    final accountId = extractChatGptAccountId(access);
    if (accountId == null) {
      throw CodexOAuthException(
        'chatgpt_account_id not found in access_token JWT',
      );
    }

    return CodexTokens(
      access: access,
      refresh: refresh,
      expiresAtMs:
          DateTime.now().millisecondsSinceEpoch + (expiresIn.toInt() * 1000),
      accountId: accountId,
    );
  }
}

class CodexTokens {
  final String access;
  final String refresh;
  final int expiresAtMs;
  final String accountId;

  const CodexTokens({
    required this.access,
    required this.refresh,
    required this.expiresAtMs,
    required this.accountId,
  });

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch >= expiresAtMs - 30000; // 30s 여유

  Map<String, String> toMap() => {
    'access': access,
    'refresh': refresh,
    'expires_at_ms': expiresAtMs.toString(),
    'account_id': accountId,
  };

  static CodexTokens? fromMap(Map<String, String?> m) {
    final a = m['access'];
    final r = m['refresh'];
    final exp = m['expires_at_ms'];
    final acc = m['account_id'];
    if (a == null || r == null || exp == null || acc == null) return null;
    final expNum = int.tryParse(exp);
    if (expNum == null) return null;
    return CodexTokens(
      access: a,
      refresh: r,
      expiresAtMs: expNum,
      accountId: acc,
    );
  }
}

class CodexOAuthException implements Exception {
  final String message;
  CodexOAuthException(this.message);
  @override
  String toString() => 'CodexOAuthException: $message';
}
