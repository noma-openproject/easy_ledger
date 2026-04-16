import 'package:hive/hive.dart';

part 'transaction.g.dart';

/// 영수증 1장 또는 수동 입력 1건에 해당하는 거래 레코드.
/// 아키텍처 문서 §10 스키마 (typeId=1).
///
/// receiptId 가 null 이면 수동 입력. non-null 이면 Receipt 박스에서 원본 이미지 조회.
/// 품목 상세는 별도 TransactionItem 박스(typeId=2)에서 transactionId 로 연결.
@HiveType(typeId: 1)
class Transaction extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? receiptId;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String? time; // "HH:MM" 24h

  @HiveField(4)
  final String storeName;

  @HiveField(5)
  final String? businessNumber; // 사업자등록번호 "000-00-00000"

  @HiveField(6)
  final int total; // 원화 정수

  @HiveField(7)
  final int? tax;

  @HiveField(8)
  final String paymentMethod; // card | cash | transfer | other

  @HiveField(9)
  final String category;
  // food | transport | living | medical | culture | education |
  // gift | housing | communication | entertainment | etc

  @HiveField(10)
  final String expenseType; // personal | business

  @HiveField(11)
  final String? taxCategory; // 사업경비 세무 카테고리

  @HiveField(12)
  final String? memo;

  @HiveField(13)
  final bool syncedToSheet;

  @HiveField(14)
  final DateTime createdAt;

  @HiveField(15)
  final int? sheetRowIndex;

  @HiveField(16)
  final DateTime? sheetSyncedAt;

  Transaction({
    required this.id,
    this.receiptId,
    required this.date,
    this.time,
    required this.storeName,
    this.businessNumber,
    required this.total,
    this.tax,
    required this.paymentMethod,
    required this.category,
    this.expenseType = 'personal',
    this.taxCategory,
    this.memo,
    this.syncedToSheet = false,
    required this.createdAt,
    this.sheetRowIndex,
    this.sheetSyncedAt,
  });

  Transaction copyWith({
    String? id,
    Object? receiptId = _sentinel,
    DateTime? date,
    Object? time = _sentinel,
    String? storeName,
    Object? businessNumber = _sentinel,
    int? total,
    Object? tax = _sentinel,
    String? paymentMethod,
    String? category,
    String? expenseType,
    Object? taxCategory = _sentinel,
    Object? memo = _sentinel,
    bool? syncedToSheet,
    DateTime? createdAt,
    Object? sheetRowIndex = _sentinel,
    Object? sheetSyncedAt = _sentinel,
  }) {
    return Transaction(
      id: id ?? this.id,
      receiptId: identical(receiptId, _sentinel)
          ? this.receiptId
          : receiptId as String?,
      date: date ?? this.date,
      time: identical(time, _sentinel) ? this.time : time as String?,
      storeName: storeName ?? this.storeName,
      businessNumber: identical(businessNumber, _sentinel)
          ? this.businessNumber
          : businessNumber as String?,
      total: total ?? this.total,
      tax: identical(tax, _sentinel) ? this.tax : tax as int?,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      category: category ?? this.category,
      expenseType: expenseType ?? this.expenseType,
      taxCategory: identical(taxCategory, _sentinel)
          ? this.taxCategory
          : taxCategory as String?,
      memo: identical(memo, _sentinel) ? this.memo : memo as String?,
      syncedToSheet: syncedToSheet ?? this.syncedToSheet,
      createdAt: createdAt ?? this.createdAt,
      sheetRowIndex: identical(sheetRowIndex, _sentinel)
          ? this.sheetRowIndex
          : sheetRowIndex as int?,
      sheetSyncedAt: identical(sheetSyncedAt, _sentinel)
          ? this.sheetSyncedAt
          : sheetSyncedAt as DateTime?,
    );
  }

  /// 3만원 초과 간이영수증 (현금 결제) 여부.
  /// 아키텍처 §11 세무 기능: 3만원 초과 간이영수증은 가산세 2% 위험.
  bool get isCashOver30k => paymentMethod == 'cash' && total > 30000;
}

const Object _sentinel = Object();
