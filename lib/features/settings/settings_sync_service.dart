import '../../core/sheets/google_auth_service.dart';
import '../../core/sheets/sheets_service.dart';
import '../../core/sheets/sync_queue.dart';
import '../../core/storage/hive_storage.dart';
import 'settings_state.dart';

class SheetConnectionResult {
  final String? sheetId;
  final GoogleStatus googleStatus;
  final String? googleEmail;
  final String message;

  const SheetConnectionResult({
    required this.sheetId,
    required this.googleStatus,
    required this.googleEmail,
    required this.message,
  });
}

class SettingsSyncService {
  final HiveStorage _hive;
  final GoogleAuthService _googleAuth;
  final SyncQueue _syncQueue;

  SettingsSyncService({
    required HiveStorage hive,
    required GoogleAuthService googleAuth,
    required SyncQueue syncQueue,
  }) : _hive = hive,
       _googleAuth = googleAuth,
       _syncQueue = syncQueue;

  Future<GoogleStatus> loginGoogle() async {
    final client = await _googleAuth.signIn();
    return client == null ? GoogleStatus.signedOut : GoogleStatus.signedIn;
  }

  Future<void> logoutGoogle() async {
    await _googleAuth.signOut();
    await _hive.setSheetId(null);
  }

  Future<String?> saveSheetId(String input) async {
    final id = extractSheetId(input);
    await _hive.setSheetId(id);
    return id;
  }

  Future<SheetConnectionResult> testSheetConnection(String input) async {
    final id = extractSheetId(input);
    if (id == null) {
      throw const FormatException('시트 ID를 입력하세요.');
    }
    final client =
        await _googleAuth.currentAuthClient() ?? await _googleAuth.signIn();
    if (client == null) {
      return const SheetConnectionResult(
        sheetId: null,
        googleStatus: GoogleStatus.signedOut,
        googleEmail: null,
        message: 'Google 로그인이 취소되었습니다.',
      );
    }
    await SheetsService(client).ensureHeader(id);
    return SheetConnectionResult(
      sheetId: id,
      googleStatus: GoogleStatus.signedIn,
      googleEmail: _googleAuth.userEmail,
      message: '연결 성공: 첫 번째 시트 헤더를 확인했습니다.',
    );
  }

  Future<int> processSyncQueueNow() async {
    await _syncQueue.processNow();
    return _syncQueue.pendingCount;
  }

  String? get googleEmail => _googleAuth.userEmail;

  static String? extractSheetId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final match = RegExp(r'/d/([^/]+)').firstMatch(trimmed);
    return match?.group(1) ?? trimmed;
  }
}
