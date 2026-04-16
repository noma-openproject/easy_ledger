import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/transaction.dart' as ledger;
import '../models/sync_item.dart';
import '../storage/hive_storage.dart';
import '../utils/format_utils.dart';
import 'google_auth_service.dart';
import 'sheets_service.dart';

class SyncQueue {
  static const maxRetryCount = 5;

  final HiveStorage _hive;
  final GoogleAuthService _googleAuth;
  final Connectivity _connectivity;
  final Uuid _uuid;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _processing = false;

  SyncQueue({
    required HiveStorage hive,
    required GoogleAuthService googleAuth,
    Connectivity? connectivity,
    Uuid? uuid,
  }) : _hive = hive,
       _googleAuth = googleAuth,
       _connectivity = connectivity ?? Connectivity(),
       _uuid = uuid ?? const Uuid();

  int get pendingCount => _hive.syncItemsBox.length;

  Future<void> enqueue(String transactionId) async {
    final alreadyQueued = _hive.syncItemsBox.values.any(
      (item) =>
          item.transactionId == transactionId &&
          item.operation == SyncItem.operationUpsert,
    );
    if (alreadyQueued) return;
    final id = _uuid.v4();
    await _hive.syncItemsBox.put(
      id,
      SyncItem(
        id: id,
        transactionId: transactionId,
        createdAt: DateTime.now(),
        operation: SyncItem.operationUpsert,
      ),
    );
  }

  Future<void> enqueueDeletion(ledger.Transaction tx) async {
    await _removeQueuedItems(tx.id);
    if (!tx.syncedToSheet) return;
    final id = _uuid.v4();
    await _hive.syncItemsBox.put(
      id,
      SyncItem(
        id: id,
        transactionId: tx.id,
        createdAt: DateTime.now(),
        operation: SyncItem.operationDelete,
        preferredSheetRowIndex: tx.sheetRowIndex,
        fallbackDateText: formatCompactDate(tx.date),
        fallbackTime: tx.time,
        fallbackStoreName: tx.storeName,
        fallbackTotal: tx.total,
      ),
    );
  }

  Future<void> enqueueIfConfigured(String transactionId) async {
    await enqueue(transactionId);
    if (!_hive.autoSyncEnabled || _hive.sheetId == null) return;
    await processFromSettings();
  }

  Future<void> enqueueDeletionIfConfigured(ledger.Transaction tx) async {
    await enqueueDeletion(tx);
    if (!_hive.autoSyncEnabled || _hive.sheetId == null) return;
    await processFromSettings();
  }

  void startAutoProcessing() {
    _subscription ??= _connectivity.onConnectivityChanged.listen((results) {
      if (_isOnline(results)) {
        unawaited(processFromSettings());
      }
    });
  }

  Future<int> enqueueUnsyncedTransactions() async {
    final queued = _hive.syncItemsBox.values
        .map((item) => item.transactionId)
        .toSet();
    var added = 0;
    for (final tx in _hive.allTransactions()) {
      if (tx.syncedToSheet || queued.contains(tx.id)) continue;
      final id = _uuid.v4();
      await _hive.syncItemsBox.put(
        id,
        SyncItem(
          id: id,
          transactionId: tx.id,
          createdAt: DateTime.now(),
          operation: SyncItem.operationUpsert,
        ),
      );
      queued.add(tx.id);
      added += 1;
    }
    return added;
  }

  Future<void> processFromSettings() async {
    await _processQueueFromStorage(respectAutoSync: true);
  }

  Future<void> processNow() async {
    await enqueueUnsyncedTransactions();
    final spreadsheetId = _hive.sheetId;
    if (spreadsheetId == null) {
      throw StateError('시트 ID를 먼저 입력하세요.');
    }
    final connectivity = await _connectivity.checkConnectivity();
    if (!_isOnline(connectivity)) {
      throw StateError('인터넷 연결을 확인하세요.');
    }
    final client = await _googleAuth.currentAuthClient();
    if (client == null) {
      throw StateError('Google 로그인이 필요합니다.');
    }
    final sheets = SheetsService(client);
    await sheets.ensureHeader(spreadsheetId);
    await processQueue(sheets, spreadsheetId);
  }

  Future<void> _processQueueFromStorage({required bool respectAutoSync}) async {
    await enqueueUnsyncedTransactions();
    if (respectAutoSync && !_hive.autoSyncEnabled) return;
    final spreadsheetId = _hive.sheetId;
    if (spreadsheetId == null) return;
    final connectivity = await _connectivity.checkConnectivity();
    if (!_isOnline(connectivity)) return;
    final client = await _googleAuth.currentAuthClient();
    if (client == null) return;
    final sheets = SheetsService(client);
    await sheets.ensureHeader(spreadsheetId);
    await processQueue(sheets, spreadsheetId);
  }

  Future<void> processQueue(SheetsService sheets, String spreadsheetId) async {
    if (_processing) return;
    _processing = true;
    try {
      final items = _hive.syncItemsBox.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final item in items) {
        if (item.retryCount >= maxRetryCount) continue;
        try {
          switch (item.operation) {
            case SyncItem.operationDelete:
              await sheets.markTransactionDeletedById(
                spreadsheetId,
                item.transactionId,
                preferredRowIndex: item.preferredSheetRowIndex,
                fallbackDateText: item.fallbackDateText,
                fallbackTime: item.fallbackTime,
                fallbackStoreName: item.fallbackStoreName,
                fallbackTotal: item.fallbackTotal,
              );
              break;
            case SyncItem.operationUpsert:
              final tx = _hive.getTransaction(item.transactionId);
              if (tx == null) {
                await _hive.syncItemsBox.delete(item.id);
                continue;
              }
              final result = await sheets.upsertTransaction(
                spreadsheetId,
                tx,
                preferredRowIndex: tx.sheetRowIndex,
              );
              await _hive.updateTransaction(
                tx.copyWith(
                  syncedToSheet: true,
                  sheetRowIndex: result.rowIndex,
                  sheetSyncedAt: DateTime.now(),
                ),
              );
              break;
            default:
              throw StateError('알 수 없는 sync 작업: ${item.operation}');
          }
          await _hive.syncItemsBox.delete(item.id);
        } catch (e) {
          await _hive.syncItemsBox.put(
            item.id,
            item.copyWith(
              retryCount: item.retryCount + 1,
              lastError: e.toString(),
            ),
          );
        }
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<void> _removeQueuedItems(String transactionId) async {
    final itemIds = _hive.syncItemsBox.values
        .where((item) => item.transactionId == transactionId)
        .map((item) => item.id)
        .toList();
    for (final id in itemIds) {
      await _hive.syncItemsBox.delete(id);
    }
  }
}
