import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/export/backup_service.dart';
import '../../core/export/simple_ledger_exporter.dart';
import '../../core/oauth/codex_oauth.dart';
import '../../core/sheets/google_auth_service.dart';
import '../../core/sheets/sheets_service.dart';
import '../../core/sheets/sync_queue.dart';
import '../../core/storage/hive_storage.dart';
import '../../core/storage/secure_storage.dart';

enum CodexStatus { loggedOut, loggingIn, loggedIn }

enum GoogleStatus { signedOut, signingIn, signedIn }

class SettingsState {
  final CodexStatus codexStatus;
  final String? accountIdShort;
  final bool geminiKeySaved;
  final bool autoSaveEnabled;
  final bool autoSyncEnabled;
  final int monthStartDay;
  final String defaultExpenseType;
  final int transactionCount;
  final int receiptCount;
  final int itemCount;
  final int syncPendingCount;
  final GoogleStatus googleStatus;
  final String? googleEmail;
  final String? sheetId;
  final bool testingSheet;
  final bool exportingLedger;
  final bool backupBusy;
  final String? sheetTestMessage;
  final String? errorText;

  const SettingsState({
    required this.codexStatus,
    this.accountIdShort,
    required this.geminiKeySaved,
    required this.autoSaveEnabled,
    required this.autoSyncEnabled,
    required this.monthStartDay,
    required this.defaultExpenseType,
    required this.transactionCount,
    required this.receiptCount,
    required this.itemCount,
    required this.syncPendingCount,
    required this.googleStatus,
    this.googleEmail,
    this.sheetId,
    required this.testingSheet,
    required this.exportingLedger,
    required this.backupBusy,
    this.sheetTestMessage,
    this.errorText,
  });

  factory SettingsState.initial() => const SettingsState(
    codexStatus: CodexStatus.loggedOut,
    geminiKeySaved: false,
    autoSaveEnabled: false,
    autoSyncEnabled: true,
    monthStartDay: 1,
    defaultExpenseType: 'personal',
    transactionCount: 0,
    receiptCount: 0,
    itemCount: 0,
    syncPendingCount: 0,
    googleStatus: GoogleStatus.signedOut,
    testingSheet: false,
    exportingLedger: false,
    backupBusy: false,
  );

  SettingsState copyWith({
    CodexStatus? codexStatus,
    Object? accountIdShort = _sentinel,
    bool? geminiKeySaved,
    bool? autoSaveEnabled,
    bool? autoSyncEnabled,
    int? monthStartDay,
    String? defaultExpenseType,
    int? transactionCount,
    int? receiptCount,
    int? itemCount,
    int? syncPendingCount,
    GoogleStatus? googleStatus,
    Object? googleEmail = _sentinel,
    Object? sheetId = _sentinel,
    bool? testingSheet,
    bool? exportingLedger,
    bool? backupBusy,
    Object? sheetTestMessage = _sentinel,
    Object? errorText = _sentinel,
  }) {
    return SettingsState(
      codexStatus: codexStatus ?? this.codexStatus,
      accountIdShort: identical(accountIdShort, _sentinel)
          ? this.accountIdShort
          : accountIdShort as String?,
      geminiKeySaved: geminiKeySaved ?? this.geminiKeySaved,
      autoSaveEnabled: autoSaveEnabled ?? this.autoSaveEnabled,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      monthStartDay: monthStartDay ?? this.monthStartDay,
      defaultExpenseType: defaultExpenseType ?? this.defaultExpenseType,
      transactionCount: transactionCount ?? this.transactionCount,
      receiptCount: receiptCount ?? this.receiptCount,
      itemCount: itemCount ?? this.itemCount,
      syncPendingCount: syncPendingCount ?? this.syncPendingCount,
      googleStatus: googleStatus ?? this.googleStatus,
      googleEmail: identical(googleEmail, _sentinel)
          ? this.googleEmail
          : googleEmail as String?,
      sheetId: identical(sheetId, _sentinel)
          ? this.sheetId
          : sheetId as String?,
      testingSheet: testingSheet ?? this.testingSheet,
      exportingLedger: exportingLedger ?? this.exportingLedger,
      backupBusy: backupBusy ?? this.backupBusy,
      sheetTestMessage: identical(sheetTestMessage, _sentinel)
          ? this.sheetTestMessage
          : sheetTestMessage as String?,
      errorText: identical(errorText, _sentinel)
          ? this.errorText
          : errorText as String?,
    );
  }
}

