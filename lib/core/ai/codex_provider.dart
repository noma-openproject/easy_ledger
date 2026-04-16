import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../oauth/codex_oauth.dart';
import '../storage/secure_storage.dart';
import 'ai_provider.dart';
import 'receipt_prompt.dart';

/// ChatGPT Codex (chatgpt.com/backend-api/codex/responses) 기반 영수증 추출.
///
/// 참조: OpenClaw pi-ai `providers/openai-codex-responses.js`.
/// - SSE 스트림으로 응답이 옴
/// - `response.output_text.delta` 이벤트의 `delta` 필드를 이어붙여서 JSON 조립
/// - `response.completed` / `response.done` / `response.incomplete` 로 종료
/// - 401 Unauthorized 수신 시 1회에 한해 refresh 후 재시도
class CodexProvider implements AiProvider {
  static const endpoint = 'https://chatgpt.com/backend-api/codex/responses';

  /// 계정 플랜에 따라 다른 모델만 허용될 수 있음.
  /// 실패 시 다음 모델로 폴백.
  static const modelFallbackChain = [
    'gpt-5.4',
    'gpt-5.1',
    'gpt-5.1-codex-mini',
  ];

  final Dio _dio;
  final SecureStorage _storage;
  final CodexOAuth _oauth;

  CodexProvider({
    required Dio dio,
    required SecureStorage storage,
    required CodexOAuth oauth,
  }) : _dio = dio,
       _storage = storage,
       _oauth = oauth;

  @override
  String get name => 'codex';

