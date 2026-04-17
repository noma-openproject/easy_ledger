import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;

import '../models/transaction.dart' as ledger;
import '../utils/format_utils.dart';

class SheetsService {
  static const transactionIdColumn = 'N';
  static const statusColumn = 'O';
  static const sheetEndColumn = 'O';
  static const transactionIdColumnIndex = 13;
  static const normalStatus = '정상';
  static const deletedStatus = '삭제됨';

  static const headers = [
    '날짜',
    '시간',
    '상호명',
    '사업자번호',
    '공급가액',
    '부가세',
    '합계',
    '결제수단',
    '카테고리',
    '세무분류',
    '경비구분',
    '담당자',
    '메모',
    '거래ID',
    '상태',
  ];

  final sheets.SheetsApi _api;

  SheetsService(auth.AuthClient client) : _api = sheets.SheetsApi(client);

  Future<void> ensureHeader(String spreadsheetId) async {
    final headerRange = await _firstSheetRange(
      spreadsheetId,
      'A1:${sheetEndColumn}1',
    );
    final response = await _api.spreadsheets.values.get(
      spreadsheetId,
      headerRange,
    );
    final firstRow = response.values?.firstOrNull;
    final normalized = [
      for (final cell in firstRow ?? const <Object?>[]) cell?.toString() ?? '',
    ];
    if (listEquals(normalized, headers)) return;

    await _api.spreadsheets.values.update(
      sheets.ValueRange(values: [headers]),
      spreadsheetId,
      headerRange,
      valueInputOption: 'USER_ENTERED',
    );
  }

  Future<SheetUpsertResult> upsertTransaction(
    String spreadsheetId,
    ledger.Transaction tx, {
    int? preferredRowIndex,
  }) async {
    final title = await _firstSheetTitle(spreadsheetId);
    final rowIndex = await _resolveRowIndex(
      spreadsheetId,
      title,
      tx.id,
      preferredRowIndex,
    );
    if (rowIndex != null) {
      await updateTransactionRow(spreadsheetId, title, rowIndex, tx);
      return SheetUpsertResult(rowIndex: rowIndex, mode: SheetWriteMode.update);
    }
    final appendedRow = await appendTransactionRow(spreadsheetId, title, tx);
    return SheetUpsertResult(
      rowIndex: appendedRow,
      mode: SheetWriteMode.append,
    );
  }

  Future<void> updateTransactionRow(
    String spreadsheetId,
    String sheetTitle,
    int rowIndex,
    ledger.Transaction tx,
  ) async {
    final range = rangeForSheetTitle(
      sheetTitle,
      'A$rowIndex:$sheetEndColumn$rowIndex',
    );
    await _api.spreadsheets.values.update(
      sheets.ValueRange(values: [_rowFor(tx)]),
      spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
    );
  }

  Future<int> appendTransactionRow(
    String spreadsheetId,
    String sheetTitle,
    ledger.Transaction tx,
  ) async {
    final appendRange = rangeForSheetTitle(sheetTitle, 'A:$sheetEndColumn');
    final response = await _api.spreadsheets.values.append(
      sheets.ValueRange(values: [_rowFor(tx)]),
      spreadsheetId,
      appendRange,
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
    );
    final updatedRange = response.updates?.updatedRange;
    final rowIndex = updatedRange == null
        ? null
        : rowIndexFromRange(updatedRange);
    if (rowIndex == null) {
      throw StateError('시트 append 결과에서 행 번호를 읽을 수 없습니다.');
    }
    return rowIndex;
  }

  Future<bool> markTransactionDeletedById(
    String spreadsheetId,
    String transactionId, {
    int? preferredRowIndex,
    String? fallbackDateText,
    String? fallbackTime,
    String? fallbackStoreName,
    int? fallbackTotal,
  }) async {
    final title = await _firstSheetTitle(spreadsheetId);
    final rowIndex =
        await _resolveRowIndex(
          spreadsheetId,
          title,
          transactionId,
          preferredRowIndex,
        ) ??
        await _findLegacyRowBySnapshot(
          spreadsheetId,
          title,
          dateText: fallbackDateText,
          timeText: fallbackTime,
          storeName: fallbackStoreName,
          total: fallbackTotal,
        );
    if (rowIndex == null) return false;
    final range = rangeForSheetTitle(
      title,
      'A$rowIndex:$sheetEndColumn$rowIndex',
    );
    final existingRow = await _api.spreadsheets.values.get(
      spreadsheetId,
      range,
    );
    final values = [
      for (final cell in existingRow.values?.firstOrNull ?? const <Object?>[])
        cell?.toString() ?? '',
    ];
    final row = _rowWithStatus(values, deletedStatus);
    await _api.spreadsheets.values.update(
      sheets.ValueRange(values: [row]),
      spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
    );
    return true;
  }

  Future<String> _firstSheetRange(String spreadsheetId, String cells) async {
    final title = await _firstSheetTitle(spreadsheetId);
    return rangeForSheetTitle(title, cells);
  }

