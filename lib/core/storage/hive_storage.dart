import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/budget.dart';
import '../models/category.dart' as model;
import '../models/receipt.dart';
import '../models/sync_item.dart';
import '../models/transaction.dart';
import '../models/transaction_item.dart';

/// 영수증/거래/품목 박스를 묶어서 다루는 영속화 레이어.
///
/// Phase 0 의 `secure_storage.dart` 는 Keychain 기반 시크릿 전용이고,
/// 이 파일은 일반 비즈니스 데이터(Hive 박스)를 다룬다 — 두 레이어 분리.
///
/// 사용 패턴:
///   void main() async {
///     WidgetsFlutterBinding.ensureInitialized();
///     final hive = await HiveStorage.init();
///     runApp(EasyLedgerApp(hive: hive));
///   }
class HiveStorage {
  static const _boxReceipts = 'receipts';
  static const _boxTransactions = 'transactions';
  static const _boxItems = 'transaction_items';
  static const _boxSyncQueue = 'sync_queue';
  static const _boxSettings = 'settings';
  static const _boxCategories = 'categories';
  static const _boxBudgets = 'budgets';

  static const _keyAutoSave = 'autoSave';
  static const _keyAutoSync = 'autoSync';
  static const _keySheetId = 'sheetId';
  static const _keyMonthStartDay = 'monthStartDay';
  static const _keyDefaultExpenseType = 'defaultExpenseType';

  final Box<Receipt> _receipts;
  final Box<Transaction> _transactions;
  final Box<TransactionItem> _items;
  final Box<SyncItem> _syncItems;
  final Box<dynamic> _settings;
  final Box<model.Category> _categories;
  final Box<Budget> _budgets;

  HiveStorage._(
    this._receipts,
    this._transactions,
    this._items,
    this._syncItems,
    this._settings,
    this._categories,
    this._budgets,
  );

  /// 앱 시작 시 1회 호출. 어댑터 등록 + 박스 열기.
  static Future<HiveStorage> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ReceiptAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(TransactionItemAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(model.CategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(SyncItemAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BudgetAdapter());
    }

    final receipts = await Hive.openBox<Receipt>(_boxReceipts);
    final transactions = await Hive.openBox<Transaction>(_boxTransactions);
    final items = await Hive.openBox<TransactionItem>(_boxItems);
    final syncItems = await Hive.openBox<SyncItem>(_boxSyncQueue);
    final settings = await Hive.openBox<dynamic>(_boxSettings);
    final categories = await Hive.openBox<model.Category>(_boxCategories);
    final budgets = await Hive.openBox<Budget>(_boxBudgets);
    final storage = HiveStorage._(
      receipts,
      transactions,
      items,
      syncItems,
      settings,
      categories,
      budgets,
    );
    await storage.ensureDefaultCategories();

    debugPrint(
      '[Hive] init OK: receipts=${receipts.length} '
      'transactions=${transactions.length} items=${items.length} '
      'syncQueue=${syncItems.length} categories=${categories.length} '
      'budgets=${budgets.length}',
    );

    return storage;
  }

  // ──────────────── 복합 저장 (스캔 → 저장 플로우) ────────────────

  /// AI 추출 결과를 한 번에 저장. Receipt + Transaction + N TransactionItems.
  Future<void> saveScanResult({
    required Receipt receipt,
    required Transaction transaction,
    required List<TransactionItem> items,
  }) async {
    await _receipts.put(receipt.id, receipt);
    await _transactions.put(transaction.id, transaction);
    for (final it in items) {
      await _items.put(it.id, it);
    }
    debugPrint(
      '[Hive] saveScanResult: tx=${transaction.id} items=${items.length}',
    );
  }

  // ──────────────── 단건 CRUD ────────────────

  Future<void> saveTransaction(Transaction t) => _transactions.put(t.id, t);

  /// 문서 §17 용어와 맞춘 alias. 수동 입력 저장에서 사용.
  Future<void> addTransaction(Transaction t) => saveTransaction(t);

  Future<void> updateTransaction(Transaction t) => _transactions.put(t.id, t);

