import 'dart:io';

/// AI 추출 제공자 추상 인터페이스.
/// - Codex(ChatGPT OAuth)
/// - Gemini(API Key)
/// 를 같은 진입점으로 호출할 수 있게 한다.
abstract class AiProvider {
  String get name;
  Future<ReceiptExtraction> extractReceipt(File imageFile);
}

class ReceiptExtraction {
  /// AI가 반환한 JSON 전체 (파싱된 Map).
  final Map<String, dynamic> parsed;

  /// 디버그용: AI가 내보낸 원본 텍스트(스트리밍 누적 포함).
  final String rawText;

  /// 이 추출에 사용된 provider 이름.
  final String providerName;

  /// 요청 시작부터 응답 파싱까지 걸린 밀리초.
  final int durationMs;

  const ReceiptExtraction({
    required this.parsed,
    required this.rawText,
    required this.providerName,
    required this.durationMs,
  });
}
