import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/export/backup_service.dart';
import '../../core/oauth/codex_oauth.dart';
import '../../core/sheets/google_auth_service.dart';
import '../../core/sheets/sync_queue.dart';
import '../../core/storage/hive_storage.dart';
import '../../core/storage/secure_storage.dart';
import 'settings_account_service.dart';
import 'settings_data_service.dart';
import 'settings_state.dart';
import 'settings_sync_service.dart';

/// 설정 탭 cubit — OAuth 로그인 + Gemini API Key 관리.
/// Phase 0 의 phase0_cubit 의 OAuth/Gemini 부분만 발췌 (영수증 추출 제외).
class SettingsCubit extends Cubit<SettingsState> {
  final SecureStorage _storage;
  final HiveStorage _hive;
  final GoogleAuthService _googleAuth;
  final SettingsAccountService _accountService;
  final SettingsSyncService _syncService;
  final SettingsDataService _dataService;

  SettingsCubit({
    required SecureStorage storage,
    required CodexOAuth oauth,
    required HiveStorage hive,
    required GoogleAuthService googleAuth,
    required SyncQueue syncQueue,
  }) : _storage = storage,
       _hive = hive,
       _googleAuth = googleAuth,
       _accountService = SettingsAccountService(storage: storage, oauth: oauth),
       _syncService = SettingsSyncService(
         hive: hive,
         googleAuth: googleAuth,
         syncQueue: syncQueue,
       ),
       _dataService = SettingsDataService(hive),
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
        accountIdShort: tokens != null
            ? SettingsAccountService.shortAccountId(tokens.accountId)
            : null,
        geminiKeySaved: geminiKey != null && geminiKey.isNotEmpty,
        autoSaveEnabled: _hive.autoSaveEnabled,
        autoSyncEnabled: _hive.autoSyncEnabled,
        monthStartDay: _hive.monthStartDay,
        defaultExpenseType: _hive.defaultExpenseType,
        transactionCount: _hive.transactionCount,
        receiptCount: _hive.receiptCount,
        itemCount: _hive.itemCount,
        syncPendingCount: _hive.syncItemsBox.length,
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
      final accountIdShort = await _accountService.loginCodex();
      emit(
        state.copyWith(
          codexStatus: CodexStatus.loggedIn,
          accountIdShort: accountIdShort,
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
    await _accountService.logoutCodex();
    emit(
      state.copyWith(codexStatus: CodexStatus.loggedOut, accountIdShort: null),
    );
  }

  Future<void> debugExpireCodexToken() async {
    await _accountService.debugExpireCodexToken();
  }

  Future<void> saveGeminiKey(String apiKey) async {
    final saved = await _accountService.saveGeminiKey(apiKey);
    emit(state.copyWith(geminiKeySaved: saved));
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
      final status = await _syncService.loginGoogle();
      emit(
        state.copyWith(
          googleStatus: status,
          googleEmail: _syncService.googleEmail,
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
    await _syncService.logoutGoogle();
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
    final id = await _syncService.saveSheetId(input);
    emit(state.copyWith(sheetId: id, sheetTestMessage: null));
  }

  Future<void> testSheetConnection(String input) async {
    emit(state.copyWith(testingSheet: true, sheetTestMessage: null));
    try {
      final result = await _syncService.testSheetConnection(input);
      emit(
        state.copyWith(
          testingSheet: false,
          googleStatus: result.googleStatus,
          googleEmail: result.googleEmail,
          sheetId: result.sheetId,
          sheetTestMessage: result.message,
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
      final pendingCount = await _syncService.processSyncQueueNow();
      emit(
        state.copyWith(
          testingSheet: false,
          syncPendingCount: pendingCount,
          sheetTestMessage: '동기화 처리 완료: 대기 $pendingCount건',
        ),
      );
    } catch (e, st) {
      emit(
        state.copyWith(
          testingSheet: false,
          syncPendingCount: state.syncPendingCount,
          errorText: '동기화 실패:\n$e\n\n$st',
          sheetTestMessage: '동기화 실패: $e',
        ),
      );
    }
  }

  Future<void> exportSimpleLedger({required int year, int? month}) async {
    emit(state.copyWith(exportingLedger: true, sheetTestMessage: null));
    try {
      final file = await _dataService.exportSimpleLedger(
        year: year,
        month: month,
      );
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
      final file = await _dataService.createBackup();
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
      final result = await _dataService.restoreBackup(path, mode: mode);
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
      await _dataService.deleteAllData();
      emit(
        state.copyWith(
          backupBusy: false,
          transactionCount: _hive.transactionCount,
          receiptCount: _hive.receiptCount,
          itemCount: _hive.itemCount,
          syncPendingCount: _hive.syncItemsBox.length,
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
}
