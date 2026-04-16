import 'package:uuid/uuid.dart';

import '../../core/ai/ai_provider.dart';
import '../../core/models/receipt.dart';
import '../../core/models/transaction.dart' as ledger;
import '../../core/models/transaction_item.dart';
import '../../core/utils/format_utils.dart';
import 'receipt_draft.dart';

class ReceiptSavePayload {
  final Receipt receipt;
  final ledger.Transaction transaction;
  final List<TransactionItem> items;

  const ReceiptSavePayload({
    required this.receipt,
    required this.transaction,
    required this.items,
  });

  String get summary =>
      '${transaction.storeName} ${formatWon(transaction.total)} 저장됨';
}

ReceiptSavePayload buildReceiptSavePayload({
  required ReceiptExtraction extraction,
  required String imagePath,
  required String defaultExpenseType,
  Uuid uuid = const Uuid(),
  DateTime? now,
}) {
  final draft = ReceiptDraft.fromExtraction(extraction);
  final timestamp = now ?? DateTime.now();
  final receiptId = uuid.v4();
  final transactionId = uuid.v4();
  final expenseType = defaultExpenseType == 'business'
      ? 'business'
      : 'personal';
  final storeName = draft.storeName.trim().isEmpty
      ? '이름 없는 영수증'
      : draft.storeName.trim();

  final receipt = Receipt(
    id: receiptId,
    imagePath: imagePath,
    scannedAt: timestamp,
    confidence: draft.confidence.clamp(0, 1).toDouble(),
    rawJson: draft.rawJson,
  );
  final transaction = ledger.Transaction(
    id: transactionId,
    receiptId: receiptId,
    date:
        parseCompactDate(draft.dateText) ??
        DateTime(timestamp.year, timestamp.month, timestamp.day),
    time: _blankToNull(draft.timeText),
    storeName: storeName,
    businessNumber: draft.businessNumber,
    total: draft.total,
    tax: draft.tax,
    paymentMethod: draft.paymentMethod,
    category: draft.category,
    expenseType: expenseType,
    taxCategory: expenseType == 'business'
        ? _taxCategoryFor(draft.category)
        : null,
    memo: null,
    syncedToSheet: false,
    createdAt: timestamp,
  );
  final items = draft.items
      .map(
        (item) => TransactionItem(
          id: uuid.v4(),
          transactionId: transactionId,
          name: item.name,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          total: item.total,
        ),
      )
      .toList();

  return ReceiptSavePayload(
    receipt: receipt,
    transaction: transaction,
    items: items,
  );
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _taxCategoryFor(String category) {
  return switch (category) {
    'food' => '복리후생비',
    'transport' => '여비교통비',
    'living' => '소모품비',
    'education' => '교육훈련비',
    'gift' || 'entertainment' => '접대비',
    'communication' => '통신비',
    _ => null,
  };
}
