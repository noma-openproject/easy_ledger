import 'package:hive/hive.dart';

part 'sync_item.g.dart';

@HiveType(typeId: 4)
class SyncItem extends HiveObject {
  static const operationUpsert = 'upsert';
  static const operationDelete = 'delete';

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String transactionId;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final int retryCount;

  @HiveField(4)
  final String? lastError;

  @HiveField(5)
  final String operation;

  @HiveField(6)
  final int? preferredSheetRowIndex;

  @HiveField(7)
  final String? fallbackDateText;

  @HiveField(8)
  final String? fallbackTime;

  @HiveField(9)
  final String? fallbackStoreName;

  @HiveField(10)
  final int? fallbackTotal;

  SyncItem({
    required this.id,
    required this.transactionId,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
    this.operation = operationUpsert,
    this.preferredSheetRowIndex,
    this.fallbackDateText,
    this.fallbackTime,
    this.fallbackStoreName,
    this.fallbackTotal,
  });

  SyncItem copyWith({
    String? id,
    String? transactionId,
    DateTime? createdAt,
    int? retryCount,
    Object? lastError = _sentinel,
    String? operation,
    Object? preferredSheetRowIndex = _sentinel,
    Object? fallbackDateText = _sentinel,
    Object? fallbackTime = _sentinel,
    Object? fallbackStoreName = _sentinel,
    Object? fallbackTotal = _sentinel,
  }) {
    return SyncItem(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: identical(lastError, _sentinel)
          ? this.lastError
          : lastError as String?,
      operation: operation ?? this.operation,
      preferredSheetRowIndex: identical(preferredSheetRowIndex, _sentinel)
          ? this.preferredSheetRowIndex
          : preferredSheetRowIndex as int?,
      fallbackDateText: identical(fallbackDateText, _sentinel)
          ? this.fallbackDateText
          : fallbackDateText as String?,
      fallbackTime: identical(fallbackTime, _sentinel)
          ? this.fallbackTime
          : fallbackTime as String?,
      fallbackStoreName: identical(fallbackStoreName, _sentinel)
          ? this.fallbackStoreName
          : fallbackStoreName as String?,
      fallbackTotal: identical(fallbackTotal, _sentinel)
          ? this.fallbackTotal
          : fallbackTotal as int?,
    );
  }
}

const Object _sentinel = Object();
