import 'dart:async';
import 'dart:io';

/// OpenAI OAuth의 `redirect_uri = http://localhost:1455/auth/callback` 를 받기 위한
/// 로컬 HTTP 서버.
///
/// 참조: OpenClaw pi-ai `startLocalOAuthServer`.
///
/// macOS 샌드박스 주의: `com.apple.security.network.server` entitlement 필요.
/// (DebugProfile.entitlements / Release.entitlements 에 이미 추가)
///
/// 사용 패턴:
/// ```
/// final server = LocalCallbackServer();
/// final waitFuture = server.waitForCode(expectedState: state);  // 먼저 listen 시작
/// await onOpenBrowser(authorizeUrl);                            // 브라우저 열기
/// final result = await waitFuture;                              // 콜백 대기
/// await server.close();
/// ```
class LocalCallbackServer {
  static const host = '127.0.0.1';
  static const port = 1455;
  static const path = '/auth/callback';

  HttpServer? _server;

  Future<CallbackResult> waitForCode({
    required String expectedState,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final server = await HttpServer.bind(host, port);
    _server = server;

    final completer = Completer<CallbackResult>();

    late StreamSubscription<HttpRequest> sub;
    sub = server.listen(
      (req) async {
        try {
          if (req.uri.path != path) {
            _respondHtml(req, 404, _errorHtml('Callback route not found.'));
            return;
          }

          final state = req.uri.queryParameters['state'];
          final code = req.uri.queryParameters['code'];
          final error = req.uri.queryParameters['error'];

          if (error != null) {
            _respondHtml(req, 400, _errorHtml('OAuth error: $error'));
            if (!completer.isCompleted) {
              completer.completeError(
                StateError('OAuth provider returned error: $error'),
              );
            }
            return;
          }
          if (state != expectedState) {
            _respondHtml(req, 400, _errorHtml('State mismatch.'));
            if (!completer.isCompleted) {
              completer.completeError(StateError('state mismatch'));
            }
            return;
          }
          if (code == null || code.isEmpty) {
            _respondHtml(req, 400, _errorHtml('Missing authorization code.'));
            if (!completer.isCompleted) {
              completer.completeError(StateError('missing code'));
            }
            return;
          }

          _respondHtml(req, 200, _successHtml());
          if (!completer.isCompleted) {
            completer.complete(CallbackResult(code: code, state: state!));
          }
        } catch (e, st) {
          _respondHtml(req, 500, _errorHtml('Internal error: $e'));
          if (!completer.isCompleted) {
            completer.completeError(e, st);
          }
        }
      },
      onError: (Object e, StackTrace st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      },
    );

    try {
      final result = await completer.future.timeout(timeout);
      await sub.cancel();
      return result;
    } catch (e) {
      await sub.cancel();
      rethrow;
    }
  }

  Future<void> close() async {
    final s = _server;
    if (s != null) {
      await s.close(force: true);
      _server = null;
    }
  }
}

class CallbackResult {
  final String code;
  final String state;
  const CallbackResult({required this.code, required this.state});
}

void _respondHtml(HttpRequest req, int status, String body) {
  req.response
    ..statusCode = status
    ..headers.contentType = ContentType.html
    ..write(body);
  req.response.close();
}

String _successHtml() => '''<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><title>로그인 완료</title>
<style>body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:#f5f5f7;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}.card{background:#fff;padding:40px 48px;border-radius:16px;box-shadow:0 4px 16px rgba(0,0,0,.08);text-align:center}h1{font-size:20px;margin:0 0 8px;color:#1d1d1f}p{color:#86868b;margin:0;font-size:14px}</style>
</head><body><div class="card"><h1>✅ 로그인이 완료되었습니다</h1><p>이 창을 닫고 앱으로 돌아가세요.</p></div></body></html>''';

String _errorHtml(String msg) => '''<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><title>로그인 실패</title>
<style>body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:#fef2f2;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}.card{background:#fff;padding:40px 48px;border-radius:16px;box-shadow:0 4px 16px rgba(0,0,0,.08);text-align:center;max-width:420px}h1{font-size:20px;margin:0 0 8px;color:#b91c1c}p{color:#6b7280;margin:0;font-size:14px}</style>
</head><body><div class="card"><h1>❌ 로그인 실패</h1><p>$msg</p></div></body></html>''';
