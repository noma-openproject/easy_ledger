import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/ai/ai_provider.dart';
import 'phase0_cubit.dart';

/// Phase 0 엔드투엔드 검증 화면.
/// 3 섹션: (1) Codex 로그인 (2) Gemini API Key (3) 영수증 추출.
class Phase0Page extends StatefulWidget {
  const Phase0Page({super.key});

  @override
  State<Phase0Page> createState() => _Phase0PageState();
}

class _Phase0PageState extends State<Phase0Page> {
  final _geminiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<Phase0Cubit>().init();
    });
  }

  @override
  void dispose() {
    _geminiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('쉬운장부 • Phase 0 Lab')),
      body: BlocBuilder<Phase0Cubit, Phase0State>(
        builder: (ctx, state) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _codexSection(ctx, state),
              const SizedBox(height: 24),
              _geminiSection(ctx, state),
              const SizedBox(height: 24),
              _extractSection(ctx, state),
            ],
          );
        },
      ),
    );
  }

  Widget _codexSection(BuildContext ctx, Phase0State s) {
    final cubit = ctx.read<Phase0Cubit>();
    final isLoggedIn = s.codexStatus == CodexStatus.loggedIn;
    final isLoggingIn = s.codexStatus == CodexStatus.loggingIn;

    return _Card(
      title: '1. ChatGPT Codex 로그인',
      subtitle: 'chatgpt.com/backend-api/codex/responses 호출용 OAuth',
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
                          content: Text(
                            '토큰 만료를 강제했습니다. 다음 Codex 호출 시 refresh 흐름이 동작해야 합니다.',
                          ),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('토큰 강제만료 (디버그)'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _geminiSection(BuildContext ctx, Phase0State s) {
    final cubit = ctx.read<Phase0Cubit>();
    return _Card(
      title: '2. Gemini API Key (fallback)',
      subtitle: 'Google AI Studio 키. 저장값은 OS 시큐어 스토리지에만 보관.',
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

  Widget _extractSection(BuildContext ctx, Phase0State s) {
    final cubit = ctx.read<Phase0Cubit>();
    final canExtract =
        s.pickedImagePath != null &&
        s.phase != ExtractPhase.running &&
        ((s.selectedProvider == ProviderKind.codex &&
                s.codexStatus == CodexStatus.loggedIn) ||
            (s.selectedProvider == ProviderKind.gemini && s.geminiKeySaved));

    return _Card(
      title: '3. 영수증 → JSON 추출',
      subtitle: '이미지 선택 → provider 선택 → 추출',
      children: [
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: () async {
                final r = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  dialogTitle: '영수증 이미지 선택',
                );
                final path = r?.files.first.path;
                if (path != null) cubit.setPickedImagePath(path);
              },
              icon: const Icon(Icons.image_outlined),
              label: const Text('이미지 선택'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s.pickedImagePath ?? '선택된 파일 없음',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          ],
        ),
        if (s.pickedImagePath != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(s.pickedImagePath!),
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 160,
                color: Colors.grey[200],
                child: const Center(child: Text('이미지 미리보기 불가')),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SegmentedButton<ProviderKind>(
          segments: const [
            ButtonSegment(
              value: ProviderKind.codex,
              label: Text('Codex'),
              icon: Icon(Icons.bolt),
            ),
            ButtonSegment(
              value: ProviderKind.gemini,
              label: Text('Gemini'),
              icon: Icon(Icons.auto_awesome),
            ),
          ],
          selected: {s.selectedProvider},
          onSelectionChanged: (set) => cubit.chooseProvider(set.first),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: canExtract ? () => cubit.extract() : null,
          icon: s.phase == ExtractPhase.running
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: Text(s.phase == ExtractPhase.running ? '추출 중…' : '추출'),
        ),
        const SizedBox(height: 12),
        if (s.phase == ExtractPhase.success && s.result != null)
          _resultBlock(s.result!),
        if (s.phase == ExtractPhase.error && s.errorText != null)
          _errorBlock(s.errorText!),
      ],
    );
  }

  Widget _resultBlock(ReceiptExtraction result) {
    final parsed = result.parsed;
    final pretty = const JsonEncoder.withIndent('  ').convert(parsed);

    String? getStr(String key) {
      final v = parsed[key];
      return v?.toString();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: 6),
              Text(
                '${result.providerName} • ${result.durationMs}ms',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Divider(),
          _field('상호명', getStr('storeName')),
          _field('사업자번호', getStr('businessNumber')),
          _field('날짜', getStr('date')),
          _field('시간', getStr('time')),
          _field('합계', getStr('total')),
          _field('부가세', getStr('tax')),
          _field('결제수단', getStr('paymentMethod')),
          _field('카테고리', getStr('category')),
          _field('확신도', getStr('confidence')),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                '원본 JSON',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: pretty));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('복사됨')));
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('복사'),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              pretty,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBlock(String msg) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 18),
              const SizedBox(width: 6),
              const Text(
                '에러 전문',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: msg));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('복사됨')));
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('복사'),
              ),
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

  Widget _field(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '(null)',
              style: TextStyle(
                color: value == null ? Colors.grey[400] : Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
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