const Object _sentinel = Object();

/// 설정 탭 cubit — OAuth 로그인 + Gemini API Key 관리.
/// Phase 0 의 phase0_cubit 의 OAuth/Gemini 부분만 발췌 (영수증 추출 제외).
class SettingsCubit extends Cubit<SettingsState> {
  final SecureStorage _storage;
  final CodexOAuth _oauth;
  final HiveStorage _hive;
  final GoogleAuthService _googleAuth;
  final SyncQueue _syncQueue;

  SettingsCubit({
    required SecureStorage storage,
    required CodexOAuth oauth,
    required HiveStorage hive,
    required GoogleAuthService googleAuth,
    required SyncQueue syncQueue,
  }) : _storage = storage,
       _oauth = oauth,
       _hive = hive,
       _googleAuth = googleAuth,
       _syncQueue = syncQueue,
       super(SettingsState.initial());

  Future<void> init() async {
    final tokens = await _storage.readCodexTokens();
    final geminiKey = await _storage.readGeminiKey();
    await _googleAuth.currentAuthClient();
    debugPrint(
      '[Settings] init: tokens=${tokens == null ? "null" : "present"} '
      'geminiKey=${geminiKey == null ? "null" : "present(len=${geminiKey.length})"}',
    );
    emit(
      state.copyWith(
        codexStatus: tokens != null
            ? CodexStatus.loggedIn
            : CodexStatus.loggedOut,
        accountIdShort: tokens != null ? _short(tokens.accountId) : null,
        geminiKeySaved: geminiKey != null && geminiKey.isNotEmpty,
        autoSaveEnabled: _hive.autoSaveEnabled,
        autoSyncEnabled: _hive.autoSyncEnabled,
        monthStartDay: _hive.monthStartDay,
        defaultExpenseType: _hive.defaultExpenseType,
        transactionCount: _hive.transactionCount,
        receiptCount: _hive.receiptCount,
        itemCount: _hive.itemCount,
        syncPendingCount: _syncQueue.pendingCount,
        googleStatus: _googleAuth.isSignedIn
            ? GoogleStatus.signedIn
            : GoogleStatus.signedOut,
        googleEmail: _googleAuth.userEmail,
        sheetId: _hive.sheetId,
      ),
    );
  }

