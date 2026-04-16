import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../app.dart';
import '../../core/models/category.dart' as model;
import '../../core/models/transaction.dart' as ledger;
import '../../core/utils/format_utils.dart';

class ManualInputPage extends StatefulWidget {
  final ledger.Transaction? initialTransaction;

  const ManualInputPage({super.key, this.initialTransaction});

  @override
  State<ManualInputPage> createState() => _ManualInputPageState();
}

class _ManualInputPageState extends State<ManualInputPage> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late final TextEditingController _dateController;
  final _timeController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _totalController = TextEditingController();
  final _taxController = TextEditingController();
  final _memoController = TextEditingController();
  String _paymentMethod = 'card';
  String _category = 'etc';
  String _expenseType = 'personal';
  String? _taxCategory;
  bool _saving = false;
  bool _loadedDefaults = false;
  late final bool _wasSyncedToSheet;
  int? _existingSheetRowIndex;
  DateTime? _existingSheetSyncedAt;

  @override
  void initState() {
    super.initState();
    final tx = widget.initialTransaction;
    _wasSyncedToSheet = tx?.syncedToSheet ?? false;
    _existingSheetRowIndex = tx?.sheetRowIndex;
    _existingSheetSyncedAt = tx?.sheetSyncedAt;
    _dateController = TextEditingController(
      text: formatCompactDate(tx?.date ?? DateTime.now()),
    );
    if (tx != null) {
      _timeController.text = tx.time ?? '';
      _storeNameController.text = tx.storeName;
      _totalController.text = tx.total.toString();
      _taxController.text = tx.tax?.toString() ?? '';
      _memoController.text = tx.memo ?? '';
      _paymentMethod = tx.paymentMethod;
      _category = tx.category;
      _expenseType = tx.expenseType;
      _taxCategory = tx.taxCategory;
    }
    _totalController.addListener(_refreshWarning);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedDefaults || widget.initialTransaction != null) return;
    _loadedDefaults = true;
    _expenseType = AppDeps.of(context).hive.defaultExpenseType;
    if (_expenseType == 'business') {
      _taxCategory ??= '기타';
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _storeNameController.dispose();
    _totalController.removeListener(_refreshWarning);
    _totalController.dispose();
    _taxController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = AppDeps.of(context).hive.categories();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialTransaction == null ? '수동 입력' : '거래 수정'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_showCashWarning) ...[
              const _CashWarning(),
              const SizedBox(height: 16),
            ],
            _Section(
              title: '거래 정보',
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      var shouldEnqueue = widget.initialTransaction == null;
      var syncedToSheet = false;
      var sheetRowIndex = _existingSheetRowIndex;
      var sheetSyncedAt = _existingSheetSyncedAt;
      if (widget.initialTransaction != null) {
        final syncMode = await _resolveEditSyncMode();
        if (!mounted) return;
        switch (syncMode) {
          case _EditSyncMode.cancel:
            setState(() => _saving = false);
            return;
          case _EditSyncMode.keepLocalOnly:
            shouldEnqueue = false;
            syncedToSheet = _wasSyncedToSheet;
            break;
          case _EditSyncMode.upsert:
            shouldEnqueue = true;
            syncedToSheet = false;
            if (_wasSyncedToSheet && _existingSheetRowIndex == null) {
              sheetRowIndex = null;
              sheetSyncedAt = null;
            }
            break;
        }
      }

      final transaction = ledger.Transaction(
        id: widget.initialTransaction?.id ?? _uuid.v4(),
        receiptId: widget.initialTransaction?.receiptId,
        date: parseCompactDate(_dateController.text)!,
        time: _blankToNull(_timeController.text),
        storeName: _storeNameController.text.trim(),
        businessNumber: widget.initialTransaction?.businessNumber,
        total: parseWon(_totalController.text)!,
        tax: parseWon(_taxController.text),
        paymentMethod: _paymentMethod,
        category: _category,
        expenseType: _expenseType,
        taxCategory: _taxCategory,
        memo: _blankToNull(_memoController.text),
        syncedToSheet: syncedToSheet,
        createdAt: widget.initialTransaction?.createdAt ?? DateTime.now(),
        sheetRowIndex: sheetRowIndex,
        sheetSyncedAt: sheetSyncedAt,
      );
      final deps = AppDeps.of(context);
      final hive = deps.hive;
      if (widget.initialTransaction == null) {
        await hive.addTransaction(transaction);
      } else {
        await hive.updateTransaction(transaction);
      }
      if (shouldEnqueue) {
        await deps.syncQueue.enqueueIfConfigured(transaction.id);
      }
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

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool get _needsLegacySheetRelink =>
      widget.initialTransaction != null &&
      _wasSyncedToSheet &&
      _existingSheetRowIndex == null;

  Future<_EditSyncMode> _resolveEditSyncMode() async {
    if (widget.initialTransaction == null) {
      return _EditSyncMode.upsert;
    }
    if (!_needsLegacySheetRelink) {
      return _EditSyncMode.upsert;
    }
    final decision = await showDialog<_EditSyncMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('시트 재연결 필요'),
        content: const Text(
          '이 거래는 예전 버전에서 동기화되어 시트 행 위치 정보가 없습니다.\n'
          '새 행으로 다시 동기화하면 이후부터는 같은 행을 업데이트할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_EditSyncMode.cancel),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_EditSyncMode.keepLocalOnly),
            child: const Text('로컬만 저장'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_EditSyncMode.upsert),
            child: const Text('새 행으로 재연결'),
          ),
        ],
      ),
    );
    return decision ?? _EditSyncMode.cancel;
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

enum _EditSyncMode { cancel, keepLocalOnly, upsert }

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

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
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...children,
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
          Expanded(child: Text('현금 결제 3만원 초과 간이영수증은 세무 리스크가 있습니다.')),
        ],
      ),
    );
  }
}
