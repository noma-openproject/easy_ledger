import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../app.dart';
import '../../core/ai/ai_provider.dart';
import '../../core/utils/image_utils.dart';
import '../manual_input/manual_input_page.dart';
import 'receipt_draft.dart';
import 'receipt_save_builder.dart';
import 'scan_cubit.dart';

enum BatchEntryStatus { waiting, processing, success, failure, saved }

class BatchScanPage extends StatefulWidget {
  const BatchScanPage({super.key});

  @override
  State<BatchScanPage> createState() => _BatchScanPageState();
}

class _BatchScanPageState extends State<BatchScanPage> {
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  ScanProviderKind _provider = ScanProviderKind.codex;
  bool _codexAvailable = false;
  bool _geminiAvailable = false;
  bool _processing = false;
  bool _saving = false;
  bool _loadedDependencies = false;
  String? _errorText;
  List<_BatchEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedDependencies) return;
    _loadedDependencies = true;
    _refreshCredentials();
  }

  @override
  Widget build(BuildContext context) {
    final successful = _entries.where(
      (entry) => entry.status == BatchEntryStatus.success,
    );
    final selectedCount = successful.where((entry) => entry.selected).length;
    final unsavedCount = successful.where((entry) => !entry.saved).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
      children: [
        _HeroCard(processing: _processing, statusCount: _entries.length),
        const SizedBox(height: 16),
        _BatchProviderSelector(
          provider: _provider,
          codexAvailable: _codexAvailable,
          geminiAvailable: _geminiAvailable,
          enabled: !_processing && !_saving,
          onChanged: (value) => setState(() => _provider = value),
          onRefresh: _refreshCredentials,
        ),
        const SizedBox(height: 16),
        _BatchPickButtons(
          enabled: !_processing && !_saving,
          onPickGallery: _pickFromGallery,
          onPickFiles: _pickFromFiles,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _entries.isEmpty || _processing || _saving
                    ? null
                    : _processEntries,
                icon: _processing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high),
                label: Text(_processing ? '배치 처리 중...' : '배치 AI 추출'),
              ),
            ),
          ],
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 16),
          _BatchErrorCard(message: _errorText!),
        ],
        if (_entries.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '선택 저장 $selectedCount건 / 성공 $unsavedCount건',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton(
                onPressed: successful.isEmpty || _saving
                    ? null
                    : _toggleAllSelection,
                child: Text(selectedCount == unsavedCount ? '모두 해제' : '모두 선택'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: selectedCount == 0 || _saving
                    ? null
                    : _saveSelectedOnly,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('선택 저장'),
              ),
              OutlinedButton.icon(
                onPressed: unsavedCount == 0 || _saving
                    ? null
                    : _saveAllSuccessful,
                icon: const Icon(Icons.done_all),
                label: const Text('모두 저장'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final entry in _entries) ...[
            _BatchEntryTile(
              entry: entry,
              onSelectedChanged:
                  entry.status == BatchEntryStatus.success && !entry.saved
                  ? (value) => _setEntrySelected(entry.id, value ?? false)
                  : null,
              onRetry: entry.status == BatchEntryStatus.failure && !_processing
                  ? () => _retryEntry(entry.id)
                  : null,
              onManualInput: () => _openManualInput(context),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Future<void> _refreshCredentials() async {
    final deps = AppDeps.of(context);
    final tokens = await deps.secureStorage.readCodexTokens();
    final geminiKey = await deps.secureStorage.readGeminiKey();
    if (!mounted) return;
    setState(() {
      _codexAvailable = tokens != null;
      _geminiAvailable = geminiKey != null && geminiKey.isNotEmpty;
      if (_provider == ScanProviderKind.codex &&
          !_codexAvailable &&
          _geminiAvailable) {
        _provider = ScanProviderKind.gemini;
      }
    });
  }

  Future<void> _pickFromGallery() async {
    final files = await _picker.pickMultiImage();
    if (!mounted || files.isEmpty) return;
    _setPickedEntries(files.map((file) => file.path).toList());
  }

  Future<void> _pickFromFiles() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      dialogTitle: '영수증 이미지 선택 (최대 10장)',
    );
    final paths = picked?.paths.whereType<String>().toList() ?? const [];
    if (!mounted || paths.isEmpty) return;
    _setPickedEntries(paths);
  }

  void _setPickedEntries(List<String> paths) {
    final limited = paths.take(10).toList();
    setState(() {
      _entries = [
        for (final path in limited)
          _BatchEntry(
            id: _uuid.v4(),
            sourcePath: path,
            status: BatchEntryStatus.waiting,
          ),
      ];
      _errorText = paths.length > 10 ? '최대 10장까지만 선택할 수 있습니다.' : null;
    });
  }

  Future<void> _processEntries() async {
    final provider = _currentProviderOrNull();
    if (provider == null) return;

    final targetIds = _entries
        .where(
          (entry) =>
              entry.status == BatchEntryStatus.waiting ||
              entry.status == BatchEntryStatus.failure,
        )
        .map((entry) => entry.id)
        .toList();
    if (targetIds.isEmpty) return;

    setState(() => _processing = true);
    var cursor = 0;

    Future<void> worker() async {
      while (cursor < targetIds.length) {
        final current = targetIds[cursor];
        cursor += 1;
        await _processEntry(current, provider);
      }
    }

    final workerCount = math.min(3, targetIds.length);
    await Future.wait([for (var i = 0; i < workerCount; i++) worker()]);

    if (!mounted) return;
    setState(() => _processing = false);
  }

  Future<void> _processEntry(String entryId, AiProvider provider) async {
    _updateEntry(
      entryId,
      (entry) => entry.copyWith(
        status: BatchEntryStatus.processing,
        errorText: null,
        extraction: null,
        processedImagePath: null,
        saved: false,
      ),
    );

    try {
      final source = File(_entryById(entryId).sourcePath);
      final processed = await _resizeIntoAppStorage(source);
      final extraction = await _extractWithFallback(provider, processed);
      _updateEntry(
        entryId,
        (entry) => entry.copyWith(
          processedImagePath: processed.path,
          extraction: extraction,
          status: BatchEntryStatus.success,
          selected: true,
          errorText: null,
        ),
      );
    } catch (e) {
      _updateEntry(
        entryId,
        (entry) => entry.copyWith(
          status: BatchEntryStatus.failure,
          errorText: _friendlyExtractionError(e),
        ),
      );
    }
  }

  Future<void> _retryEntry(String entryId) async {
    final provider = _currentProviderOrNull();
    if (provider == null) return;
    setState(() => _processing = true);
    await _processEntry(entryId, provider);
    if (!mounted) return;
    setState(() => _processing = false);
  }

  Future<void> _saveSelectedOnly() async {
    await _saveEntries(
      _entries
          .where(
            (entry) =>
                entry.status == BatchEntryStatus.success &&
                entry.selected &&
                !entry.saved,
          )
          .map((entry) => entry.id)
          .toList(),
    );
  }

  Future<void> _saveAllSuccessful() async {
    await _saveEntries(
      _entries
          .where(
            (entry) => entry.status == BatchEntryStatus.success && !entry.saved,
          )
          .map((entry) => entry.id)
          .toList(),
    );
  }

  Future<void> _saveEntries(List<String> entryIds) async {
    if (entryIds.isEmpty) return;
    final deps = AppDeps.of(context);
    setState(() => _saving = true);
    var savedCount = 0;
    try {
      for (final id in entryIds) {
        final entry = _entryById(id);
        if (entry.extraction == null || entry.processedImagePath == null) {
          continue;
        }
        final payload = buildReceiptSavePayload(
          extraction: entry.extraction!,
          imagePath: entry.processedImagePath!,
          defaultExpenseType: deps.hive.defaultExpenseType,
          uuid: _uuid,
        );
        await deps.hive.saveScanResult(
          receipt: payload.receipt,
          transaction: payload.transaction,
          items: payload.items,
        );
        await deps.syncQueue.enqueueIfConfigured(payload.transaction.id);
        savedCount += 1;
        _updateEntry(
          id,
          (current) => current.copyWith(
            status: BatchEntryStatus.saved,
            saved: true,
            selected: false,
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$savedCount건 저장 완료')));
      RootShellScope.maybeOf(context)?.selectTab(1);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = '배치 저장 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _toggleAllSelection() {
    final successful = _entries.where(
      (entry) => entry.status == BatchEntryStatus.success && !entry.saved,
    );
    final shouldSelectAll = successful.any((entry) => !entry.selected);
    setState(() {
      _entries = [
        for (final entry in _entries)
          if (entry.status == BatchEntryStatus.success && !entry.saved)
            entry.copyWith(selected: shouldSelectAll)
          else
            entry,
      ];
    });
  }

  void _setEntrySelected(String entryId, bool selected) {
    _updateEntry(entryId, (entry) => entry.copyWith(selected: selected));
  }

  AiProvider? _currentProviderOrNull() {
    final deps = AppDeps.of(context);
    if (_provider == ScanProviderKind.codex) {
      if (!_codexAvailable) {
        setState(() {
          _errorText = 'ChatGPT 로그인이 필요합니다. 설정 탭에서 먼저 로그인하세요.';
        });
        return null;
      }
      return deps.codex;
    }
    if (!_geminiAvailable) {
      setState(() {
        _errorText = 'Gemini API Key가 필요합니다. 설정 탭에서 먼저 저장하세요.';
      });
      return null;
    }
    return deps.gemini;
  }

  Future<File> _resizeIntoAppStorage(File source) async {
    final documents = await getApplicationDocumentsDirectory();
    final destPath = p.join(documents.path, 'receipts', '${_uuid.v4()}.jpg');
    return ImageUtils.resizeAndSave(source, destPath);
  }

  Future<ReceiptExtraction> _extractWithFallback(
    AiProvider provider,
    File processed,
  ) async {
    final deps = AppDeps.of(context);
    try {
      return await provider.extractReceipt(processed);
    } catch (e) {
      final canFallbackToGemini =
          provider == deps.codex && _isCodexUsageLimit(e) && _geminiAvailable;
      if (!canFallbackToGemini) rethrow;
      try {
        return await deps.gemini.extractReceipt(processed);
      } catch (geminiError) {
        throw StateError(
          'Codex는 사용량 한도에 도달했고, Gemini fallback도 실패했습니다.\n'
          '${_friendlyExtractionError(geminiError)}',
        );
      }
    }
  }

  bool _isCodexUsageLimit(Object error) {
    final text = error.toString();
    return text.contains('HTTP 429') ||
        text.contains('usage_limit_reached') ||
        text.contains('usage limit has been reached');
  }

  String _friendlyExtractionError(Object error) {
    final text = error.toString();
    if (_isCodexUsageLimit(error)) {
      return 'Codex 사용량 한도에 도달했습니다.\n잠시 후 다시 시도하거나 Gemini로 전환하세요.';
    }
    if (text.contains('Gemini API Key')) {
      return 'Gemini API Key가 없습니다. 설정 탭에서 키를 저장하세요.';
    }
    return text.replaceFirst('Bad state: ', '').trim();
  }

  _BatchEntry _entryById(String entryId) {
    return _entries.firstWhere((entry) => entry.id == entryId);
  }

  void _updateEntry(
    String entryId,
    _BatchEntry Function(_BatchEntry entry) transform,
  ) {
    if (!mounted) return;
    setState(() {
      _entries = [
        for (final entry in _entries)
          if (entry.id == entryId) transform(entry) else entry,
      ];
    });
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

class _HeroCard extends StatelessWidget {
  final bool processing;
  final int statusCount;

  const _HeroCard({required this.processing, required this.statusCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '배치 영수증 스캔',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '최대 10장을 선택하고, 동시에 최대 3건씩 AI 추출합니다.',
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
          if (statusCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              '현재 선택 $statusCount장',
              style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
            ),
          ],
          if (processing) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class _BatchProviderSelector extends StatelessWidget {
  final ScanProviderKind provider;
  final bool codexAvailable;
  final bool geminiAvailable;
  final bool enabled;
  final ValueChanged<ScanProviderKind> onChanged;
  final Future<void> Function() onRefresh;

  const _BatchProviderSelector({
    required this.provider,
    required this.codexAvailable,
    required this.geminiAvailable,
    required this.enabled,
    required this.onChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<ScanProviderKind>(
            segments: [
              ButtonSegment(
                value: ScanProviderKind.codex,
                label: Text(codexAvailable ? 'Codex' : 'Codex 필요'),
                icon: Icon(codexAvailable ? Icons.bolt : Icons.lock_outline),
              ),
              ButtonSegment(
                value: ScanProviderKind.gemini,
                label: Text(geminiAvailable ? 'Gemini' : 'Gemini 필요'),
                icon: Icon(
                  geminiAvailable ? Icons.auto_awesome : Icons.key_off_outlined,
                ),
              ),
            ],
            selected: {provider},
            onSelectionChanged: enabled ? (set) => onChanged(set.first) : null,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: '연결 상태 새로고침',
          onPressed: enabled ? () => onRefresh() : null,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _BatchPickButtons extends StatelessWidget {
  final bool enabled;
  final Future<void> Function() onPickGallery;
  final Future<void> Function() onPickFiles;

  const _BatchPickButtons({
    required this.enabled,
    required this.onPickGallery,
    required this.onPickFiles,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Platform.isAndroid || Platform.isIOS;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (isMobile)
          FilledButton.icon(
            onPressed: enabled ? () => onPickGallery() : null,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('앨범에서 여러 장'),
          ),
        FilledButton.tonalIcon(
          onPressed: enabled ? () => onPickFiles() : null,
          icon: const Icon(Icons.collections_outlined),
          label: const Text('파일 여러 장 선택'),
        ),
      ],
    );
  }
}

class _BatchEntryTile extends StatelessWidget {
  final _BatchEntry entry;
  final ValueChanged<bool?>? onSelectedChanged;
  final VoidCallback? onRetry;
  final VoidCallback onManualInput;

  const _BatchEntryTile({
    required this.entry,
    required this.onSelectedChanged,
    required this.onRetry,
    required this.onManualInput,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = entry.processedImagePath ?? entry.sourcePath;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onSelectedChanged != null)
                Checkbox(value: entry.selected, onChanged: onSelectedChanged)
              else
                _StatusDot(status: entry.status),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.basename(entry.sourcePath),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _StatusChip(status: entry.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(imagePath),
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 84,
                    height: 84,
                    color: Colors.grey[200],
                    alignment: Alignment.center,
                    child: const Text('미리보기\n불가', textAlign: TextAlign.center),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.extraction != null)
                      Text(
                        '${ReceiptDraft.fromExtraction(entry.extraction!).storeName} · '
                        '${ReceiptDraft.fromExtraction(entry.extraction!).total}원',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    if (entry.errorText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.errorText!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                    if (entry.status == BatchEntryStatus.failure) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('재시도'),
                          ),
                          TextButton.icon(
                            onPressed: onManualInput,
                            icon: const Icon(Icons.edit_note),
                            label: const Text('수동 입력으로 전환'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BatchErrorCard extends StatelessWidget {
  final String message;

  const _BatchErrorCard({required this.message});

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
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final BatchEntryStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BatchEntryStatus.waiting => ('대기', Colors.grey),
      BatchEntryStatus.processing => ('처리중', Colors.blue),
      BatchEntryStatus.success => ('성공', Colors.green),
      BatchEntryStatus.failure => ('실패', Colors.red),
      BatchEntryStatus.saved => ('저장됨', Colors.teal),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final BatchEntryStatus status;

  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      BatchEntryStatus.waiting => Colors.grey,
      BatchEntryStatus.processing => Colors.blue,
      BatchEntryStatus.success => Colors.green,
      BatchEntryStatus.failure => Colors.red,
      BatchEntryStatus.saved => Colors.teal,
    };
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _BatchEntry {
  final String id;
  final String sourcePath;
  final String? processedImagePath;
  final ReceiptExtraction? extraction;
  final BatchEntryStatus status;
  final String? errorText;
  final bool selected;
  final bool saved;

  const _BatchEntry({
    required this.id,
    required this.sourcePath,
    this.processedImagePath,
    this.extraction,
    required this.status,
    this.errorText,
    this.selected = false,
    this.saved = false,
  });

  _BatchEntry copyWith({
    String? id,
    String? sourcePath,
    Object? processedImagePath = _sentinel,
    Object? extraction = _sentinel,
    BatchEntryStatus? status,
    Object? errorText = _sentinel,
    bool? selected,
    bool? saved,
  }) {
    return _BatchEntry(
      id: id ?? this.id,
      sourcePath: sourcePath ?? this.sourcePath,
      processedImagePath: identical(processedImagePath, _sentinel)
          ? this.processedImagePath
          : processedImagePath as String?,
      extraction: identical(extraction, _sentinel)
          ? this.extraction
          : extraction as ReceiptExtraction?,
      status: status ?? this.status,
      errorText: identical(errorText, _sentinel)
          ? this.errorText
          : errorText as String?,
      selected: selected ?? this.selected,
      saved: saved ?? this.saved,
    );
  }
}

const Object _sentinel = Object();
