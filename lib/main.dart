import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/ai/codex_provider.dart';
import 'core/ai/gemini_provider.dart';
import 'core/oauth/codex_oauth.dart';
import 'core/sheets/google_auth_service.dart';
import 'core/sheets/sync_queue.dart';
import 'core/storage/hive_storage.dart';
import 'core/storage/secure_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  // Phase 1: Hive 박스 3개 (receipts/transactions/transaction_items) 초기화.
  // 어댑터(typeId 0/1/2) 등록은 HiveStorage.init() 내부에서 수행.
  final hive = await HiveStorage.init();
  runApp(EasyLedgerApp(hive: hive));
}

class EasyLedgerApp extends StatelessWidget {
  final HiveStorage hive;
  const EasyLedgerApp({super.key, required this.hive});

  @override
  Widget build(BuildContext context) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 3), // SSE 대기 여유
        sendTimeout: const Duration(seconds: 60),
      ),
    );

    final secureStorage = SecureStorage();
    final oauth = CodexOAuth(dio);
    final codex = CodexProvider(dio: dio, storage: secureStorage, oauth: oauth);
    final gemini = GeminiProvider(dio: dio, storage: secureStorage);
    final googleAuth = GoogleAuthService();
    final syncQueue = SyncQueue(hive: hive, googleAuth: googleAuth)
      ..startAutoProcessing();

    return AppDeps(
      hive: hive,
      secureStorage: secureStorage,
      dio: dio,
      oauth: oauth,
      codex: codex,
      gemini: gemini,
      googleAuth: googleAuth,
      syncQueue: syncQueue,
      child: MaterialApp(
        title: '쉬운장부',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF2E7D32),
          scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        ),
        home: const RootShell(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
