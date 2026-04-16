import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../app.dart';
import '../../core/ai/ai_provider.dart';
import '../../core/models/category.dart' as model;
import '../../core/models/receipt.dart';
import '../../core/models/transaction.dart' as ledger;
import '../../core/models/transaction_item.dart';
import '../../core/utils/format_utils.dart';
import 'receipt_draft.dart';

class ReviewPage extends StatefulWidget {
  final ReceiptExtraction extraction;
  final String imagePath;

  const ReviewPage({
    super.key,
    required this.extraction,
    required this.imagePath,
  });

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final _uuid = const Uuid();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _storeNameController;
  late final TextEditingController _businessNumberController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _totalController;
  late final TextEditingController _taxController;
  late final TextEditingController _memoController;
  late final List<_ItemEditor> _items;

  late String _paymentMethod;
  late String _category;
  String _expenseType = 'personal';
  String? _taxCategory;
  bool _saving = false;
  bool _loadedDefaults = false;

  @override
  void initState() {
    super.initState();
    final draft = ReceiptDraft.fromExtraction(widget.extraction);
    _storeNameController = TextEditingController(text: draft.storeName);
    _businessNumberController = TextEditingController(
      text: draft.businessNumber ?? '',
    );
    _dateController = TextEditingController(text: draft.dateText);
    _timeController = TextEditingController(text: draft.timeText ?? '');
    _totalController = TextEditingController(text: draft.total.toString());
    _taxController = TextEditingController(text: draft.tax?.toString() ?? '');
    _memoController = TextEditingController();
    _items = draft.items.map(_ItemEditor.fromDraft).toList();
    _paymentMethod = draft.paymentMethod;
    _category = draft.category;
    _totalController.addListener(_refreshWarning);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedDefaults) return;
    _loadedDefaults = true;
    _expenseType = AppDeps.of(context).hive.defaultExpenseType;
    if (_expenseType == 'business') {
      _taxCategory ??= '기타';
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _businessNumberController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _totalController.removeListener(_refreshWarning);
    _totalController.dispose();
    _taxController.dispose();
    _memoController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ReceiptDraft.fromExtraction(widget.extraction);
    final categories = AppDeps.of(context).hive.categories();
    return Scaffold(
      appBar: AppBar(title: const Text('리뷰')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ImageHeader(
              imagePath: widget.imagePath,
              confidence: draft.confidence,
              providerName: widget.extraction.providerName,
            ),
            const SizedBox(height: 16),
            if (_showCashWarning) ...[
              const _CashWarning(),
              const SizedBox(height: 16),
            ],
            _Section(
              title: '기본 정보',
              children: [
                TextFormField(
                  controller: _storeNameController,
                  decoration: const InputDecoration(
                    labelText: '상호',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '상호를 입력하세요.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _businessNumberController,
                  decoration: const InputDecoration(
                    labelText: '사업자등록번호',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dateController,
                        decoration: const InputDecoration(
                          labelText: '날짜',
                          hintText: 'YYYY-MM-DD',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            parseCompactDate(value ?? '') == null
                            ? 'YYYY-MM-DD 형식으로 입력하세요.'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _timeController,
                        decoration: const InputDecoration(
                          labelText: '시간',
                          hintText: 'HH:MM',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: '금액과 분류',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _totalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '총액',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final amount = parseWon(value ?? '');
                          return amount == null || amount < 0
                              ? '총액을 입력하세요.'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _taxController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '부가세',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: '결제수단',
                    border: OutlineInputBorder(),
                  ),
                  items: kPaymentMethods
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(paymentMethodLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _paymentMethod = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: '카테고리',
                    border: OutlineInputBorder(),
                  ),
                  items: _categoryMenuItems(categories, _category),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'personal',
                      label: Text('개인지출'),
                      icon: Icon(Icons.person_outline),
                    ),
                    ButtonSegment(
                      value: 'business',
                      label: Text('사업경비'),
                      icon: Icon(Icons.business_center_outlined),
                    ),
                  ],
                  selected: {_expenseType},
                  onSelectionChanged: (set) {
                    setState(() {
                      _expenseType = set.first;
                      if (_expenseType == 'personal') {
                        _taxCategory = null;
                      } else {
                        _taxCategory ??= '기타';
                      }
                    });
                  },
                ),
                if (_expenseType == 'business') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _taxCategory,
                    decoration: const InputDecoration(
                      labelText: '세무 카테고리',
                      border: OutlineInputBorder(),
                    ),
                    items: kTaxCategories
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _taxCategory = value),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: '품목',
              trailing: TextButton.icon(
                onPressed: _saving ? null : _addItem,
                icon: const Icon(Icons.add),
                label: const Text('추가'),
              ),
              children: [
                for (var i = 0; i < _items.length; i++) ...[
                  _ItemEditorTile(
                    index: i,
                    editor: _items[i],
                    onRemove: _items.length <= 1 ? null : () => _removeItem(i),
                  ),
                  if (i != _items.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _memoController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '메모',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? '저장 중...' : '저장'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _showCashWarning {
    final total = parseWon(_totalController.text) ?? 0;
    return _paymentMethod == 'cash' && total > 30000;
  }

  void _refreshWarning() {
    if (mounted) setState(() {});
  }

  void _addItem() {
    setState(() {
      _items.add(
        _ItemEditor.empty(totalHint: parseWon(_totalController.text) ?? 0),
      );
    });
  }

  void _removeItem(int index) {
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final date = parseCompactDate(_dateController.text)!;
    final total = parseWon(_totalController.text)!;
    final itemValues = _readItems();
    if (itemValues == null) return;

    setState(() => _saving = true);
    try {
      final deps = AppDeps.of(context);
      final receiptId = _uuid.v4();
      final transactionId = _uuid.v4();
      final now = DateTime.now();
      final receipt = Receipt(
        id: receiptId,
        imagePath: widget.imagePath,
        scannedAt: now,
        confidence: ReceiptDraft.fromExtraction(
          widget.extraction,
        ).confidence.clamp(0, 1).toDouble(),
        rawJson: ReceiptDraft.fromExtraction(widget.extraction).rawJson,
      );
      final transaction = ledger.Transaction(
        id: transactionId,
        receiptId: receiptId,
        date: date,
        time: _blankToNull(_timeController.text),
        storeName: _storeNameController.text.trim(),
        businessNumber: _blankToNull(_businessNumberController.text),
        total: total,
        tax: parseWon(_taxController.text),
        paymentMethod: _paymentMethod,
        category: _category,
        expenseType: _expenseType,
        taxCategory: _taxCategory,
        memo: _blankToNull(_memoController.text),
        syncedToSheet: false,
        createdAt: now,
      );
      final items = itemValues
          .map(
            (item) => TransactionItem(
              id: _uuid.v4(),
              transactionId: transactionId,
              name: item.name,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              total: item.total,
            ),
          )
          .toList();
      await deps.hive.saveScanResult(
        receipt: receipt,
        transaction: transaction,
        items: items,
      );
      await deps.syncQueue.enqueueIfConfigured(transaction.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  List<ReceiptItemDraft>? _readItems() {
    final values = <ReceiptItemDraft>[];
    for (final editor in _items) {
      final name = editor.name.text.trim();
      final quantity = int.tryParse(editor.quantity.text.trim());
      final unitPrice = parseWon(editor.unitPrice.text);
      final total = parseWon(editor.total.text);
      if (name.isEmpty ||
          quantity == null ||
          unitPrice == null ||
          total == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('품목명, 수량, 단가, 금액을 확인하세요.')),
        );
        return null;
      }
      values.add(
        ReceiptItemDraft(
          name: name,
          quantity: quantity <= 0 ? 1 : quantity,
          unitPrice: unitPrice,
          total: total,
        ),
      );
    }
    return values;
  }

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<DropdownMenuItem<String>> _categoryMenuItems(
    List<model.Category> categories,
    String selected,
  ) {
    final items = [
      for (final category in categories)
        DropdownMenuItem(
          value: category.id,
          child: Text('${category.iconEmoji} ${category.name}'),
        ),
    ];
    if (!categories.any((category) => category.id == selected)) {
      items.add(
        DropdownMenuItem(value: selected, child: Text(categoryLabel(selected))),
      );
    }
    return items;
  }
}

class _ImageHeader extends StatelessWidget {
  final String imagePath;
  final double confidence;
  final String providerName;

  const _ImageHeader({
    required this.imagePath,
    required this.confidence,
    required this.providerName,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (confidence * 100).clamp(0, 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(imagePath),
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(providerName)),
              Text('confidence $percent%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashWarning extends StatelessWidget {
  const _CashWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '현금 결제 3만원 초과 간이영수증은 세무 리스크가 있습니다. '
              '가능하면 카드전표나 세금계산서를 확인하세요.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  const _Section({required this.title, this.trailing, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              // ignore: use_null_aware_elements
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ItemEditorTile extends StatelessWidget {
  final int index;
  final _ItemEditor editor;
  final VoidCallback? onRemove;

  const _ItemEditorTile({
    required this.index,
    required this.editor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '품목 ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                tooltip: '품목 삭제',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          TextFormField(
            controller: editor.name,
            decoration: const InputDecoration(
              labelText: '품목명',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: editor.quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '수량',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: editor.unitPrice,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '단가',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: editor.total,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '금액',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemEditor {
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController total;

  _ItemEditor({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory _ItemEditor.fromDraft(ReceiptItemDraft item) {
    return _ItemEditor(
      name: TextEditingController(text: item.name),
      quantity: TextEditingController(text: item.quantity.toString()),
      unitPrice: TextEditingController(text: item.unitPrice.toString()),
      total: TextEditingController(text: item.total.toString()),
    );
  }

  factory _ItemEditor.empty({required int totalHint}) {
    return _ItemEditor(
      name: TextEditingController(text: '품목'),
      quantity: TextEditingController(text: '1'),
      unitPrice: TextEditingController(text: totalHint.toString()),
      total: TextEditingController(text: totalHint.toString()),
    );
  }

  void dispose() {
    name.dispose();
    quantity.dispose();
    unitPrice.dispose();
    total.dispose();
  }
}
