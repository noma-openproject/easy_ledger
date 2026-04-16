import 'package:flutter/material.dart';

import '../../core/models/category.dart' as model;
import '../../core/utils/format_utils.dart';

enum TransactionPeriodPreset {
  none,
  currentMonth,
  lastMonth,
  currentYear,
  custom,
}

class TransactionFilters {
  final TransactionPeriodPreset period;
  final DateTimeRange? customRange;
  final Set<String> categories;
  final String expenseType;
  final int? minAmount;
  final int? maxAmount;
  final Set<String> paymentMethods;

  const TransactionFilters({
    this.period = TransactionPeriodPreset.none,
    this.customRange,
    this.categories = const {},
    this.expenseType = 'all',
    this.minAmount,
    this.maxAmount,
    this.paymentMethods = const {},
  });

  bool get hasDateOverride => period != TransactionPeriodPreset.none;

  bool get isEmpty =>
      period == TransactionPeriodPreset.none &&
      categories.isEmpty &&
      expenseType == 'all' &&
      minAmount == null &&
      maxAmount == null &&
      paymentMethods.isEmpty;

  TransactionFilters copyWith({
    TransactionPeriodPreset? period,
    Object? customRange = _sentinel,
    Set<String>? categories,
    String? expenseType,
    Object? minAmount = _sentinel,
    Object? maxAmount = _sentinel,
    Set<String>? paymentMethods,
  }) {
    return TransactionFilters(
      period: period ?? this.period,
      customRange: identical(customRange, _sentinel)
          ? this.customRange
          : customRange as DateTimeRange?,
      categories: categories ?? this.categories,
      expenseType: expenseType ?? this.expenseType,
      minAmount: identical(minAmount, _sentinel)
          ? this.minAmount
          : minAmount as int?,
      maxAmount: identical(maxAmount, _sentinel)
          ? this.maxAmount
          : maxAmount as int?,
      paymentMethods: paymentMethods ?? this.paymentMethods,
    );
  }
}

const Object _sentinel = Object();

Future<TransactionFilters?> showTransactionFilterSheet(
  BuildContext context, {
  required TransactionFilters initialFilters,
  required List<model.Category> categories,
}) {
  final minController = TextEditingController(
    text: initialFilters.minAmount?.toString() ?? '',
  );
  final maxController = TextEditingController(
    text: initialFilters.maxAmount?.toString() ?? '',
  );
  var filters = initialFilters;

  return showModalBottomSheet<TransactionFilters>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> pickCustomDate(bool isStart) async {
            final initialDate = isStart
                ? filters.customRange?.start ?? DateTime.now()
                : filters.customRange?.end ?? DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035, 12, 31),
            );
            if (picked == null) return;
            setSheetState(() {
              final current = filters.customRange;
              final start = isStart
                  ? picked
                  : (current?.start ?? picked);
              final end = isStart
                  ? (current?.end ?? picked)
                  : picked;
              filters = filters.copyWith(
                customRange: _normalizedRange(start, end),
              );
            });
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '필터',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '기간',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preset in TransactionPeriodPreset.values)
                          ChoiceChip(
                            label: Text(_periodLabel(preset)),
                            selected: filters.period == preset,
                            onSelected: (_) {
                              setSheetState(() {
                                filters = filters.copyWith(
                                  period: preset,
                                  customRange:
                                      preset == TransactionPeriodPreset.custom
                                      ? filters.customRange
                                      : null,
                                );
                              });
                            },
                          ),
                      ],
                    ),
                    if (filters.period == TransactionPeriodPreset.custom) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickCustomDate(true),
                              icon: const Icon(Icons.event_outlined),
                              label: Text(
                                filters.customRange == null
                                    ? '시작일'
                                    : formatCompactDate(
                                        filters.customRange!.start,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickCustomDate(false),
                              icon: const Icon(Icons.event_available_outlined),
                              label: Text(
                                filters.customRange == null
                                    ? '종료일'
                                    : formatCompactDate(
                                        filters.customRange!.end,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      '카테고리',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    for (final category in categories)
                      CheckboxListTile(
                        value: filters.categories.contains(category.id),
                        contentPadding: EdgeInsets.zero,
                        title: Text('${category.iconEmoji} ${category.name}'),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (checked) {
                          final next = {...filters.categories};
                          if (checked == true) {
                            next.add(category.id);
                          } else {
                            next.remove(category.id);
                          }
                          setSheetState(() {
                            filters = filters.copyWith(categories: next);
                          });
                        },
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      '경비 구분',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    RadioGroup<String>(
                      groupValue: filters.expenseType,
                      onChanged: (value) => setSheetState(
                        () => filters = filters.copyWith(
                          expenseType: value ?? 'all',
                        ),
                      ),
                      child: Column(
                        children: const [
                          RadioListTile<String>(
                            value: 'all',
                            contentPadding: EdgeInsets.zero,
                            title: Text('전체'),
                          ),
                          RadioListTile<String>(
                            value: 'personal',
                            contentPadding: EdgeInsets.zero,
                            title: Text('개인지출'),
                          ),
                          RadioListTile<String>(
                            value: 'business',
                            contentPadding: EdgeInsets.zero,
                            title: Text('사업경비'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '금액 범위',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '최소 금액',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: maxController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '최대 금액',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '결제수단',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    for (final method in kPaymentMethods)
                      CheckboxListTile(
                        value: filters.paymentMethods.contains(method),
                        contentPadding: EdgeInsets.zero,
                        title: Text(paymentMethodLabel(method)),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (checked) {
                          final next = {...filters.paymentMethods};
                          if (checked == true) {
                            next.add(method);
                          } else {
                            next.remove(method);
                          }
                          setSheetState(() {
                            filters = filters.copyWith(paymentMethods: next);
                          });
                        },
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            minController.clear();
                            maxController.clear();
                            Navigator.of(
                              context,
                            ).pop(const TransactionFilters());
                          },
                          child: const Text('초기화'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(context).pop(
                              filters.copyWith(
                                minAmount: _parseInt(minController.text),
                                maxAmount: _parseInt(maxController.text),
                              ),
                            );
                          },
                          child: const Text('적용'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

String _periodLabel(TransactionPeriodPreset preset) {
  return switch (preset) {
    TransactionPeriodPreset.none => '기본 월',
    TransactionPeriodPreset.currentMonth => '이번 달',
    TransactionPeriodPreset.lastMonth => '지난 달',
    TransactionPeriodPreset.currentYear => '올해',
    TransactionPeriodPreset.custom => '직접 선택',
  };
}

int? _parseInt(String input) {
  final digits = input.trim().replaceAll(',', '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

DateTimeRange _normalizedRange(DateTime start, DateTime end) {
  if (start.isAfter(end)) {
    return DateTimeRange(start: end, end: start);
  }
  return DateTimeRange(start: start, end: end);
}
