import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app.dart';
import '../../core/models/transaction.dart' as ledger;
import '../../core/storage/hive_storage.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/statistics_calculator.dart';
import '../transactions/transaction_detail_page.dart';

/// 달력 탭 — 저장된 Hive 거래를 날짜별로 집계해서 보여준다.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final hive = AppDeps.of(context).hive;
    return Scaffold(
      appBar: AppBar(title: const Text('달력')),
      body: AnimatedBuilder(
        animation: hive.listenable,
        builder: (context, _) {
          final monthTransactions = hive.transactionsByMonth(
            _focusedDay.year,
            _focusedDay.month,
          );
          final summary = StatisticsCalculator.summarize(monthTransactions);
          final dailyStats = StatisticsCalculator.dailyStats(monthTransactions);
          final selectedTransactions = hive.getByDate(_selectedDay);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
            children: [
              _MonthSummary(
                month: _focusedDay,
                income: summary.income,
                expense: summary.expense,
              ),
              const SizedBox(height: 12),
              _CalendarCard(
                hive: hive,
                focusedDay: _focusedDay,
                selectedDay: _selectedDay,
                dailyStats: dailyStats,
                events: monthTransactions,
                onPageChanged: (day) {
                  setState(() {
                    _focusedDay = day;
                    _selectedDay = DateTime(day.year, day.month, 1);
                  });
                },
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
              ),
              const SizedBox(height: 18),
              _SelectedDayList(
                hive: hive,
                date: _selectedDay,
                transactions: selectedTransactions,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthSummary extends StatelessWidget {
  final DateTime month;
  final int income;
  final int expense;

  const _MonthSummary({
    required this.month,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatMonthTitle(month),
                  style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
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
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  final HiveStorage hive;
  final DateTime focusedDay;
  final DateTime selectedDay;
  final Map<DateTime, DailyStat> dailyStats;
  final List<ledger.Transaction> events;
  final ValueChanged<DateTime> onPageChanged;
  final void Function(DateTime selected, DateTime focused) onDaySelected;

  const _CalendarCard({
    required this.hive,
    required this.focusedDay,
    required this.selectedDay,
    required this.dailyStats,
    required this.events,
    required this.onPageChanged,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: TableCalendar<ledger.Transaction>(
        locale: 'ko_KR',
        firstDay: DateTime(2020),
        lastDay: DateTime(2035, 12, 31),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) => isSameDay(selectedDay, day),
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: '월'},
        startingDayOfWeek: StartingDayOfWeek.monday,
        rowHeight: 68,
        eventLoader: (day) => StatisticsCalculator.byDate(events, day),
        onDaySelected: onDaySelected,
        onPageChanged: onPageChanged,
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          leftChevronIcon: Icon(Icons.chevron_left),
          rightChevronIcon: Icon(Icons.chevron_right),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          selectedDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
        ),
        calendarBuilders: CalendarBuilders<ledger.Transaction>(
          markerBuilder: (context, day, dayEvents) {
            final stat = dailyStats[DateTime(day.year, day.month, day.day)];
            if (stat == null || stat.total <= 0) return const SizedBox.shrink();
            final category = dayEvents.isEmpty
                ? 'etc'
                : dayEvents.first.category;
            return Positioned(
              bottom: 4,
              left: 2,
              right: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Color(hive.categoryColorHex(category)),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatWon(stat.total),
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SelectedDayList extends StatelessWidget {
  final HiveStorage hive;
  final DateTime date;
  final List<ledger.Transaction> transactions;

  const _SelectedDayList({
    required this.hive,
    required this.date,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Text('${formatKoreanDate(date)} 거래가 없습니다.'),
      );
    }

    final total = transactions.fold<int>(0, (sum, tx) => sum + tx.total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '${formatKoreanDate(date)} · ${formatWon(total)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        for (final tx in transactions)
          _CalendarTransactionTile(hive: hive, tx: tx),
      ],
    );
  }
}

class _CalendarTransactionTile extends StatelessWidget {
  final HiveStorage hive;
  final ledger.Transaction tx;

  const _CalendarTransactionTile({required this.hive, required this.tx});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(
            hive.categoryColorHex(tx.category),
          ).withValues(alpha: 0.16),
          child: Text(hive.categoryIcon(tx.category)),
        ),
        title: Text(tx.storeName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            hive.categoryName(tx.category),
            paymentMethodLabel(tx.paymentMethod),
            if (tx.time != null) tx.time!,
          ].join(' · '),
        ),
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
    );
  }
}
