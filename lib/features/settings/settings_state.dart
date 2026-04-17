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
