import 'package:hive/hive.dart';

part 'receipt.g.dart';

/// 스캔한 영수증의 원본 메타데이터.
/// 아키텍처 문서 §10 스키마 (typeId=0).
///
/// Transaction 과 1:1 관계: Transaction.receiptId 가 이 id 를 참조.
/// - imagePath: 앱 내부 스토리지에 복사된 리사이즈된 JPEG 경로
/// - rawJson: AI 가 반환한 원본 JSON (디버깅/재해석용)
@HiveType(typeId: 0)
class Receipt extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String imagePath;

  @HiveField(2)
  final DateTime scannedAt;

  @HiveField(3)
  final double confidence;

  @HiveField(4)
  final String rawJson;

  Receipt({
    required this.id,
    required this.imagePath,
    required this.scannedAt,
    required this.confidence,
    required this.rawJson,
  });
}
