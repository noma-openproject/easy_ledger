import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction.dart' as ledger;
import '../storage/hive_storage.dart';
import '../utils/format_utils.dart';
import '../utils/statistics_calculator.dart';

class SimpleLedgerExporter {
  final HiveStorage _hive;

  SimpleLedgerExporter(this._hive);

  Future<File> exportToXlsx({required int year, int? month}) async {
    final transactions = _transactionsFor(year: year, month: month);
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.rename(defaultSheet, '간편장부');
    }

    _buildSimpleLedgerSheet(excel['간편장부'], transactions);
    _buildDetailSheet(excel['전체 거래 상세'], transactions);
    _buildCategorySummarySheet(excel['카테고리별 요약'], transactions);

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('엑셀 파일 생성에 실패했습니다.');
    }
    final documents = await getApplicationDocumentsDirectory();
    final suffix = month == null
        ? year.toString()
        : '$year-${month.toString().padLeft(2, '0')}';
    final file = File(p.join(documents.path, '간편장부_$suffix.xlsx'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> exportAndShare({required int year, int? month}) async {
    final file = await exportToXlsx(year: year, month: month);
    await Share.shareXFiles([XFile(file.path)], text: 'Easy Ledger 간편장부 내보내기');
    return file;
  }

  List<ledger.Transaction> _transactionsFor({required int year, int? month}) {
    final transactions = month == null
        ? _hive.allTransactions().where((tx) => tx.date.year == year).toList()
        : _hive.transactionsByMonth(year, month);
    transactions.sort((a, b) => a.date.compareTo(b.date));
    return transactions;
  }

  void _buildSimpleLedgerSheet(
    Sheet sheet,
    List<ledger.Transaction> transactions,
  ) {
    _appendTextRow(sheet, const [
      '날짜',
      '거래처',
      '적요',
      '수입금액',
      '비용금액',
      '고정자산증감',
      '비고',
    ]);
    final business = transactions
        .where((tx) => tx.expenseType == 'business')
        .toList();
    int annualExpense = 0;
    int annualIncome = 0;
    int? currentMonth;
    int monthlyExpense = 0;
    int monthlyIncome = 0;

    void appendSubtotal() {
      if (currentMonth == null) return;
      _appendRow(sheet, [
        '',
        '',
        '$currentMonth월 소계',
        monthlyIncome,
        monthlyExpense,
        0,
        '',
      ]);
    }

    for (final tx in business) {
      if (currentMonth != null && currentMonth != tx.date.month) {
        appendSubtotal();
        monthlyExpense = 0;
        monthlyIncome = 0;
      }
      currentMonth = tx.date.month;
      final income = 0;
      final expense = tx.total;
      monthlyIncome += income;
      monthlyExpense += expense;
      annualIncome += income;
      annualExpense += expense;
      _appendRow(sheet, [
        formatCompactDate(tx.date),
        tx.storeName,
        _summaryFor(tx),
        income,
        expense,
        0,
        tx.memo ?? '',
      ]);
    }
    appendSubtotal();
    _appendRow(sheet, ['', '', '연간 합계', annualIncome, annualExpense, 0, '']);
  }

  void _buildDetailSheet(Sheet sheet, List<ledger.Transaction> transactions) {
    _appendTextRow(sheet, const [
      '날짜',
      '시간',
      '상호',
      '사업자번호',
      '공급가액',
      '부가세',
      '합계',
      '결제수단',
      '카테고리',
      '세무분류',
      '경비구분',
      '메모',
    ]);
    for (final tx in transactions) {
      final tax = tx.tax ?? 0;
      _appendRow(sheet, [
        formatCompactDate(tx.date),
        tx.time ?? '',
        tx.storeName,
        tx.businessNumber ?? '',
        tx.total - tax,
        tax,
        tx.total,
        paymentMethodLabel(tx.paymentMethod),
        _hive.categoryName(tx.category),
        tx.taxCategory ?? '',
        expenseTypeLabel(tx.expenseType),
        tx.memo ?? '',
      ]);
    }
  }

  void _buildCategorySummarySheet(
    Sheet sheet,
    List<ledger.Transaction> transactions,
  ) {
    _appendTextRow(sheet, const ['카테고리', '건수', '합계', '비율']);
    for (final stat in StatisticsCalculator.categoryStats(transactions)) {
      _appendRow(sheet, [
        _hive.categoryName(stat.categoryId),
        stat.count,
        stat.total,
        '${(stat.ratio * 100).toStringAsFixed(1)}%',
      ]);
    }
  }

  String _summaryFor(ledger.Transaction tx) {
    final taxPrefix = tx.taxCategory == null ? '' : '${tx.taxCategory} - ';
    return '$taxPrefix${_hive.categoryName(tx.category)} - ${tx.storeName}';
  }

  void _appendTextRow(Sheet sheet, List<String> values) {
    sheet.appendRow(values.map(TextCellValue.new).toList());
  }

  void _appendRow(Sheet sheet, List<Object?> values) {
    sheet.appendRow(values.map(_cellValue).toList());
  }

  CellValue _cellValue(Object? value) {
    return switch (value) {
      int v => IntCellValue(v),
      double v => DoubleCellValue(v),
      null => TextCellValue(''),
      _ => TextCellValue(value.toString()),
    };
  }
}
