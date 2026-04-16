import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app.dart';
import '../../core/utils/format_utils.dart';
import 'budget_cubit.dart';
import 'budget_widget.dart';

class BudgetPage extends StatelessWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    final hive = AppDeps.of(context).hive;
    return BlocProvider(
      create: (_) => BudgetCubit(hive),
      child: const _BudgetView(),
    );
  }
}

class _BudgetView extends StatelessWidget {
  const _BudgetView();

  @override
  Widget build(BuildContext context) {
    final hive = AppDeps.of(context).hive;
    return BlocConsumer<BudgetCubit, BudgetState>(
      listenWhen: (previous, current) =>
          previous.message != current.message ||
          previous.errorText != current.errorText,
      listener: (context, state) {
        final message = state.errorText ?? state.message;
        if (message == null) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        context.read<BudgetCubit>().clearMessage();
      },
      builder: (context, state) {
        final budgets = hive.budgetAmountMapForMonth(
          state.month.year,
          state.month.month,
        );
        final totalBudget = hive.totalBudgetByMonth(
          state.month.year,
          state.month.month,
        );
        final categories = hive.categories();

        return Scaffold(
          appBar: AppBar(title: const Text('예산 관리')),
          body: AnimatedBuilder(
            animation: hive.listenable,
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _BudgetHeader(
                    month: state.month,
                    totalBudget: totalBudget,
                    onPrevious: () => context.read<BudgetCubit>().moveMonth(-1),
                    onNext: () => context.read<BudgetCubit>().moveMonth(1),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '카테고리별 월 예산',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '비워두면 해당 카테고리 예산이 없는 것으로 처리합니다.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  for (final category in categories) ...[
                    BudgetCategoryField(
                      category: category,
                      amount: budgets[category.id],
                      onSave: (value) => context.read<BudgetCubit>().saveBudget(
                        category.id,
                        value,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _BudgetHeader extends StatelessWidget {
  final DateTime month;
  final int totalBudget;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _BudgetHeader({
    required this.month,
    required this.totalBudget,
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
                  '총 예산 ${formatWon(totalBudget)}',
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
