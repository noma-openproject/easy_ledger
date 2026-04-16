import 'dart:convert';

import '../../core/ai/ai_provider.dart';
import '../../core/utils/format_utils.dart';

class ReceiptDraft {
  final String storeName;
  final String? businessNumber;
  final String dateText;
  final String? timeText;
  final int total;
  final int? tax;
  final String paymentMethod;
  final String category;
  final double confidence;
  final String rawJson;
  final List<ReceiptItemDraft> items;

  const ReceiptDraft({
    required this.storeName,
    required this.businessNumber,
    required this.dateText,
    required this.timeText,
    required this.total,
    required this.tax,
    required this.paymentMethod,
    required this.category,
    required this.confidence,
    required this.rawJson,
    required this.items,
  });

  factory ReceiptDraft.fromExtraction(ReceiptExtraction extraction) {
    final json = extraction.parsed;
    final items = _readItems(json['items']);
    final itemTotal = items.fold<int>(0, (sum, item) => sum + item.total);
    final total = _readInt(json['total']) ?? itemTotal;
    return ReceiptDraft(
      storeName: _readString(json['storeName']) ?? '',
      businessNumber: _readString(json['businessNumber']),
      dateText: _readString(json['date']) ?? formatCompactDate(DateTime.now()),
      timeText: _readString(json['time']),
      total: total,
      tax: _readInt(json['tax']),
      paymentMethod: _allowed(
        _readString(json['paymentMethod']),
        kPaymentMethods,
        fallback: 'card',
      ),
      category: _allowed(
        _readString(json['category']),
        kCategories,
        fallback: 'etc',
      ),
      confidence: _readDouble(json['confidence']) ?? 0,
      rawJson: extraction.rawText.trim().isNotEmpty
          ? extraction.rawText
          : const JsonEncoder.withIndent('  ').convert(json),
      items: items.isEmpty
          ? [
              ReceiptItemDraft(
                name: '영수증 합계',
                quantity: 1,
                unitPrice: total,
                total: total,
              ),
            ]
          : items,
    );
  }
}

class ReceiptItemDraft {
  final String name;
  final int quantity;
  final int unitPrice;
  final int total;

  const ReceiptItemDraft({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
}

List<ReceiptItemDraft> _readItems(Object? value) {
  if (value is! List) return const [];
  final items = <ReceiptItemDraft>[];
  for (final raw in value) {
    if (raw is! Map) continue;
    final name = _readString(raw['name']);
    final total = _readInt(raw['total']);
    if (name == null || name.isEmpty || total == null) continue;
    final quantity = _readInt(raw['quantity']) ?? 1;
    items.add(
      ReceiptItemDraft(
        name: name,
        quantity: quantity <= 0 ? 1 : quantity,
        unitPrice: _readInt(raw['unitPrice']) ?? total,
        total: total,
      ),
    );
  }
  return items;
}

String _allowed(
  String? value,
  List<String> allowed, {
  required String fallback,
}) {
  if (value != null && allowed.contains(value)) return value;
  return fallback;
}

String? _readString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty || text == 'null' ? null : text;
}

int? _readInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  return parseWon(value.toString());
}

double? _readDouble(Object? value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
