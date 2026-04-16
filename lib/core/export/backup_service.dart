import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/category.dart' as model;
import '../models/receipt.dart';
import '../models/transaction.dart' as ledger;
import '../models/transaction_item.dart';
import '../storage/hive_storage.dart';

enum BackupRestoreMode { overwrite, merge }

class BackupResult {
  final int restoredTransactions;
  final int restoredImages;
  final int skippedTransactions;

  const BackupResult({
    required this.restoredTransactions,
    required this.restoredImages,
    required this.skippedTransactions,
  });
}

class BackupService {
  final HiveStorage _hive;

  BackupService(this._hive);

  Future<File> createBackup() async {
    final archive = Archive();
    final receipts = _hive.allReceipts();
    final data = {
      'version': 2,
      'createdAt': DateTime.now().toIso8601String(),
      'receipts': receipts.map(_receiptToJson).toList(),
      'transactions': _hive.allTransactions().map(_transactionToJson).toList(),
      'transaction_items': _hive.allItems().map(_itemToJson).toList(),
      'categories': _hive.categories().map(_categoryToJson).toList(),
      'settings': _hive.settingsSnapshot(),
    };
    archive.addFile(
      ArchiveFile.string(
        'data.json',
        const JsonEncoder.withIndent('  ').convert(data),
      ),
    );

    for (final receipt in receipts) {
      final file = File(receipt.imagePath);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      archive.addFile(
        ArchiveFile(
          'images/${p.basename(receipt.imagePath)}',
          bytes.length,
          bytes,
        ),
      );
    }

    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) throw StateError('백업 ZIP 생성에 실패했습니다.');
    final documents = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .substring(0, 10)
        .replaceAll('-', '');
    final file = File(p.join(documents.path, 'easy_ledger_backup_$stamp.zip'));
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'Easy Ledger 백업');
    return file;
  }

  Future<BackupResult> restoreFromZip(
    File zipFile, {
    BackupRestoreMode mode = BackupRestoreMode.merge,
  }) async {
    final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
    final dataFile = archive.findFile('data.json');
    if (dataFile == null) throw StateError('data.json이 없는 백업 파일입니다.');
    final json = jsonDecode(utf8.decode(dataFile.content as List<int>));
    if (json is! Map<String, dynamic>) {
      throw StateError('백업 data.json 형식이 올바르지 않습니다.');
    }

    final documents = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(documents.path, 'receipts'));
    await imageDir.create(recursive: true);
    final imageNames = <String>{};
    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith('images/')) continue;
      final imageName = p.basename(file.name);
      final dest = File(p.join(imageDir.path, imageName));
      await dest.writeAsBytes(file.content as List<int>, flush: true);
      imageNames.add(imageName);
    }

    final receipts = _readList(json['receipts']).map((raw) {
      final map = raw as Map<String, dynamic>;
      final imageName =
          map['imageName']?.toString() ??
          p.basename(map['imagePath']?.toString() ?? '');
      final restoredPath = imageNames.contains(imageName)
          ? p.join(imageDir.path, imageName)
          : map['imagePath']?.toString() ?? '';
      return Receipt(
        id: map['id'].toString(),
        imagePath: restoredPath,
        scannedAt: DateTime.parse(map['scannedAt'].toString()),
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
        rawJson: map['rawJson']?.toString() ?? '',
      );
    }).toList();
    final transactions = _readList(
      json['transactions'],
    ).map((raw) => _transactionFromJson(raw as Map<String, dynamic>)).toList();
    final items = _readList(
      json['transaction_items'],
    ).map((raw) => _itemFromJson(raw as Map<String, dynamic>)).toList();
    final categories = _readList(
      json['categories'],
    ).map((raw) => _categoryFromJson(raw as Map<String, dynamic>)).toList();
    final existingIds = _hive.allTransactions().map((tx) => tx.id).toSet();
    final skipped = mode == BackupRestoreMode.merge
        ? transactions.where((tx) => existingIds.contains(tx.id)).length
        : 0;

    await _hive.restoreData(
      receipts: receipts,
      transactions: transactions,
      items: items,
      categories: categories,
      settings: Map<String, dynamic>.from(
        json['settings'] as Map? ?? const <String, dynamic>{},
      ),
      overwrite: mode == BackupRestoreMode.overwrite,
    );

    return BackupResult(
      restoredTransactions: transactions.length - skipped,
      restoredImages: imageNames.length,
      skippedTransactions: skipped,
    );
  }

  Future<void> deleteAllData() async {
    for (final receipt in _hive.allReceipts()) {
      final file = File(receipt.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _hive.clearAllLocalData();
  }

  Map<String, dynamic> _receiptToJson(Receipt receipt) => {
    'id': receipt.id,
    'imagePath': receipt.imagePath,
    'imageName': p.basename(receipt.imagePath),
    'scannedAt': receipt.scannedAt.toIso8601String(),
    'confidence': receipt.confidence,
    'rawJson': receipt.rawJson,
  };

  Map<String, dynamic> _transactionToJson(ledger.Transaction tx) => {
    'id': tx.id,
    'receiptId': tx.receiptId,
    'date': tx.date.toIso8601String(),
    'time': tx.time,
    'storeName': tx.storeName,
    'businessNumber': tx.businessNumber,
    'total': tx.total,
    'tax': tx.tax,
    'paymentMethod': tx.paymentMethod,
    'category': tx.category,
    'expenseType': tx.expenseType,
    'taxCategory': tx.taxCategory,
    'memo': tx.memo,
    'syncedToSheet': tx.syncedToSheet,
    'createdAt': tx.createdAt.toIso8601String(),
    'sheetRowIndex': tx.sheetRowIndex,
    'sheetSyncedAt': tx.sheetSyncedAt?.toIso8601String(),
  };

  ledger.Transaction _transactionFromJson(Map<String, dynamic> map) {
    return ledger.Transaction(
      id: map['id'].toString(),
      receiptId: map['receiptId'] as String?,
      date: DateTime.parse(map['date'].toString()),
      time: map['time'] as String?,
      storeName: map['storeName'].toString(),
      businessNumber: map['businessNumber'] as String?,
      total: (map['total'] as num).toInt(),
      tax: (map['tax'] as num?)?.toInt(),
      paymentMethod: map['paymentMethod']?.toString() ?? 'card',
      category: map['category']?.toString() ?? 'etc',
      expenseType: map['expenseType']?.toString() ?? 'personal',
      taxCategory: map['taxCategory'] as String?,
      memo: map['memo'] as String?,
      syncedToSheet: map['syncedToSheet'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'].toString()),
      sheetRowIndex: (map['sheetRowIndex'] as num?)?.toInt(),
      sheetSyncedAt: map['sheetSyncedAt'] == null
          ? null
          : DateTime.parse(map['sheetSyncedAt'].toString()),
    );
  }

  Map<String, dynamic> _itemToJson(TransactionItem item) => {
    'id': item.id,
    'transactionId': item.transactionId,
    'name': item.name,
    'quantity': item.quantity,
    'unitPrice': item.unitPrice,
    'total': item.total,
  };

  TransactionItem _itemFromJson(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'].toString(),
      transactionId: map['transactionId'].toString(),
      name: map['name'].toString(),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (map['unitPrice'] as num).toInt(),
      total: (map['total'] as num).toInt(),
    );
  }

  Map<String, dynamic> _categoryToJson(model.Category category) => {
    'id': category.id,
    'name': category.name,
    'iconEmoji': category.iconEmoji,
    'colorHex': category.colorHex,
    'isDefault': category.isDefault,
    'taxCategory': category.taxCategory,
    'sortOrder': category.sortOrder,
  };

  model.Category _categoryFromJson(Map<String, dynamic> map) {
    return model.Category(
      id: map['id'].toString(),
      name: map['name'].toString(),
      iconEmoji: map['iconEmoji']?.toString() ?? '🧾',
      colorHex: (map['colorHex'] as num?)?.toInt() ?? 0xFF90A4AE,
      isDefault: map['isDefault'] as bool? ?? false,
      taxCategory: map['taxCategory'] as String?,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  List<dynamic> _readList(Object? value) => value is List ? value : const [];
}
