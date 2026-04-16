import 'package:hive/hive.dart';

part 'transaction_item.g.dart';

/// 거래 1건의 품목별 세부 라인.
/// 아키텍처 문서 §10 스키마 (typeId=2).
///
/// transactionId 로 부모 Transaction 과 N:1 관계.
/// 품목이 1개뿐인 단순 영수증도 1개의 row 로 저장 (편의상).
@HiveType(typeId: 2)
class TransactionItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String transactionId;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final int quantity;

  @HiveField(4)
  final int unitPrice;

  @HiveField(5)
  final int total;

  TransactionItem({
    required this.id,
    required this.transactionId,
    required this.name,
    this.quantity = 1,
    required this.unitPrice,
    required this.total,
  });

  TransactionItem copyWith({
    String? id,
    String? transactionId,
    String? name,
    int? quantity,
    int? unitPrice,
    int? total,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? this.total,
    );
  }
}
