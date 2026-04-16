import 'dart:convert';

/// JWT에서 OpenAI `chatgpt_account_id`를 추출한다.
///
/// Codex responses 호출 시 `chatgpt-account-id` 헤더에 필수로 넣어야 한다.
/// 클레임 경로: `payload["https://api.openai.com/auth"]["chatgpt_account_id"]`
///
/// 실패 시 null 반환(호출 측이 에러 처리).
String? extractChatGptAccountId(String jwt) {
  try {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;

    final payloadJson = _decodeBase64UrlUtf8(parts[1]);
    final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

    final auth = payload['https://api.openai.com/auth'];
    if (auth is Map<String, dynamic>) {
      final id = auth['chatgpt_account_id'];
      if (id is String && id.isNotEmpty) return id;
    }
    return null;
  } catch (_) {
    return null;
  }
}

String _decodeBase64UrlUtf8(String raw) {
  var s = raw;
  final pad = s.length % 4;
  if (pad != 0) s = s + '=' * (4 - pad);
  final bytes = base64Url.decode(s);
  return utf8.decode(bytes);
}
