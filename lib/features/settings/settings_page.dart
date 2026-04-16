import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';

import '../../app.dart';
import '../../core/export/backup_service.dart';
import '../../core/utils/format_utils.dart';
import '../budget/budget_page.dart';
import '../phase0_lab/phase0_cubit.dart' as p0;
import '../phase0_lab/phase0_page.dart';
import 'category_manager_page.dart';
import 'settings_cubit.dart';

/// 설정 탭 — ChatGPT OAuth + Gemini API Key + 디버그 도구.
/// §17 단계 1-2: Phase 0 lab 의 OAuth/Gemini 부분을 여기로 이동.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppDeps.of(context);
    return BlocProvider(
      create: (_) => SettingsCubit(
        storage: deps.secureStorage,
        oauth: deps.oauth,
        hive: deps.hive,
        googleAuth: deps.googleAuth,
        syncQueue: deps.syncQueue,
      )..init(),
      child: const _SettingsBody(),
    );
  }
}

class _SettingsBody extends StatefulWidget {
  const _SettingsBody();

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  final _geminiController = TextEditingController();
  final _sheetIdController = TextEditingController();
  String? _lastSheetId;

  @override
  void dispose() {
    _geminiController.dispose();
    _sheetIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (ctx, s) {
          if (_lastSheetId != s.sheetId) {
            _lastSheetId = s.sheetId;
            _sheetIdController.text = s.sheetId ?? '';
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _codexSection(ctx, s),
              const SizedBox(height: 24),
              _geminiSection(ctx, s),
              const SizedBox(height: 24),
              _googleSheetsSection(ctx, s),
              const SizedBox(height: 24),
              _categorySection(ctx),
              const SizedBox(height: 24),
              _budgetSection(ctx),
              const SizedBox(height: 24),
              _generalSection(ctx, s),
              const SizedBox(height: 24),
              _exportSection(ctx, s),
              const SizedBox(height: 24),
              _dataSection(ctx, s),
              const SizedBox(height: 24),
              _devToolsSection(ctx),
              if (s.errorText != null) ...[
                const SizedBox(height: 16),
                _errorBlock(s.errorText!),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _categorySection(BuildContext ctx) {
    final hive = AppDeps.of(ctx).hive;
    return AnimatedBuilder(
      animation: hive.listenable,
      builder: (context, _) {
        return _Card(
          title: '카테고리 관리',
          subtitle: '기본 카테고리와 직접 추가한 분류를 관리합니다.',
          children: [
            Row(
              children: [
                const Icon(Icons.category_outlined),
                const SizedBox(width: 8),
                Expanded(child: Text('카테고리 ${hive.categories().length}개')),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => const CategoryManagerPage(),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('편집'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _googleSheetsSection(BuildContext ctx, SettingsState s) {
    final cubit = ctx.read<SettingsCubit>();
    final isSignedIn = s.googleStatus == GoogleStatus.signedIn;
    final isSigningIn = s.googleStatus == GoogleStatus.signingIn;
    return _Card(
      title: '팀 공유 (Google Sheets)',
      subtitle: '공유 시트에 저장 거래를 행으로 추가합니다.',
      children: [
        Row(
          children: [
            Icon(
              isSignedIn ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSignedIn ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isSignedIn
                    ? '구글 계정: ${s.googleEmail ?? "로그인됨"}'
                    : '구글 계정이 연결되지 않았습니다.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: isSigningIn ? null : cubit.loginGoogle,
              icon: isSigningIn
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(isSigningIn ? '로그인 중...' : 'Google 로그인'),
            ),
            OutlinedButton.icon(
              onPressed: isSignedIn ? cubit.logoutGoogle : null,
              icon: const Icon(Icons.logout),
              label: const Text('로그아웃'),
            ),
            OutlinedButton.icon(
              onPressed: s.testingSheet ? null : cubit.processSyncQueueNow,
              icon: const Icon(Icons.sync),
              label: Text('지금 동기화 (${s.syncPendingCount})'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _sheetIdController,
          decoration: const InputDecoration(
            labelText: '시트 ID 또는 Google Sheets URL',
            helperText: 'URL의 /d/{시트ID}/edit 부분을 붙여넣어도 됩니다.',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.table_chart_outlined),
          ),
          onChanged: cubit.saveSheetId,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('자동 동기화'),
          subtitle: const Text('저장된 거래를 온라인 상태에서 시트로 보냅니다.'),
          value: s.autoSyncEnabled,
          onChanged: cubit.setAutoSyncEnabled,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: s.testingSheet
                  ? null
                  : () => cubit.testSheetConnection(_sheetIdController.text),
              icon: s.testingSheet
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fact_check_outlined),
              label: Text(s.testingSheet ? '확인 중...' : '연결 테스트'),
            ),
          ],
        ),
        if (s.sheetTestMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            s.sheetTestMessage!,
            style: TextStyle(
              color: s.sheetTestMessage!.startsWith('연결 성공')
                  ? Colors.green[700]
                  : Colors.red[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _budgetSection(BuildContext ctx) {
    return _Card(
      title: '예산 관리',
      subtitle: '카테고리별 월 예산을 설정하고 통계 탭에서 진행률을 확인합니다.',
      children: [
        Row(
          children: [
            const Icon(Icons.savings_outlined),
            const SizedBox(width: 8),
            const Expanded(child: Text('월 예산 설정')),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(
                ctx,
              ).push(MaterialPageRoute(builder: (_) => const BudgetPage())),
              icon: const Icon(Icons.chevron_right),
              label: const Text('열기'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _generalSection(BuildContext ctx, SettingsState s) {
    final cubit = ctx.read<SettingsCubit>();
    return _Card(
      title: '일반 설정',
      subtitle: '입력 기본값과 자동저장 동작을 정합니다.',
      children: [
        DropdownButtonFormField<int>(
          initialValue: s.monthStartDay,
          decoration: const InputDecoration(
            labelText: '월 시작일',
            border: OutlineInputBorder(),
          ),
          items: [
            for (var day = 1; day <= 28; day++)
              DropdownMenuItem(value: day, child: Text('$day일')),
          ],
          onChanged: (value) {
            if (value != null) cubit.setMonthStartDay(value);
          },
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'personal',
              label: Text('개인지출'),
              icon: Icon(Icons.person_outline),
            ),
            ButtonSegment(
              value: 'business',
              label: Text('사업경비'),
              icon: Icon(Icons.business_center_outlined),
            ),
          ],
          selected: {s.defaultExpenseType},
          onSelectionChanged: (set) => cubit.setDefaultExpenseType(set.first),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('자동저장'),
          subtitle: const Text('AI confidence 90% 이상이면 리뷰 없이 바로 저장'),
          value: s.autoSaveEnabled,
          onChanged: cubit.setAutoSaveEnabled,
        ),
      ],
    );
  }

  Widget _dataSection(BuildContext ctx, SettingsState s) {
    return AnimatedBuilder(
      animation: AppDeps.of(ctx).hive.listenable,
      builder: (context, _) {
        final hive = AppDeps.of(ctx).hive;
        return _Card(
          title: '데이터',
          subtitle: '현재 기기에 저장된 Hive 데이터 현황',
          children: [
            _DataRow('거래', '${hive.transactionCount}건'),
            _DataRow('이미지', '${hive.receiptCount}장'),
            _DataRow('품목', '${hive.itemCount}건'),
            _DataRow('기본 경비 태그', expenseTypeLabel(s.defaultExpenseType)),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: s.backupBusy
                      ? null
                      : () => ctx.read<SettingsCubit>().createBackup(),
                  icon: s.backupBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.backup_outlined),
                  label: const Text('백업 생성'),
                ),
                OutlinedButton.icon(
                  onPressed: s.backupBusy
                      ? null
                      : () => _pickAndRestoreBackup(ctx),
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('백업 복원'),
                ),
                OutlinedButton.icon(
                  onPressed: s.backupBusy
                      ? null
                      : () => _confirmDeleteAllData(ctx),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('전체 삭제'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _exportSection(BuildContext ctx, SettingsState s) {
    return _Card(
      title: '내보내기',
      subtitle: '간편장부 양식 .xlsx 파일을 만들고 공유합니다.',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: s.exportingLedger
                  ? null
                  : () => _promptLedgerExport(ctx, monthly: false),
              icon: s.exportingLedger
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined),
              label: const Text('연간 간편장부'),
            ),
            OutlinedButton.icon(
              onPressed: s.exportingLedger
                  ? null
                  : () => _promptLedgerExport(ctx, monthly: true),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('월별 내보내기'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _promptLedgerExport(
    BuildContext context, {
    required bool monthly,
  }) async {
    final now = DateTime.now();
    final yearController = TextEditingController(text: now.year.toString());
    final monthController = TextEditingController(text: now.month.toString());
    try {
      final result = await showDialog<({int year, int? month})>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(monthly ? '월별 내보내기' : '연간 간편장부 내보내기'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '연도',
                  border: OutlineInputBorder(),
                ),
              ),
              if (monthly) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: monthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '월',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final year = int.tryParse(yearController.text.trim());
                final month = monthly
                    ? int.tryParse(monthController.text.trim())
                    : null;
                if (year == null ||
                    year < 2000 ||
                    year > 2100 ||
                    (monthly && (month == null || month < 1 || month > 12))) {
                  return;
                }
                Navigator.of(
                  dialogContext,
                ).pop((year: year, month: monthly ? month : null));
              },
              child: const Text('내보내기'),
            ),
          ],
        ),
      );
      if (result == null || !context.mounted) return;
      await context.read<SettingsCubit>().exportSimpleLedger(
        year: result.year,
        month: result.month,
      );
    } finally {
      yearController.dispose();
      monthController.dispose();
    }
  }

  Future<void> _pickAndRestoreBackup(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: false,
    );
    if (picked == null || picked.files.isEmpty || !context.mounted) return;
    final path = picked.files.single.path;
    if (path == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('선택한 백업 파일 경로를 읽을 수 없습니다.')));
      return;
    }
    final mode = await showDialog<BackupRestoreMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('백업 복원 방식'),
        content: const Text('현재 데이터를 유지하며 병합하거나, 현재 데이터를 지우고 백업으로 덮어쓸 수 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          OutlinedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(BackupRestoreMode.merge),
            child: const Text('병합'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(BackupRestoreMode.overwrite),
            child: const Text('덮어쓰기'),
          ),
        ],
      ),
    );
    if (mode == null || !context.mounted) return;
    await context.read<SettingsCubit>().restoreBackup(path, mode: mode);
  }

  Future<void> _confirmDeleteAllData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('전체 데이터 삭제'),
        content: const Text('거래, 영수증 이미지, 품목, 동기화 대기열, 설정을 이 기기에서 삭제합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<SettingsCubit>().deleteAllData();
  }

  Widget _codexSection(BuildContext ctx, SettingsState s) {
    final cubit = ctx.read<SettingsCubit>();
    final isLoggedIn = s.codexStatus == CodexStatus.loggedIn;
    final isLoggingIn = s.codexStatus == CodexStatus.loggingIn;
    return _Card(
      title: 'ChatGPT 연결',
      subtitle: 'Codex(GPT-5) 영수증 추출용 OAuth',
      children: [
        Row(
          children: [
            Icon(
              isLoggedIn ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isLoggedIn ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              isLoggedIn
                  ? '로그인됨 (account: ${s.accountIdShort ?? "?"})'
                  : '로그인되지 않음',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: isLoggingIn ? null : () => cubit.loginCodex(),
              icon: isLoggingIn
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(isLoggingIn ? '브라우저에서 로그인 대기 중…' : 'ChatGPT 로그인'),
            ),
            OutlinedButton.icon(
              onPressed: isLoggedIn ? () => cubit.logoutCodex() : null,
              icon: const Icon(Icons.logout),
              label: const Text('로그아웃'),
            ),
            TextButton.icon(
              onPressed: isLoggedIn
                  ? () async {
                      await cubit.debugExpireCodexToken();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('토큰 만료 강제. 다음 호출 시 refresh 흐름 동작.'),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('토큰 강제만료'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _geminiSection(BuildContext ctx, SettingsState s) {
    final cubit = ctx.read<SettingsCubit>();
    return _Card(
      title: 'Gemini API Key (fallback)',
      subtitle: 'Google AI Studio 키. OS 시큐어 스토리지에 보관.',
      children: [
        Row(
          children: [
            Icon(
              s.geminiKeySaved
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: s.geminiKeySaved ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(s.geminiKeySaved ? '저장됨' : '저장되지 않음'),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _geminiController,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'AIza... 로 시작하는 API 키',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.key),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: () async {
                await cubit.saveGeminiKey(_geminiController.text);
                _geminiController.clear();
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('저장 완료')));
              },
              child: const Text('저장'),
            ),
            OutlinedButton(
              onPressed: s.geminiKeySaved
                  ? () async {
                      await cubit.saveGeminiKey('');
                      if (!mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('삭제 완료')));
                    }
                  : null,
              child: const Text('삭제'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _devToolsSection(BuildContext ctx) {
    final deps = AppDeps.of(ctx);
    return _Card(
      title: '개발자 도구',
      subtitle: 'Phase 0 lab — OAuth/Codex/Gemini 영수증 직접 호출 디버깅',
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.science_outlined),
          label: const Text('Phase 0 Lab 열기'),
          onPressed: () {
            Navigator.of(ctx).push(
              MaterialPageRoute(
                builder: (_) => BlocProvider(
                  create: (_) => p0.Phase0Cubit(
                    storage: deps.secureStorage,
                    oauth: deps.oauth,
                    codex: deps.codex,
                    gemini: deps.gemini,
                  ),
                  child: const Phase0Page(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _errorBlock(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 18),
              SizedBox(width: 6),
              Text('에러', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            msg,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;

  const _DataRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const _Card({required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
