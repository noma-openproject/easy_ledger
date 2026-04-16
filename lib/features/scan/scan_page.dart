import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app.dart';
import '../manual_input/manual_input_page.dart';
import 'batch_scan_page.dart';
import 'review_page.dart';
import 'scan_cubit.dart';

/// 스캔 탭 — Sheetify 5단계 ① Scan + ② Extract.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

enum ScanMode { single, batch }

class _ScanPageState extends State<ScanPage> {
  ScanMode _mode = ScanMode.single;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('스캔')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<ScanMode>(
                segments: const [
                  ButtonSegment(
                    value: ScanMode.single,
                    icon: Icon(Icons.filter_1),
                    label: Text('단일'),
                  ),
                  ButtonSegment(
                    value: ScanMode.batch,
                    icon: Icon(Icons.filter_frames),
                    label: Text('배치'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (set) {
                  setState(() => _mode = set.first);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _mode == ScanMode.single
                  ? const _SingleScanPane(key: ValueKey('single-scan'))
                  : const BatchScanPage(key: ValueKey('batch-scan')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SingleScanPane extends StatelessWidget {
  const _SingleScanPane({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppDeps.of(context);
    return BlocProvider(
      create: (_) => ScanCubit(
        storage: deps.secureStorage,
        hive: deps.hive,
        syncQueue: deps.syncQueue,
        codex: deps.codex,
        gemini: deps.gemini,
      )..init(),
      child: const _SingleScanBody(),
    );
  }
}

class _SingleScanBody extends StatelessWidget {
  const _SingleScanBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ScanCubit, ScanState>(
      listenWhen: (previous, current) =>
          previous.phase != current.phase &&
          (current.phase == ScanPhase.extracted ||
              current.phase == ScanPhase.autoSaved),
      listener: (context, state) {
        if (state.phase == ScanPhase.autoSaved) {
          final message = state.autoSaveMessage ?? '자동저장 완료';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          context.read<ScanCubit>().resetAfterReview();
          RootShellScope.maybeOf(context)?.selectTab(1);
          return;
        }
        if (state.extraction != null && state.processedImagePath != null) {
          _openReview(context, state);
        }
      },
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
          children: [
            _HeroPanel(state: state),
            const SizedBox(height: 16),
            _ProviderSelector(state: state),
            const SizedBox(height: 16),
            _PickButtons(state: state),
            if (state.hasImage) ...[
              const SizedBox(height: 16),
              _PreviewCard(state: state),
            ],
            const SizedBox(height: 16),
            _ExtractActions(state: state),
            if (state.errorText != null) ...[
              const SizedBox(height: 16),
              _ErrorCard(message: state.errorText!),
            ],
          ],
        );
      },
    );
  }

  Future<void> _openReview(BuildContext context, ScanState state) async {
    final extraction = state.extraction;
    final imagePath = state.processedImagePath;
    if (extraction == null || imagePath == null) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ReviewPage(extraction: extraction, imagePath: imagePath),
      ),
    );
    if (!context.mounted) return;

    context.read<ScanCubit>().resetAfterReview();
    if (saved == true) {
      RootShellScope.maybeOf(context)?.selectTab(1);
    }
  }
}

class _HeroPanel extends StatelessWidget {
  final ScanState state;
  const _HeroPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.document_scanner_outlined,
            size: 52,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '영수증 스캔',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.statusText ??
                      '이미지를 선택하면 1024px JPEG로 압축한 뒤 AI가 내용을 추출합니다.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                if (state.isBusy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderSelector extends StatelessWidget {
  final ScanState state;
  const _ProviderSelector({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ScanCubit>();
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<ScanProviderKind>(
            segments: [
              ButtonSegment(
                value: ScanProviderKind.codex,
                label: Text(state.codexAvailable ? 'Codex' : 'Codex 필요'),
                icon: Icon(
                  state.codexAvailable ? Icons.bolt : Icons.lock_outline,
                ),
              ),
              ButtonSegment(
                value: ScanProviderKind.gemini,
                label: Text(state.geminiAvailable ? 'Gemini' : 'Gemini 필요'),
                icon: Icon(
                  state.geminiAvailable
                      ? Icons.auto_awesome
                      : Icons.key_off_outlined,
                ),
              ),
            ],
            selected: {state.selectedProvider},
            onSelectionChanged: state.isBusy
                ? null
                : (set) => cubit.chooseProvider(set.first),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: '연결 상태 새로고침',
          onPressed: state.isBusy ? null : cubit.refreshCredentials,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _PickButtons extends StatelessWidget {
  final ScanState state;
  const _PickButtons({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ScanCubit>();
    final isMobile = Platform.isAndroid || Platform.isIOS;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (isMobile)
          FilledButton.icon(
            onPressed: state.isBusy ? null : cubit.pickFromCamera,
            icon: const Icon(Icons.camera_alt),
            label: const Text('촬영'),
          ),
        if (isMobile)
          FilledButton.tonalIcon(
            onPressed: state.isBusy ? null : cubit.pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('앨범'),
          ),
        FilledButton.tonalIcon(
          onPressed: state.isBusy ? null : cubit.pickFromFiles,
          icon: const Icon(Icons.image_outlined),
          label: Text(isMobile ? '파일' : '이미지 선택'),
        ),
        OutlinedButton.icon(
          onPressed: state.isBusy ? null : () => _openManualInput(context),
          icon: const Icon(Icons.edit_note),
          label: const Text('수동 입력'),
        ),
      ],
    );
  }

  Future<void> _openManualInput(BuildContext context) async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ManualInputPage()));
    if (!context.mounted) return;
    if (saved == true) {
      RootShellScope.maybeOf(context)?.selectTab(1);
    }
  }
}

class _PreviewCard extends StatelessWidget {
  final ScanState state;
  const _PreviewCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final path = state.processedImagePath ?? state.originalImagePath;
    if (path == null) return const SizedBox.shrink();
    final file = File(path);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              file,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 220,
                color: Colors.grey[200],
                child: const Center(child: Text('이미지 미리보기 불가')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtractActions extends StatelessWidget {
  final ScanState state;
  const _ExtractActions({required this.state});

  @override
  Widget build(BuildContext context) {
    final canExtract = state.originalImagePath != null && !state.isBusy;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: canExtract
                ? context.read<ScanCubit>().extractSelected
                : null,
            icon: state.isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high),
            label: Text(state.isBusy ? '처리 중...' : 'AI 추출 시작'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '추출 실패',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                SelectableText(message, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _openManualInput(context),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('수동 입력으로 전환'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openManualInput(BuildContext context) async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ManualInputPage()));
    if (!context.mounted) return;
    if (saved == true) {
      RootShellScope.maybeOf(context)?.selectTab(1);
    }
  }
}
