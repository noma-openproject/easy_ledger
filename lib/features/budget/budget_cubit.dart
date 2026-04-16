import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/budget.dart';
import '../../core/storage/hive_storage.dart';
import '../../core/utils/format_utils.dart';

class BudgetState {
  final DateTime month;
  final String? message;
  final String? errorText;

  const BudgetState({required this.month, this.message, this.errorText});

  factory BudgetState.initial() => BudgetState(month: DateTime.now());

  BudgetState copyWith({
    DateTime? month,
    Object? message = _sentinel,
    Object? errorText = _sentinel,
  }) {
    return BudgetState(
      month: month ?? this.month,
      message: identical(message, _sentinel)
          ? this.message
          : message as String?,
      errorText: identical(errorText, _sentinel)
          ? this.errorText
          : errorText as String?,
    );
  }
}

const Object _sentinel = Object();

class BudgetCubit extends Cubit<BudgetState> {
  final HiveStorage _hive;

  BudgetCubit(this._hive) : super(BudgetState.initial());

  void moveMonth(int delta) {
    emit(
      state.copyWith(
        month: DateTime(state.month.year, state.month.month + delta),
        message: null,
        errorText: null,
      ),
    );
  }

  Future<void> saveBudget(String categoryId, String input) async {
    final trimmed = input.trim();
    try {
      if (trimmed.isEmpty) {
        await _hive.deleteBudget(
          HiveStorage.budgetId(categoryId, state.month.year, state.month.month),
        );
        emit(state.copyWith(message: '예산을 삭제했습니다.', errorText: null));
        return;
      }

      final amount = parseWon(trimmed);
      if (amount == null || amount < 0) {
        emit(state.copyWith(errorText: '예산 금액을 확인하세요.', message: null));
        return;
      }

      final budget = Budget(
        id: HiveStorage.budgetId(
          categoryId,
          state.month.year,
          state.month.month,
        ),
        categoryId: categoryId,
        monthlyAmount: amount,
        year: state.month.year,
        month: state.month.month,
      );
      await _hive.upsertBudget(budget);
      emit(
        state.copyWith(
          message: '${_hive.categoryName(categoryId)} 예산을 저장했습니다.',
          errorText: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(errorText: '예산 저장 실패: $e', message: null));
    }
  }

  void clearMessage() {
    emit(state.copyWith(message: null, errorText: null));
  }
}