  Future<void> loginCodex() async {
    if (state.codexStatus == CodexStatus.loggingIn) return;
    debugPrint('[Settings] loginCodex: START');
    emit(state.copyWith(codexStatus: CodexStatus.loggingIn, errorText: null));
    try {
      final tokens = await _oauth.login(
        onOpenBrowser: (uri) async {
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!ok) {
            throw StateError('외부 브라우저를 열 수 없습니다. URL: $uri');
          }
        },
      );
      await _storage.writeCodexTokens(tokens);
      emit(
        state.copyWith(
          codexStatus: CodexStatus.loggedIn,
          accountIdShort: _short(tokens.accountId),
          errorText: null,
        ),
      );
      debugPrint('[Settings] loginCodex: emitted loggedIn');
    } catch (e, st) {
      debugPrint('[Settings] loginCodex: EXCEPTION: $e');
      emit(
        state.copyWith(
          codexStatus: CodexStatus.loggedOut,
          errorText: 'ChatGPT 로그인 실패:\n$e\n\n$st',
        ),
      );
    }
  }

  Future<void> logoutCodex() async {
    await _storage.clearCodexTokens();
    emit(
      state.copyWith(codexStatus: CodexStatus.loggedOut, accountIdShort: null),
    );
  }

  Future<void> debugExpireCodexToken() async {
    await _storage.debugExpireCodexToken();
  }

  Future<void> saveGeminiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await _storage.clearGeminiKey();
      emit(state.copyWith(geminiKeySaved: false));
      return;
    }
    await _storage.writeGeminiKey(trimmed);
    emit(state.copyWith(geminiKeySaved: true));
  }

  Future<void> setAutoSaveEnabled(bool value) async {
    await _hive.setAutoSaveEnabled(value);
    emit(state.copyWith(autoSaveEnabled: value));
  }

  Future<void> setAutoSyncEnabled(bool value) async {
    await _hive.setAutoSyncEnabled(value);
    emit(state.copyWith(autoSyncEnabled: value));
  }

  Future<void> setMonthStartDay(int value) async {
    await _hive.setMonthStartDay(value);
    emit(state.copyWith(monthStartDay: _hive.monthStartDay));
  }

  Future<void> setDefaultExpenseType(String value) async {
    await _hive.setDefaultExpenseType(value);
    emit(state.copyWith(defaultExpenseType: _hive.defaultExpenseType));
  }

  Future<void> loginGoogle() async {
    if (state.googleStatus == GoogleStatus.signingIn) return;
    emit(
      state.copyWith(
        googleStatus: GoogleStatus.signingIn,
        errorText: null,
        sheetTestMessage: null,
      ),
    );
    try {
      final client = await _googleAuth.signIn();
      emit(
        state.copyWith(
          googleStatus: client == null
              ? GoogleStatus.signedOut
              : GoogleStatus.signedIn,
          googleEmail: _googleAuth.userEmail,
          errorText: null,
        ),
      );
    } catch (e, st) {
      emit(
        state.copyWith(
          googleStatus: GoogleStatus.signedOut,
          googleEmail: null,
          errorText: 'Google 로그인 실패:\n$e\n\n$st',
        ),
      );
    }
  }

  Future<void> logoutGoogle() async {
    await _googleAuth.signOut();
    await _hive.setSheetId(null);
    emit(
      state.copyWith(
        googleStatus: GoogleStatus.signedOut,
        googleEmail: null,
        sheetId: null,
        sheetTestMessage: null,
      ),
    );
  }

  Future<void> saveSheetId(String input) async {
    final id = _extractSheetId(input);
    await _hive.setSheetId(id);
    emit(state.copyWith(sheetId: id, sheetTestMessage: null));
  }

  Future<void> testSheetConnection(String input) async {
    final id = _extractSheetId(input);
    if (id == null) {
      emit(state.copyWith(sheetTestMessage: '시트 ID를 입력하세요.'));
      return;
    }
    await _hive.setSheetId(id);
    emit(
      state.copyWith(testingSheet: true, sheetId: id, sheetTestMessage: null),
    );
    try {
      final client =
          await _googleAuth.currentAuthClient() ?? await _googleAuth.signIn();
      if (client == null) {
        emit(
          state.copyWith(
            testingSheet: false,
            googleStatus: GoogleStatus.signedOut,
            sheetTestMessage: 'Google 로그인이 취소되었습니다.',
          ),
        );
        return;
      }
      await SheetsService(client).ensureHeader(id);
      await _syncQueue.processNow();
      emit(
        state.copyWith(
          testingSheet: false,
          googleStatus: GoogleStatus.signedIn,
          googleEmail: _googleAuth.userEmail,
          syncPendingCount: _syncQueue.pendingCount,
          sheetTestMessage: '연결 성공: 첫 번째 시트 헤더를 확인했습니다.',
          errorText: null,
        ),
      );
    } catch (e, st) {
      emit(
        state.copyWith(
          testingSheet: false,
          sheetTestMessage: '연결 실패: $e',
          errorText: 'Google Sheets 연결 테스트 실패:\n$e\n\n$st',
        ),
      );
    }
  }

  Future<void> processSyncQueueNow() async {
    final sheetId = _hive.sheetId;
    if (sheetId == null) {
      emit(state.copyWith(sheetTestMessage: '시트 ID를 먼저 입력하세요.'));
      return;
    }
    emit(state.copyWith(testingSheet: true, sheetTestMessage: null));
    try {
      await _syncQueue.processNow();
      emit(
        state.copyWith(
          testingSheet: false,
          syncPendingCount: _syncQueue.pendingCount,
          sheetTestMessage: '동기화 처리 완료: 대기 ${_syncQueue.pendingCount}건',
        ),
      );
    } catch (e, st) {
      emit(
        state.copyWith(
          testingSheet: false,
          syncPendingCount: _syncQueue.pendingCount,
          errorText: '동기화 실패:\n$e\n\n$st',
          sheetTestMessage: '동기화 실패: $e',
        ),
      );
    }
  }

  Future<void> exportSimpleLedger({required int year, int? month}) async {
    emit(state.copyWith(exportingLedger: true, sheetTestMessage: null));
    try {
      final file = await SimpleLedgerExporter(
        _hive,
      ).exportAndShare(year: year, month: month);
      emit(
        state.copyWith(
          exportingLedger: false,
          sheetTestMessage: '내보내기 완료: ${file.path}',
          errorText: null,
        ),
      );
    } catch (e, st) {
      emit(
        state.copyWith(
          exportingLedger: false,
          sheetTestMessage: '내보내기 실패: $e',
          errorText: '간편장부 내보내기 실패:\n$e\n\n$st',
        ),
      );
    }
  }

  Future<void> createBackup() async {
    emit(state.copyWith(backupBusy: true, sheetTestMessage: null));
    try {
      final file = await BackupService(_hive).createBackup();
      emit(
        state.copyWith(
          backupBusy: false,
          sheetTestMessage: '백업 생성 완료: ${file.path}',
          errorText: null,
        ),
      );
    } catch (e, st) {
      emit(
        state.copyWith(
          backupBusy: false,
          sheetTestMessage: '백업 생성 실패: $e',
          errorText: '백업 생성 실패:\n$e\n\n$st',
        ),
      );
    }
  }

  Future<void> restoreBackup(
    String path, {
    required BackupRestoreMode mode,
  }) async {
    emit(state.copyWith(backupBusy: true, sheetTestMessage: null));
    try {
      final result = await BackupService(
        _hive,
      ).restoreFromZip(File(path), mode: mode);
      emit(
        state.copyWith(
          backupBusy: false,
          transactionCount: _hive.transactionCount,
          receiptCount: _hive.receiptCount,
          itemCount: _hive.itemCount,
          sheetTestMessage:
              '복원 완료: 거래 ${result.restoredTransactions}건, 이미지 ${result.restoredImages}장, 스킵 ${result.skippedTransactions}건',
          errorText: null,
        ),
      );
    } catch (e, st) {
      emit(
        state.copyWith(
          backupBusy: false,
          sheetTestMessage: '복원 실패: $e',
          errorText: '백업 복원 실패:\n$e\n\n$st',
        ),
      );
    }
  }

  Future<void> deleteAllData() async {
    emit(state.copyWith(backupBusy: true, sheetTestMessage: null));
    try {
      await BackupService(_hive).deleteAllData();
      emit(
        state.copyWith(
          backupBusy: false,
          transactionCount: _hive.transactionCount,
          receiptCount: _hive.receiptCount,
          itemCount: _hive.itemCount,
          syncPendingCount: _syncQueue.pendingCount,
          sheetTestMessage: '전체 데이터 삭제 완료',
          errorText: null,
        ),
      );
    } catch (e, st) {
      emit(
        state.copyWith(
          backupBusy: false,
          sheetTestMessage: '전체 삭제 실패: $e',
          errorText: '전체 삭제 실패:\n$e\n\n$st',
        ),
      );
    }
  }

  String? _extractSheetId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final match = RegExp(r'/d/([^/]+)').firstMatch(trimmed);
    return match?.group(1) ?? trimmed;
  }

  String _short(String id) => id.length <= 10 ? id : '${id.substring(0, 10)}…';
}
