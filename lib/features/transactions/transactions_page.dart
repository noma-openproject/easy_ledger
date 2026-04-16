import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/models/transaction.dart' as ledger;
import '../../core/storage/hive_storage.dart';
import '../../core/utils/format_utils.dart';
import '../manual_input/manual_input_page.dart';
import 'filter_sheet.dart';
import 'search_bar.dart';
import 'transaction_detail_page.dart';

/// 내역 탭 — 월 이동 + 검색 + 필터.
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  DateTime _month = DateTime.now();
  String _searchQuery = '';
  TransactionFilters _filters = const TransactionFilters();

  bool get _isSearchActive => _searchQuery.isNotEmpty;
  bool get _locksMonthNavigation => _isSearchActive || _filters.hasDateOverride;

  @override
  Widget build(BuildContext context) {
    final hive = AppDeps.of(context).hive;
    return Scaffold(
      appBar: AppBar(
        title: const Text('내역'),
        actions: [
          IconButton(
            tooltip: '수동 입력',
            onPressed: () => _openManualInput(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: hive.listenable,
        builder: (context, _) {
          final allTransactions = hive.allTransactions();
          if (allTransactions.isEmpty) {
            return const _EmptyState();
          }

          final filteredTransactions = _visibleTransactions(hive);
          final displayedExpense = filteredTransactions.fold<int>(
            0,
            (sum, tx) => sum + tx.total,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TransactionSearchBar(
                      initialValue: _searchQuery,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => _openFilterSheet(context),
                    icon: const Icon(Icons.tune),
                    label: const Text('필터'),
                  ),
                ],
              ),
              if (_hasActiveConditionChips(hive)) ...[
                const SizedBox(height: 12),
                _FilterChips(chips: _buildFilterChips(hive)),
              ],
              const SizedBox(height: 12),
              _MonthSummary(
                title: _summaryTitle,
                income: 0,
                expense: displayedExpense,
                navigationEnabled: !_locksMonthNavigation,
                onPrevious: () => _moveMonth(-1),
                onNext: () => _moveMonth(1),
              ),
              const SizedBox(height: 16),
              if (filteredTransactions.isEmpty)
                _buildEmptyState()
              else
                ..._groupedRows(context, filteredTransactions),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openManualInput(context),
        icon: const Icon(Icons.edit_note),
        label: const Text('수동 입력'),
      ),
    );
  }

  String get _summaryTitle {
    if (_isSearchActive) return '전체 거래 검색';
    return switch (_filters.period) {
      TransactionPeriodPreset.none => formatMonthTitle(_month),
      TransactionPeriodPreset.currentMonth => '이번 달',
      TransactionPeriodPreset.lastMonth => '지난 달',
      TransactionPeriodPreset.currentYear => '올해',
      TransactionPeriodPreset.custom => _customRangeTitle,
    };
  }

  String get _customRangeTitle {
    final range = _filters.customRange;
    if (range == null) return '직접 선택';
    return '${formatCompactDate(range.start)} ~ ${formatCompactDate(range.end)}';
  }

  List<ledger.Transaction> _visibleTransactions(HiveStorage hive) {
    final base = _baseTransactions(hive);
    final query = _searchQuery.toLowerCase();
    final list = base.where((tx) {
      if (_filters.period != TransactionPeriodPreset.none &&
          !_matchesPeriod(tx.date)) {
        return false;
      }
      if (_filters.categories.isNotEmpty &&
          !_filters.categories.contains(tx.category)) {
        return false;
      }
      if (_filters.expenseType != 'all' &&
          tx.expenseType != _filters.expenseType) {
        return false;
      }
      if (_filters.minAmount != null && tx.total < _filters.minAmount!) {
        return false;
      }
      if (_filters.maxAmount != null && tx.total > _filters.maxAmount!) {
        return false;
      }
      if (_filters.paymentMethods.isNotEmpty &&
          !_filters.paymentMethods.contains(tx.paymentMethod)) {
        return false;
      }
      if (query.isEmpty) return true;

      final store = tx.storeName.toLowerCase();
      final memo = (tx.memo ?? '').toLowerCase();
      if (store.contains(query) || memo.contains(query)) {
        return true;
      }
      return hive
          .itemsByTransaction(tx.id)
          .any((item) => item.name.toLowerCase().contains(query));
    }).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<ledger.Transaction> _baseTransactions(HiveStorage hive) {
    if (_isSearchActive || _filters.hasDateOverride) {
      return hive.allTransactions();
    }
    return hive.transactionsByMonth(_month.year, _month.month);
  }

  bool _matchesPeriod(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    switch (_filters.period) {
      case TransactionPeriodPreset.none:
        return true;
      case TransactionPeriodPreset.currentMonth:
        final now = DateTime.now();
        return day.year == now.year && day.month == now.month;
      case TransactionPeriodPreset.lastMonth:
        final lastMonth = DateTime(
          DateTime.now().year,
          DateTime.now().month - 1,
        );
        return day.year == lastMonth.year && day.month == lastMonth.month;
      case TransactionPeriodPreset.currentYear:
        return day.year == DateTime.now().year;
      case TransactionPeriodPreset.custom:
        final range = _filters.customRange;
        if (range == null) return true;
        final start = DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        );
        final end = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
        ).add(const Duration(days: 1));
        return !day.isBefore(start) && day.isBefore(end);
    }
  }

  Widget _buildEmptyState() {
    if (!_isSearchActive && _filters.isEmpty) {
      return _MonthEmptyState(
        onScan: () => RootShellScope.maybeOf(context)?.selectTab(0),
        onPreviousMonth: () => _moveMonth(-1),
      );
    }
    return _FilteredEmptyState(
      onClearSearch: _isSearchActive
          ? () => setState(() => _searchQuery = '')
          : null,
      onClearFilters: !_filters.isEmpty
          ? () => setState(() => _filters = const TransactionFilters())
          : null,
    );
  }

  bool _hasActiveConditionChips(HiveStorage hive) {
    return _buildFilterChips(hive).isNotEmpty;
  }

  List<_FilterChipData> _buildFilterChips(HiveStorage hive) {
    final chips = <_FilterChipData>[];
    if (_filters.categories.isNotEmpty) {
      chips.add(
        _FilterChipData(
          label: _filters.categories.map(hive.categoryName).join(', '),
          onDeleted: () {
            setState(() => _filters = _filters.copyWith(categories: {}));
          },
        ),
      );
    }
    if (_filters.period != TransactionPeriodPreset.none) {
      chips.add(
        _FilterChipData(
          label: _summaryTitle,
          onDeleted: () {
            setState(
              () => _filters = _filters.copyWith(
                period: TransactionPeriodPreset.none,
                customRange: null,
              ),
            );
          },
        ),
      );
    }
    if (_filters.expenseType != 'all') {
      chips.add(
        _FilterChipData(
          label: expenseTypeLabel(_filters.expenseType),
          onDeleted: () {
            setState(() => _filters = _filters.copyWith(expenseType: 'all'));
          },
        ),
      );
    }
    if (_filters.minAmount != null || _filters.maxAmount != null) {
      chips.add(
        _FilterChipData(
          label: [
            if (_filters.minAmount != null)
              '${formatWon(_filters.minAmount!)} 이상',
            if (_filters.maxAmount != null)
              '${formatWon(_filters.maxAmount!)} 이하',
          ].join(' · '),
          onDeleted: () {
            setState(
              () => _filters = _filters.copyWith(
                minAmount: null,
                maxAmount: null,
              ),
            );
          },
        ),
      );
    }
    if (_filters.paymentMethods.isNotEmpty) {
      chips.add(
        _FilterChipData(
          label: _filters.paymentMethods.map(paymentMethodLabel).join(', '),
          onDeleted: () {
            setState(() => _filters = _filters.copyWith(paymentMethods: {}));
          },
        ),
      );
    }
    return chips;
  }

  void _moveMonth(int delta) {
    if (_locksMonthNavigation) return;
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  List<Widget> _groupedRows(
    BuildContext context,
    List<ledger.Transaction> transactions,
  ) {
    final rows = <Widget>[];
    DateTime? currentDay;
    for (final tx in transactions) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (currentDay == null || currentDay != day) {
        currentDay = day;
        rows.add(_DateHeader(date: day));
      }
      rows.add(
        _TransactionTile(hive: AppDeps.of(context).hive, transaction: tx),
      );
    }
    return rows;
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final hive = AppDeps.of(context).hive;
    final next = await showTransactionFilterSheet(
      context,
      initialFilters: _filters,
      categories: hive.categories(),
    );
    if (next == null || !mounted) return;
    setState(() => _filters = next);
  }

  Future<void> _openManualInput(BuildContext context) async {
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ManualInputPage()));
  }
}

