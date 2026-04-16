import '../models/transaction.dart' as ledger;

class CategoryStat {
  final String categoryId;
  final int total;
  final int count;
  final double ratio;

  const CategoryStat({
    required this.categoryId,
    required this.total,
    required this.count,
    required this.ratio,
  });
}

class MonthlyStat {
  final int year;
  final int month;
  final int total;
  final int count;

  const MonthlyStat({
    required this.year,
    required this.month,
    required this.total,
    required this.count,
  });

  DateTime get date => DateTime(year, month);
}

class DailyStat {
  final DateTime date;
  final int total;
  final int count;

  const DailyStat({
    required this.date,
    required this.total,
    required this.count,
  });
}

class StatisticsSummary {
  final int income;
  final int expense;
  final int count;

  const StatisticsSummary({
    required this.income,
    required this.expense,
    required this.count,
  });
}

class BudgetProgress {
  final int budget;
  final int spent;
  final double ratio;

  const BudgetProgress({
    required this.budget,
    required this.spent,
    required this.ratio,
  });

  int get remaining => budget - spent;
  bool get hasBudget => budget > 0;
  bool get isOverBudget => hasBudget && spent > budget;
}

class StatisticsCalculator {
  const StatisticsCalculator._();

  static StatisticsSummary summarize(List<ledger.Transaction> transactions) {
    final expense = transactions.fold<int>(0, (sum, tx) => sum + tx.total);
    return StatisticsSummary(
      income: 0,
      expense: expense,
      count: transactions.length,
    );
  }

  static BudgetProgress budgetProgress({
    required int budget,
    required int spent,
  }) {
    final ratio = budget <= 0 ? 0.0 : spent / budget;
    return BudgetProgress(budget: budget, spent: spent, ratio: ratio);
  }

  static List<CategoryStat> categoryStats(
    List<ledger.Transaction> transactions,
  ) {
    final totals = <String, int>{};
    final counts = <String, int>{};
    for (final tx in transactions) {
      totals.update(
        tx.category,
        (value) => value + tx.total,
        ifAbsent: () => tx.total,
      );
      counts.update(tx.category, (value) => value + 1, ifAbsent: () => 1);
    }

    final grandTotal = totals.values.fold<int>(0, (sum, value) => sum + value);
    final rows = totals.entries
        .map(
          (entry) => CategoryStat(
            categoryId: entry.key,
            total: entry.value,
            count: counts[entry.key] ?? 0,
            ratio: grandTotal == 0 ? 0 : entry.value / grandTotal,
          ),
        )
        .toList();
    rows.sort((a, b) => b.total.compareTo(a.total));
    return rows;
  }

  static List<MonthlyStat> recentMonthlyStats(
    List<ledger.Transaction> transactions,
    DateTime anchor, {
    int months = 6,
  }) {
    final safeMonths = months < 1 ? 1 : months;
    final monthStarts = List<DateTime>.generate(safeMonths, (index) {
      final offset = safeMonths - 1 - index;
      return DateTime(anchor.year, anchor.month - offset);
    });
    final totals = <String, int>{};
    final counts = <String, int>{};
    for (final tx in transactions) {
      final key = _monthKey(tx.date.year, tx.date.month);
      totals.update(key, (value) => value + tx.total, ifAbsent: () => tx.total);
      counts.update(key, (value) => value + 1, ifAbsent: () => 1);
    }
    return [
      for (final month in monthStarts)
        MonthlyStat(
          year: month.year,
          month: month.month,
          total: totals[_monthKey(month.year, month.month)] ?? 0,
          count: counts[_monthKey(month.year, month.month)] ?? 0,
        ),
    ];
  }

  static Map<DateTime, DailyStat> dailyStats(
    List<ledger.Transaction> transactions,
  ) {
    final totals = <DateTime, int>{};
    final counts = <DateTime, int>{};
    for (final tx in transactions) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      totals.update(day, (value) => value + tx.total, ifAbsent: () => tx.total);
      counts.update(day, (value) => value + 1, ifAbsent: () => 1);
    }
    return {
      for (final entry in totals.entries)
        entry.key: DailyStat(
          date: entry.key,
          total: entry.value,
          count: counts[entry.key] ?? 0,
        ),
    };
  }

  static List<ledger.Transaction> byCategory(
    List<ledger.Transaction> transactions,
    String categoryId,
  ) {
    final list = transactions.where((tx) => tx.category == categoryId).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static List<ledger.Transaction> byDate(
    List<ledger.Transaction> transactions,
    DateTime date,
  ) {
    final day = DateTime(date.year, date.month, date.day);
    final list = transactions
        .where(
          (tx) => DateTime(tx.date.year, tx.date.month, tx.date.day) == day,
        )
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static String _monthKey(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';
}
