import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'core/ai/codex_provider.dart';
import 'core/ai/gemini_provider.dart';
import 'core/oauth/codex_oauth.dart';
import 'core/sheets/google_auth_service.dart';
import 'core/sheets/sync_queue.dart';
import 'core/storage/hive_storage.dart';
import 'core/storage/secure_storage.dart';
import 'features/calendar/calendar_page.dart';
import 'features/scan/scan_page.dart';
import 'features/settings/settings_page.dart';
import 'features/statistics/statistics_page.dart';
import 'features/transactions/transactions_page.dart';

/// 앱 전역 의존성을 트리에 노출하는 InheritedWidget.
///
/// 자식 위젯에서 `AppDeps.of(context).hive` 식으로 접근.
/// Phase 0 의 DI 패턴(BlocProvider 안에서 직접 instantiate)을 대체.
class AppDeps extends InheritedWidget {
  final HiveStorage hive;
  final SecureStorage secureStorage;
  final Dio dio;
  final CodexOAuth oauth;
  final CodexProvider codex;
  final GeminiProvider gemini;
  final GoogleAuthService googleAuth;
  final SyncQueue syncQueue;

  const AppDeps({
    super.key,
    required this.hive,
    required this.secureStorage,
    required this.dio,
    required this.oauth,
    required this.codex,
    required this.gemini,
    required this.googleAuth,
    required this.syncQueue,
    required super.child,
  });

  static AppDeps of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<AppDeps>();
    assert(w != null, 'AppDeps not found in widget tree — wrap with AppDeps.');
    return w!;
  }

  @override
  bool updateShouldNotify(AppDeps old) =>
      hive != old.hive ||
      secureStorage != old.secureStorage ||
      dio != old.dio ||
      oauth != old.oauth ||
      codex != old.codex ||
      gemini != old.gemini ||
      googleAuth != old.googleAuth ||
      syncQueue != old.syncQueue;
}

class RootShellScope extends InheritedWidget {
  final int selectedIndex;
  final ValueChanged<int> selectTab;

  const RootShellScope({
    super.key,
    required this.selectedIndex,
    required this.selectTab,
    required super.child,
  });

  static RootShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RootShellScope>();
  }

  static RootShellScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'RootShellScope not found in widget tree.');
    return scope!;
  }

  @override
  bool updateShouldNotify(RootShellScope oldWidget) {
    return selectedIndex != oldWidget.selectedIndex ||
        selectTab != oldWidget.selectTab;
  }
}

/// 5탭 BottomNavigationBar 셸. 아키텍처 §9.
/// 📷 스캔 / 📋 내역 / 📅 달력 / 📊 통계 / ⚙️ 설정
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  // IndexedStack 으로 탭 전환 시 state 보존.
  static const List<Widget> _pages = [
    ScanPage(),
    TransactionsPage(),
    CalendarPage(),
    StatisticsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return RootShellScope(
      selectedIndex: _index,
      selectTab: (i) => setState(() => _index = i),
      child: Scaffold(
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.camera_alt_outlined),
              selectedIcon: Icon(Icons.camera_alt),
              label: '스캔',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: '내역',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: '달력',
            ),
            NavigationDestination(
              icon: Icon(Icons.pie_chart_outline),
              selectedIcon: Icon(Icons.pie_chart),
              label: '통계',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }
}