  /// 거래 삭제 시 연관 품목 + (다른 거래에서 참조 안 하면) 영수증도 정리.
  Future<void> deleteTransaction(String id) async {
    final tx = _transactions.get(id);
    if (tx == null) return;

    // 1) 품목 정리
    final childItemIds = _items.values
        .where((it) => it.transactionId == id)
        .map((it) => it.id)
        .toList();
    for (final iid in childItemIds) {
      await _items.delete(iid);
    }

    // 2) 영수증 정리 (다른 트랜잭션이 같은 receiptId 안 쓸 때만)
    final receiptId = tx.receiptId;
    if (receiptId != null) {
      final stillReferenced = _transactions.values.any(
        (other) => other.id != id && other.receiptId == receiptId,
      );
      if (!stillReferenced) {
        await _receipts.delete(receiptId);
      }
    }

    // 3) 트랜잭션 자체 삭제
    await _transactions.delete(id);

    debugPrint(
      '[Hive] deleteTransaction: tx=$id items=${childItemIds.length} '
      'receiptCleaned=${receiptId != null}',
    );
  }

  // ──────────────── 단건 조회 ────────────────

  Receipt? getReceipt(String id) => _receipts.get(id);
  Transaction? getTransaction(String id) => _transactions.get(id);
  List<Receipt> allReceipts() => _receipts.values.toList();
  List<TransactionItem> allItems() => _items.values.toList();
  Map<String, dynamic> settingsSnapshot() => {
    for (final key in _settings.keys) key.toString(): _settings.get(key),
  };

  // ──────────────── 목록 조회 ────────────────

