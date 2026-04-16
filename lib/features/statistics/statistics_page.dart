import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/models/transaction.dart' as ledger;
import '../../core/storage/hive_storage.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/statistics_calculator.dart';
import '../transactions/transaction_detail_page.dart';
import 'monthly_chart.dart';

/// 통계 탭 — 카테고리 도넛 + 최근 6개월 바 차트.
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  DateTime _month = DateTime.now();
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final hive = AppDeps.of(context).hive;
    return Scaffold(
      appBar: AppBar(title: const Text('통계')),
      body: AnimatedBuilder(
        animation: hive.listenable,
        builder: (context, _) {
          final monthTransactions = hive.transactionsByMonth(
            _month.year,
            _month.month,
          );
          final allTransactions = hive.allTransactions();
          final summary = StatisticsCalculator.summarize(monthTransactions);
          final budgetProgress = StatisticsCalculator.budgetProgress(
            budget: hive.totalBudgetByMonth(_month.year, _month.month),
            spent: summary.expense,
          );
          final categoryStats = StatisticsCalculator.categoryStats(
            monthTransactions,
          );
          final monthlyStats = StatisticsCalculator.recentMonthlyStats(
            allTransactions,
            _month,
          );
          final selectedList = _selectedCategory == null
              ? const <ledger.Transaction>[]
              : StatisticsCalculator.byCategory(
                  monthTransactions,
                  _selectedCategory!,
                );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
            children: [
              _MonthHeader(
                month: _month,
                expense: summary.expense,
                onPrevious: () => _moveMonth(-1),
                onNext: () => _moveMonth(1),
              ),
              const SizedBox(height: 12),
              _BudgetProgressCard(progress: budgetProgress),
              const SizedBox(height: 16),
              _CategoryDonut(
                hive: hive,
                total: summary.expense,
                stats: categoryStats,
                selectedCategory: _selectedCategory,
              ),
              const SizedBox(height: 16),
              _CategoryList(
                hive: hive,
                stats: categoryStats,
                selectedCategory: _selectedCategory,
                onSelected: (category) {
                  setState(() {
                    _selectedCategory = _selectedCategory == category
                        ? null
                        : category;
                  });
                },
              ),
              if (_selectedCategory != null) ...[
                const SizedBox(height: 16),
                _FilteredTransactions(
                  hive: hive,
                  categoryId: _selectedCategory!,
                  transactions: selectedList,
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                '월별 추이',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              MonthlyChart(stats: monthlyStats),
            ],
          );
        },
      ),
    );
  }

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selectedCategory = null;
    });
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final int expense;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.month,
    required this.expense,
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
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  formatMonthTitle(month),
                  style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  '지출 ${formatWon(expense)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '다음 달',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _BudgetProgressCard extends StatelessWidget {
  final BudgetProgress progress;

  const _BudgetProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    if (!progress.hasBudget) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: const Row(
          children: [
            Icon(Icons.savings_outlined),
            SizedBox(width: 10),
            Expanded(child: Text('이번 달 예산이 설정되지 않았습니다.')),
          ],
        ),
      );
    }

    final ratio = progress.ratio;
    final clamped = ratio.clamp(0.0, 1.0);
    final color = ratio < 0.8
        ? Colors.green
        : ratio <= 1.0
        ? Colors.orange
        : Colors.red;

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
              Icon(
                progress.isOverBudget
                    ? Icons.warning_amber_rounded
                    : Icons.savings_outlined,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  progress.isOverBudget
                      ? '예산을 초과했습니다'
                      : '예산 진행률 ${(ratio * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${(ratio * 100).round()}%',
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 10,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('예산 ${formatWon(progress.budget)}'),
              Text('지출 ${formatWon(progress.spent)}'),
              Text(
                progress.isOverBudget
                    ? '초과 ${formatWon(progress.spent - progress.budget)} ⚠️'
                    : '잔액 ${formatWon(progress.remaining)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryDonut extends StatelessWidget {
  final HiveStorage hive;
  final int total;
  final List<CategoryStat> stats;
  final String? selectedCategory;

  const _CategoryDonut({
    required this.hive,
    required this.total,
    required this.stats,
    required this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return _EmptyStatsCard(total: total);
    }

    return Container(
      height: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              centerSpaceRadius: 68,
              sectionsSpace: 3,
              pieTouchData: PieTouchData(enabled: false),
              sections: [
                for (final stat in stats)
                  PieChartSectionData(
                    value: stat.total.toDouble(),
                    color: Color(hive.categoryColorHex(stat.categoryId)),
                    radius: selectedCategory == stat.categoryId ? 72 : 62,
                    title: '${(stat.ratio * 100).round()}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('총 지출', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
              Text(
                formatWon(total),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyStatsCard extends StatelessWidget {
  final int total;

  const _EmptyStatsCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Center(
        child: Text(
          total == 0 ? '이번 달 거래가 없습니다.' : '분류할 거래가 없습니다.',
          style: const TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final HiveStorage hive;
  final List<CategoryStat> stats;
  final String? selectedCategory;
  final ValueChanged<String> onSelected;

  const _CategoryList({
    required this.hive,
    required this.stats,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final stat in stats)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            color: selectedCategory == stat.categoryId
                ? Color(
                    hive.categoryColorHex(stat.categoryId),
                  ).withValues(alpha: 0.12)
                : null,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(
                  hive.categoryColorHex(stat.categoryId),
                ).withValues(alpha: 0.16),
                child: Text(hive.categoryIcon(stat.categoryId)),
              ),
              title: Text(hive.categoryName(stat.categoryId)),
              subtitle: Text('${stat.count}건'),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(stat.ratio * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(formatWon(stat.total)),
                ],
              ),
              onTap: () => onSelected(stat.categoryId),
            ),
          ),
      ],
    );
  }
}

class _FilteredTransactions extends StatelessWidget {
  final HiveStorage hive;
  final String categoryId;
  final List<ledger.Transaction> transactions;

  const _FilteredTransactions({
    required this.hive,
    required this.categoryId,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${hive.categoryName(categoryId)} 거래',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (transactions.isEmpty)
            const Text('거래가 없습니다.')
          else
            for (final tx in transactions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tx.storeName),
                subtitle: Text(formatCompactDate(tx.date)),
                trailing: Text(
                  formatWon(tx.total),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TransactionDetailPage(transaction: tx),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
