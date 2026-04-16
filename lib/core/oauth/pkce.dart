import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PKCE (RFC 7636) verifier / challenge 생성.
///
/// 참조: OpenClaw(noma_kr)의 pi-ai SDK `utils/oauth/pkce.js` 등가 구현.
/// - 32바이트 랜덤 → base64url(패딩 제거) = verifier
/// - SHA-256(utf8(verifier)) → base64url(패딩 제거) = challenge
///
/// 주의: `code_challenge_method=S256` 으로 보내야 함.
class PkceCodes {
  final String verifier;
  final String challenge;
  const PkceCodes({required this.verifier, required this.challenge});
}

Future<PkceCodes> generatePkce() async {
  final bytes = _randomBytes(32);
  final verifier = _base64UrlNoPad(bytes);

  final digest = sha256.convert(utf8.encode(verifier));
  final challenge = _base64UrlNoPad(Uint8List.fromList(digest.bytes));

  return PkceCodes(verifier: verifier, challenge: challenge);
}

/// 16바이트 랜덤 hex (OAuth state 파라미터용).
String generateState() {
  final bytes = _randomBytes(16);
  final buf = StringBuffer();
  for (final b in bytes) {
    buf.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return buf.toString();
}

Uint8List _randomBytes(int len) {
  final rng = Random.secure();
  final out = Uint8List(len);
  for (var i = 0; i < len; i++) {
    out[i] = rng.nextInt(256);
  }
  return out;
}

String _base64UrlNoPad(Uint8List bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}