  /// 전체 거래, 최신순(date desc).
  List<Transaction> allTransactions() {
    final list = _transactions.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// 특정 연/월의 거래.
  List<Transaction> transactionsByMonth(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final list = _transactions.values
        .where((t) => !t.date.isBefore(start) && t.date.isBefore(end))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// 특정 일자의 거래, 최신순(date desc).
  List<Transaction> getByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final list = _transactions.values
        .where((t) => !t.date.isBefore(start) && t.date.isBefore(end))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// 특정 거래의 품목.
  List<TransactionItem> itemsByTransaction(String txId) {
    return _items.values.where((it) => it.transactionId == txId).toList();
  }

  /// 월별 합계. Phase 1 에서는 모든 트랜잭션이 지출이므로 income=0.
  /// Phase 2+ 에서 income 분류 추가 시 확장.
  ({int income, int expense}) totalsByMonth(int year, int month) {
    final list = transactionsByMonth(year, month);
    final expense = list.fold<int>(0, (sum, t) => sum + t.total);
    return (income: 0, expense: expense);
  }

  /// 디버그/테스트 전용: 박스 전체 비우기.
  Future<void> debugClearAll() async {
    await _receipts.clear();
    await _transactions.clear();
    await _items.clear();
    await _syncItems.clear();
    await _budgets.clear();
    debugPrint('[Hive] debugClearAll: all boxes emptied');
  }

  /// 사용자 데이터 초기화: 백업/복원 설정 화면의 "전체 삭제"에서 사용.
  Future<void> clearAllLocalData() async {
    await _receipts.clear();
    await _transactions.clear();
    await _items.clear();
    await _syncItems.clear();
    await _categories.clear();
    await _budgets.clear();
    await _settings.clear();
    await ensureDefaultCategories();
    debugPrint('[Hive] clearAllLocalData: all local data emptied');
  }

  // ──────────────── Phase 2 설정 + 카테고리 ────────────────

  bool get autoSaveEnabled {
    final value = _settings.get(_keyAutoSave, defaultValue: false);
    return value is bool ? value : false;
  }

  Future<void> setAutoSaveEnabled(bool value) =>
      _settings.put(_keyAutoSave, value);

  bool get autoSyncEnabled {
    final value = _settings.get(_keyAutoSync, defaultValue: true);
    return value is bool ? value : true;
  }

  Future<void> setAutoSyncEnabled(bool value) =>
      _settings.put(_keyAutoSync, value);

  String? get sheetId {
    final value = _settings.get(_keySheetId);
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  Future<void> setSheetId(String? value) async {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      await _settings.delete(_keySheetId);
      return;
    }
    await _settings.put(_keySheetId, normalized);
  }

  int get monthStartDay {
    final value = _settings.get(_keyMonthStartDay, defaultValue: 1);
    final day = value is num ? value.toInt() : 1;
    return day.clamp(1, 28).toInt();
  }

  Future<void> setMonthStartDay(int value) =>
      _settings.put(_keyMonthStartDay, value.clamp(1, 28).toInt());

  String get defaultExpenseType {
    final value = _settings.get(
      _keyDefaultExpenseType,
      defaultValue: 'personal',
    );
    return value == 'business' ? 'business' : 'personal';
  }

  Future<void> setDefaultExpenseType(String value) => _settings.put(
    _keyDefaultExpenseType,
    value == 'business' ? value : 'personal',
  );

  int get transactionCount => _transactions.length;
  int get receiptCount => _receipts.length;
  int get itemCount => _items.length;
  Box<SyncItem> get syncItemsBox => _syncItems;

  List<model.Category> categories() {
    final values = _categories.values.toList();
    values.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return values;
  }

  model.Category? categoryFor(String id) => _categories.get(id);

  String categoryName(String id) => categoryFor(id)?.name ?? id;

  String categoryIcon(String id) => categoryFor(id)?.iconEmoji ?? '🧾';

  int categoryColorHex(String id) => categoryFor(id)?.colorHex ?? 0xFF90A4AE;

  Future<void> ensureDefaultCategories() async {
    for (final category in model.defaultCategories) {
      if (!_categories.containsKey(category.id)) {
        await _categories.put(category.id, category);
      }
    }
  }

  Future<void> upsertCategory(model.Category category) async {
    await _categories.put(category.id, category);
  }

  Future<void> reorderCategories(List<model.Category> categories) async {
    for (var i = 0; i < categories.length; i++) {
      await _categories.put(
        categories[i].id,
        categories[i].copyWith(sortOrder: i),
      );
    }
  }

  Future<void> deleteCategory(String id) async {
    final category = _categories.get(id);
    if (category == null || category.isDefault) return;
    await _categories.delete(id);
  }

  List<Budget> budgetsByMonth(int year, int month) {
    final list = _budgets.values
        .where((budget) => budget.year == year && budget.month == month)
        .toList();
    final categoryOrder = {
      for (final category in categories()) category.id: category.sortOrder,
    };
    list.sort((a, b) {
      final left = categoryOrder[a.categoryId] ?? 9999;
      final right = categoryOrder[b.categoryId] ?? 9999;
      if (left != right) return left.compareTo(right);
      return a.categoryId.compareTo(b.categoryId);
    });
    return list;
  }

  Budget? budgetForCategory(String categoryId, int year, int month) {
    final id = budgetId(categoryId, year, month);
    return _budgets.get(id);
  }

  Map<String, int> budgetAmountMapForMonth(int year, int month) {
    return {
      for (final budget in budgetsByMonth(year, month))
        budget.categoryId: budget.monthlyAmount,
    };
  }

  int totalBudgetByMonth(int year, int month) {
    return budgetsByMonth(
      year,
      month,
    ).fold<int>(0, (sum, budget) => sum + budget.monthlyAmount);
  }

  Future<void> upsertBudget(Budget budget) => _budgets.put(budget.id, budget);

  Future<void> deleteBudget(String id) => _budgets.delete(id);

  static String budgetId(String categoryId, int year, int month) {
    return '$year-${month.toString().padLeft(2, '0')}-$categoryId';
  }

  Future<void> restoreData({
    required List<Receipt> receipts,
    required List<Transaction> transactions,
    required List<TransactionItem> items,
    required List<model.Category> categories,
    required Map<String, dynamic> settings,
    required bool overwrite,
  }) async {
    if (overwrite) {
      await _receipts.clear();
      await _transactions.clear();
      await _items.clear();
      await _syncItems.clear();
      await _categories.clear();
      await _settings.clear();
    }
    for (final receipt in receipts) {
      if (overwrite || !_receipts.containsKey(receipt.id)) {
        await _receipts.put(receipt.id, receipt);
      }
    }
    for (final transaction in transactions) {
      if (overwrite || !_transactions.containsKey(transaction.id)) {
        await _transactions.put(transaction.id, transaction);
      }
    }
    for (final item in items) {
      if (overwrite || !_items.containsKey(item.id)) {
        await _items.put(item.id, item);
      }
    }
    for (final category in categories) {
      if (overwrite || !_categories.containsKey(category.id)) {
        await _categories.put(category.id, category);
      }
    }
    for (final entry in settings.entries) {
      if (overwrite || !_settings.containsKey(entry.key)) {
        await _settings.put(entry.key, entry.value);
      }
    }
    await ensureDefaultCategories();
  }

  // ──────────────── ListenableBuilder 용 ────────────────

  Listenable get listenable => Listenable.merge([
    _transactions.listenable(),
    _items.listenable(),
    _receipts.listenable(),
    _syncItems.listenable(),
    _settings.listenable(),
    _categories.listenable(),
    _budgets.listenable(),
  ]);
}