  Future<String> _firstSheetTitle(String spreadsheetId) async {
    final spreadsheet = await _api.spreadsheets.get(spreadsheetId);
    return firstSheetTitleFromSpreadsheet(spreadsheet);
  }

  Future<int?> _resolveRowIndex(
    String spreadsheetId,
    String sheetTitle,
    String transactionId,
    int? preferredRowIndex,
  ) async {
    if (preferredRowIndex != null) {
      final currentId = await _transactionIdAtRow(
        spreadsheetId,
        sheetTitle,
        preferredRowIndex,
      );
      if (currentId == transactionId) {
        return preferredRowIndex;
      }
    }
    return _findRowByTransactionId(spreadsheetId, sheetTitle, transactionId);
  }

  Future<String?> _transactionIdAtRow(
    String spreadsheetId,
    String sheetTitle,
    int rowIndex,
  ) async {
    final range = rangeForSheetTitle(
      sheetTitle,
      '$transactionIdColumn$rowIndex:$transactionIdColumn$rowIndex',
    );
    final response = await _api.spreadsheets.values.get(spreadsheetId, range);
    final row = response.values?.firstOrNull;
    final value = row?.firstOrNull?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<int?> _findRowByTransactionId(
    String spreadsheetId,
    String sheetTitle,
    String transactionId,
  ) async {
    final range = rangeForSheetTitle(sheetTitle, 'A2:$sheetEndColumn');
    final response = await _api.spreadsheets.values.get(spreadsheetId, range);
    final rows = response.values ?? const <List<Object?>>[];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      if (row.length > transactionIdColumnIndex &&
          row[transactionIdColumnIndex].toString().trim() == transactionId) {
        return index + 2;
      }
    }
    return null;
  }

  Future<int?> _findLegacyRowBySnapshot(
    String spreadsheetId,
    String sheetTitle, {
    String? dateText,
    String? timeText,
    String? storeName,
    int? total,
  }) async {
    if (dateText == null || storeName == null || total == null) return null;
    final normalizedTime = timeText?.trim() ?? '';
    final normalizedStore = storeName.trim();
    final range = rangeForSheetTitle(sheetTitle, 'A2:$sheetEndColumn');
    final response = await _api.spreadsheets.values.get(spreadsheetId, range);
    final rows = response.values ?? const <List<Object?>>[];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      if (row.length < 7) continue;
      final rowDate = row[0].toString().trim();
      final rowTime = row.length > 1 ? row[1].toString().trim() : '';
      final rowStore = row.length > 2 ? row[2].toString().trim() : '';
      final rowTotal = row.length > 6
          ? int.tryParse(row[6].toString().replaceAll(',', '').trim())
          : null;
      if (rowDate == dateText &&
          rowTime == normalizedTime &&
          rowStore == normalizedStore &&
          rowTotal == total) {
        return index + 2;
      }
    }
    return null;
  }

  @visibleForTesting
  static String firstSheetTitleFromSpreadsheet(sheets.Spreadsheet spreadsheet) {
    final sheetList = spreadsheet.sheets;
    if (sheetList == null || sheetList.isEmpty) {
      throw StateError('스프레드시트에 시트가 없습니다.');
    }
    final title = sheetList.first.properties?.title?.trim();
    if (title == null || title.isEmpty) {
      throw StateError('첫 번째 시트 이름을 읽을 수 없습니다.');
    }
    return title;
  }

  @visibleForTesting
  static String rangeForSheetTitle(String title, String cells) {
    final escaped = title.replaceAll("'", "''");
    return "'$escaped'!$cells";
  }

  @visibleForTesting
  static int? rowIndexFromRange(String range) {
    final match = RegExp(r'![A-Z]+(\d+)(?::[A-Z]+(\d+))?$').firstMatch(range);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  List<Object?> _rowFor(ledger.Transaction tx, {String status = normalStatus}) {
    final tax = tx.tax ?? 0;
    final supply = tx.total - tax;
    return [
      formatCompactDate(tx.date),
      tx.time ?? '',
      tx.storeName,
      tx.businessNumber ?? '',
      supply < 0 ? 0 : supply,
      tax,
      tx.total,
      paymentMethodLabel(tx.paymentMethod),
      categoryLabel(tx.category),
      tx.taxCategory ?? '',
      expenseTypeLabel(tx.expenseType),
      '',
      tx.memo ?? '',
      tx.id,
      status,
    ];
  }

  List<Object?> _rowWithStatus(List<Object?> values, String status) {
    final row = <Object?>[
      for (var index = 0; index < headers.length; index++)
        index < values.length ? values[index] : '',
    ];
    row[headers.length - 1] = status;
    return row;
  }
}

enum SheetWriteMode { append, update }

class SheetUpsertResult {
  final int rowIndex;
  final SheetWriteMode mode;

  const SheetUpsertResult({required this.rowIndex, required this.mode});
}
