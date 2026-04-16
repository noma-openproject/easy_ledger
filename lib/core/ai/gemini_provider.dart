import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../storage/secure_storage.dart';
import 'ai_provider.dart';
import 'receipt_prompt.dart';

/// Google AI Studio (generativelanguage.googleapis.com) 기반 영수증 추출.
/// 사용자가 직접 입력한 API Key를 사용하는 fallback 경로.
class GeminiProvider implements AiProvider {
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Phase 0 기본 모델. 실패 시 호출 측이 다른 모델로 교체 가능.
  static const defaultModel = 'gemini-2.0-flash';

  final Dio _dio;
  final SecureStorage _storage;
  final String model;

  GeminiProvider({
    required Dio dio,
    required SecureStorage storage,
    this.model = defaultModel,
  }) : _dio = dio,
       _storage = storage;

  @override
  String get name => 'gemini/$model';

  @override
  Future<ReceiptExtraction> extractReceipt(File imageFile) async {
    final stopwatch = Stopwatch()..start();

    final apiKey = await _storage.readGeminiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('Gemini API Key가 저장되어 있지 않습니다. 설정에서 먼저 저장하세요.');
    }

    final bytes = await imageFile.readAsBytes();
    final b64 = base64Encode(bytes);
    final mime = _guessMime(imageFile.path);

    final url = '$_baseUrl/$model:generateContent';
    final resp = await _dio.post<Map<String, dynamic>>(
      url,
      queryParameters: {'key': apiKey},
      data: {
        'contents': [
          {
            'parts': [
              {'text': '$kReceiptSystemPrompt\n\n$kReceiptUserPrompt'},
              {
                'inline_data': {'mime_type': mime, 'data': b64},
              },
            ],
          },
        ],
        'generationConfig': {
          'response_mime_type': 'application/json',
          'temperature': 0.0,
        },
      },
      options: Options(
        responseType: ResponseType.json,
        headers: {'Content-Type': 'application/json'},
        validateStatus: (_) => true,
      ),
    );

    final status = resp.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw StateError('Gemini HTTP $status: ${jsonEncode(resp.data)}');
    }

    final data = resp.data!;
    final text = _extractText(data);
    final parsed = _parseJson(text);
    stopwatch.stop();

    return ReceiptExtraction(
      parsed: parsed,
      rawText: text,
      providerName: name,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  String _extractText(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List;
      if (candidates.isEmpty) {
        throw StateError('Gemini: candidates가 비어있음.\n원본: ${jsonEncode(data)}');
      }
      final first = candidates.first as Map<String, dynamic>;
      final content = first['content'] as Map<String, dynamic>;
      final parts = content['parts'] as List;
      if (parts.isEmpty) {
        throw StateError('Gemini: parts가 비어있음.\n원본: ${jsonEncode(data)}');
      }
      final first0 = parts.first as Map<String, dynamic>;
      final text = first0['text'];
      if (text is! String) {
        throw StateError('Gemini: parts[0].text 누락.\n원본: ${jsonEncode(data)}');
      }
      return text;
    } catch (e) {
      if (e is StateError) rethrow;
      throw StateError('Gemini 응답 구조 파싱 실패: $e\n원본: ${jsonEncode(data)}');
    }
  }

  Map<String, dynamic> _parseJson(String text) {
    final t = text.trim();
    if (t.isEmpty) {
      throw StateError('Gemini: 빈 응답(parts[0].text가 빈 문자열).');
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
    throw StateError('Gemini 응답을 JSON으로 파싱 실패. 원문:\n$t');
  }

  String _guessMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }
}
