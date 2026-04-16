import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:image/image.dart' as img;

import 'package:easy_ledger/core/ai/ai_provider.dart';
import 'package:easy_ledger/core/models/transaction.dart' as ledger;
import 'package:easy_ledger/core/sheets/sheets_service.dart';
import 'package:easy_ledger/core/utils/image_utils.dart';
import 'package:easy_ledger/core/utils/statistics_calculator.dart';
import 'package:easy_ledger/features/scan/receipt_draft.dart';
import 'package:easy_ledger/features/scan/receipt_save_builder.dart';

void main() {
  test('ReceiptDraft maps AI JSON into safe defaults', () {
    final draft = ReceiptDraft.fromExtraction(
      const ReceiptExtraction(
        parsed: {
          'storeName': '테스트상점',
          'date': '2026-04-15',
          'total': '12,300원',
          'paymentMethod': 'cash',
          'category': 'food',
          'confidence': 0.93,
          'items': [
            {'name': '아메리카노', 'quantity': 2, 'unitPrice': 4500, 'total': 9000},
          ],
        },
        rawText: '{"storeName":"테스트상점"}',
        providerName: 'test',
        durationMs: 1,
      ),
    );

    expect(draft.storeName, '테스트상점');
    expect(draft.dateText, '2026-04-15');
    expect(draft.total, 12300);
    expect(draft.paymentMethod, 'cash');
    expect(draft.category, 'food');
    expect(draft.items.single.name, '아메리카노');
    expect(draft.confidence, 0.93);
  });

  test('ImageUtils resizes long edge to max 1024 and writes JPEG', () async {
    final dir = await Directory.systemTemp.createTemp('easy_ledger_img_test_');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    final source = File('${dir.path}/source.png');
    final image = img.Image(width: 2000, height: 1000);
    await source.writeAsBytes(img.encodePng(image));

    final resized = await ImageUtils.resizeAndSave(
      source,
      '${dir.path}/out.jpg',
    );
    final decoded = img.decodeJpg(await resized.readAsBytes());

    expect(decoded, isNotNull);
    expect(decoded!.width, 1024);
    expect(decoded.height, 512);
  });

  test('StatisticsCalculator groups category, month, and day totals', () {
    final transactions = [
      _tx('a', DateTime(2026, 4, 15), 1000, 'food'),
      _tx('b', DateTime(2026, 4, 15), 3000, 'food'),
      _tx('c', DateTime(2026, 3, 1), 2000, 'transport'),
    ];

    final categories = StatisticsCalculator.categoryStats(transactions);
    final months = StatisticsCalculator.recentMonthlyStats(
      transactions,
      DateTime(2026, 4, 1),
      months: 2,
    );
    final days = StatisticsCalculator.dailyStats(transactions);

    expect(categories.first.categoryId, 'food');
    expect(categories.first.total, 4000);
    expect(categories.first.ratio, closeTo(4000 / 6000, 0.0001));
    expect(months.map((stat) => stat.total), [2000, 4000]);
    expect(days[DateTime(2026, 4, 15)]?.total, 4000);
  });

  test('buildReceiptSavePayload preserves extracted data for auto save', () {
    final payload = buildReceiptSavePayload(
      extraction: const ReceiptExtraction(
        parsed: {
          'storeName': 'GS25',
          'date': '2026-04-15',
          'time': '18:10',
          'total': 3900,
          'paymentMethod': 'card',
          'category': 'food',
          'confidence': 0.95,
          'items': [
            {'name': '샌드위치', 'quantity': 1, 'unitPrice': 3900, 'total': 3900},
          ],
        },
        rawText: '',
        providerName: 'test',
        durationMs: 1,
      ),
      imagePath: '/tmp/receipt.jpg',
      defaultExpenseType: 'business',
      now: DateTime(2026, 4, 15, 18, 11),
    );

    expect(payload.receipt.imagePath, '/tmp/receipt.jpg');
    expect(payload.receipt.confidence, 0.95);
    expect(payload.transaction.storeName, 'GS25');
    expect(payload.transaction.expenseType, 'business');
    expect(payload.transaction.taxCategory, '복리후생비');
    expect(payload.items.single.name, '샌드위치');
  });

  test('SheetsService uses first Korean sheet title for range', () {
    final spreadsheet = sheets.Spreadsheet(
      sheets: [sheets.Sheet(properties: sheets.SheetProperties(title: '시트1'))],
    );

    final title = SheetsService.firstSheetTitleFromSpreadsheet(spreadsheet);
    final range = SheetsService.rangeForSheetTitle(title, 'A1:M1');

    expect(title, '시트1');
    expect(range, "'시트1'!A1:M1");
  });

  test('SheetsService uses first English sheet title for range', () {
    final spreadsheet = sheets.Spreadsheet(
      sheets: [
        sheets.Sheet(properties: sheets.SheetProperties(title: 'Sheet1')),
      ],
    );

    final title = SheetsService.firstSheetTitleFromSpreadsheet(spreadsheet);
    final range = SheetsService.rangeForSheetTitle(title, 'A:M');

    expect(title, 'Sheet1');
    expect(range, "'Sheet1'!A:M");
  });
}

ledger.Transaction _tx(String id, DateTime date, int total, String category) {
  return ledger.Transaction(
    id: id,
    date: date,
    storeName: id,
    total: total,
    paymentMethod: 'card',
    category: category,
    createdAt: date,
  );
}