class _MonthSummary extends StatelessWidget {
  final String title;
  final int income;
  final int expense;
  final bool navigationEnabled;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthSummary({
    required this.title,
    required this.income,
    required this.expense,
    required this.navigationEnabled,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '이전 달',
            onPressed: navigationEnabled ? onPrevious : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      '수입 ${formatWon(income)}',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '지출 ${formatWon(expense)}',
                      style: TextStyle(
                        color: Colors.red[800],
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '다음 달',
            onPressed: navigationEnabled ? onNext : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final List<_FilterChipData> chips;

  const _FilterChips({required this.chips});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final chip in chips)
          InputChip(label: Text(chip.label), onDeleted: chip.onDeleted),
      ],
    );
  }
}

class _FilterChipData {
  final String label;
  final VoidCallback onDeleted;

  const _FilterChipData({required this.label, required this.onDeleted});
}

class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        formatKoreanDate(date),
        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[700]),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final HiveStorage hive;
  final ledger.Transaction transaction;
  const _TransactionTile({required this.hive, required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(
            hive.categoryColorHex(transaction.category),
          ).withValues(alpha: 0.16),
          child: Text(hive.categoryIcon(transaction.category)),
        ),
        title: Text(
          transaction.storeName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            hive.categoryName(transaction.category),
            paymentMethodLabel(transaction.paymentMethod),
            if (transaction.time != null) transaction.time!,
            transaction.syncedToSheet ? '시트 완료' : '시트 대기',
          ].join(' · '),
        ),
        trailing: Text(
          formatWon(transaction.total),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionDetailPage(transaction: transaction),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 96,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              '아직 거래 없음',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '스캔 탭에서 영수증을 추가하세요.\n직접 입력하려면 아래 버튼을 누르세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const ManualInputPage()),
              ),
              icon: const Icon(Icons.edit_note),
              label: const Text('수동 입력'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthEmptyState extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onPreviousMonth;

  const _MonthEmptyState({required this.onScan, required this.onPreviousMonth});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '이 달에 거래가 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '다른 달로 이동하거나 새 영수증을 추가해 보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('스캔하러 가기'),
              ),
              OutlinedButton.icon(
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left),
                label: const Text('이전 달 보기'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  final VoidCallback? onClearSearch;
  final VoidCallback? onClearFilters;

  const _FilteredEmptyState({
    required this.onClearSearch,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_outlined, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '조건에 맞는 거래가 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '검색어나 필터를 조정해 보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (onClearSearch != null)
                OutlinedButton.icon(
                  onPressed: onClearSearch,
                  icon: const Icon(Icons.close),
                  label: const Text('검색 지우기'),
                ),
              if (onClearFilters != null)
                FilledButton.tonalIcon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('필터 초기화'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