  @override
  Future<ReceiptExtraction> extractReceipt(File imageFile) async {
    final stopwatch = Stopwatch()..start();
    var tokens = await _storage.readCodexTokens();
    if (tokens == null) {
      throw StateError('Codex: 로그인이 필요합니다.');
    }
    if (tokens.isExpired) {
      tokens = await _oauth.refresh(tokens.refresh);
      await _storage.writeCodexTokens(tokens);
    }

    final bytes = await imageFile.readAsBytes();
    final b64 = base64Encode(bytes);
    final mime = _guessMime(imageFile.path);

    Object? lastError;
    for (final model in modelFallbackChain) {
      try {
        final text = await _callOnce(
          tokens: tokens,
          model: model,
          base64Image: b64,
          mimeType: mime,
          allowRefresh: true,
        );
        final parsed = _parseJson(text);
        stopwatch.stop();
        return ReceiptExtraction(
          parsed: parsed,
          rawText: text,
          providerName: 'codex/$model',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } on _ModelRejectedException catch (e) {
        lastError = e;
        continue;
      }
    }

    throw StateError(
      'Codex 모든 모델 시도 실패. 최종 에러: $lastError\n(지원 모델 chain: $modelFallbackChain)',
    );
  }

  Future<String> _callOnce({
    required CodexTokens tokens,
    required String model,
    required String base64Image,
    required String mimeType,
    required bool allowRefresh,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'store': false,
      'stream': true,
      'instructions': kReceiptSystemPrompt,
      'input': [
        {
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': kReceiptUserPrompt},
            {
              'type': 'input_image',
              'image_url': 'data:$mimeType;base64,$base64Image',
            },
          ],
        },
      ],
      'text': {'verbosity': 'low'},
      'tool_choice': 'auto',
      'parallel_tool_calls': false,
    };

    final resp = await _dio.post<ResponseBody>(
      endpoint,
      data: body,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Authorization': 'Bearer ${tokens.access}',
          'chatgpt-account-id': tokens.accountId,
          'originator': CodexOAuth.originator,
          'OpenAI-Beta': 'responses=experimental',
          'Accept': 'text/event-stream',
          'Content-Type': 'application/json',
        },
        validateStatus: (_) => true,
      ),
    );

    final status = resp.statusCode ?? 0;

    if (status == 401 && allowRefresh) {
      try {
        await resp.data!.stream.drain();
      } catch (_) {}
      final fresh = await _oauth.refresh(tokens.refresh);
      await _storage.writeCodexTokens(fresh);
      return _callOnce(
        tokens: fresh,
        model: model,
        base64Image: base64Image,
        mimeType: mimeType,
        allowRefresh: false,
      );
    }

    if (status < 200 || status >= 300) {
      final errorText = await _collectErrorText(resp.data!);
      if (_looksLikeModelRejection(status, errorText)) {
        throw _ModelRejectedException(
          model: model,
          status: status,
          body: errorText,
        );
      }
      throw StateError('Codex HTTP $status: $errorText');
    }

    return _consumeSseToText(resp.data!);
  }

  Future<String> _consumeSseToText(ResponseBody body) async {
    final buf = StringBuffer();
    String pending = '';

    await for (final chunk in body.stream) {
      pending += utf8.decode(chunk, allowMalformed: true);

      while (true) {
        final idx = pending.indexOf('\n\n');
        if (idx < 0) break;
        final eventBlock = pending.substring(0, idx);
        pending = pending.substring(idx + 2);

        final dataLines = <String>[];
        for (final line in const LineSplitter().convert(eventBlock)) {
          if (line.startsWith('data:')) {
            dataLines.add(line.substring(5).trim());
          }
        }
        if (dataLines.isEmpty) continue;
        final data = dataLines.join('\n').trim();
        if (data.isEmpty || data == '[DONE]') continue;

        Map<String, dynamic>? event;
        try {
          event = jsonDecode(data) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        final type = event['type'];

        if (type == 'response.output_text.delta') {
          final delta = event['delta'];
          if (delta is String) buf.write(delta);
        } else if (type == 'response.completed' ||
            type == 'response.done' ||
            type == 'response.incomplete') {
          return buf.toString();
        } else if (type == 'response.failed') {
          final msg = (event['response'] is Map<String, dynamic>)
              ? (event['response'] as Map<String, dynamic>)['error']
              : null;
          throw StateError('Codex response.failed: $msg');
        } else if (type == 'error') {
          throw StateError(
            'Codex error event: ${event['message'] ?? event['code'] ?? event}',
          );
        }
      }
    }
    return buf.toString();
  }

  Future<String> _collectErrorText(ResponseBody body) async {
    final bytes = <int>[];
    await for (final c in body.stream) {
      bytes.addAll(c);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  bool _looksLikeModelRejection(int status, String body) {
    if (status != 400 && status != 404) return false;
    final re = RegExp(
      r'(model.*not.*found|model.*not.*available|unsupported.*model|invalid.*model|no access to model|unknown_model|model_not_found)',
      caseSensitive: false,
    );
    return re.hasMatch(body);
  }

  Map<String, dynamic> _parseJson(String text) {
    final t = text.trim();
    if (t.isEmpty) {
      throw StateError('Codex: 빈 응답(AI가 아무 텍스트도 반환하지 않음).');
    }
    try {
      return jsonDecode(t) as Map<String, dynamic>;
    } catch (_) {}
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', multiLine: true);
    final m = fence.firstMatch(t);
    if (m != null) {
      try {
        return jsonDecode(m.group(1)!) as Map<String, dynamic>;
      } catch (_) {}
    }
    final s = t.indexOf('{');
    final e = t.lastIndexOf('}');
    if (s >= 0 && e > s) {
      try {
        return jsonDecode(t.substring(s, e + 1)) as Map<String, dynamic>;
      } catch (_) {}
    }
    throw StateError('Codex 응답을 JSON으로 파싱 실패. 원문:\n$t');
  }

  String _guessMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }
}

class _ModelRejectedException implements Exception {
  final String model;
  final int status;
  final String body;
  _ModelRejectedException({
    required this.model,
    required this.status,
    required this.body,
  });
  @override
  String toString() =>
      '_ModelRejectedException(model=$model, status=$status): $body';
}
