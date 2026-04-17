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
import 'settings_state.dart';

part 'settings_page_sections.dart';
part 'settings_page_dialogs.dart';

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
}
