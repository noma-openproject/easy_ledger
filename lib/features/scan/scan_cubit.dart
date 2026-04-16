import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/ai/ai_provider.dart';
import '../../core/ai/codex_provider.dart';
import '../../core/ai/gemini_provider.dart';
import '../../core/sheets/sync_queue.dart';
import '../../core/storage/hive_storage.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/utils/image_utils.dart';
import 'receipt_draft.dart';
import 'receipt_save_builder.dart';

enum ScanProviderKind { codex, gemini }

enum ScanPhase {
  idle,
  picking,
  selected,
  preprocessing,
  extracting,
  extracted,
  autoSaved,
  error,
}

class ScanState {
  final ScanProviderKind selectedProvider;
  final ScanPhase phase;
  final bool codexAvailable;
  final bool geminiAvailable;
  final String? originalImagePath;
  final String? processedImagePath;
  final ReceiptExtraction? extraction;
  final String? statusText;
  final String? errorText;
  final String? autoSaveMessage;

  const ScanState({
    required this.selectedProvider,
    required this.phase,
    required this.codexAvailable,
    required this.geminiAvailable,
    this.originalImagePath,
    this.processedImagePath,
    this.extraction,
    this.statusText,
    this.errorText,
    this.autoSaveMessage,
  });

  factory ScanState.initial() => const ScanState(
    selectedProvider: ScanProviderKind.codex,
    phase: ScanPhase.idle,
    codexAvailable: false,
    geminiAvailable: false,
  );

  bool get isBusy =>
      phase == ScanPhase.picking ||
      phase == ScanPhase.preprocessing ||
      phase == ScanPhase.extracting;

  bool get hasImage => originalImagePath != null || processedImagePath != null;

  ScanState copyWith({
    ScanProviderKind? selectedProvider,
    ScanPhase? phase,
    bool? codexAvailable,
    bool? geminiAvailable,
    Object? originalImagePath = _sentinel,
    Object? processedImagePath = _sentinel,
    Object? extraction = _sentinel,
    Object? statusText = _sentinel,
    Object? errorText = _sentinel,
    Object? autoSaveMessage = _sentinel,
  }) {
    return ScanState(
      selectedProvider: selectedProvider ?? this.selectedProvider,
      phase: phase ?? this.phase,
      codexAvailable: codexAvailable ?? this.codexAvailable,
      geminiAvailable: geminiAvailable ?? this.geminiAvailable,
      originalImagePath: identical(originalImagePath, _sentinel)
          ? this.originalImagePath
          : originalImagePath as String?,
      processedImagePath: identical(processedImagePath, _sentinel)
          ? this.processedImagePath
          : processedImagePath as String?,
      extraction: identical(extraction, _sentinel)
          ? this.extraction
          : extraction as ReceiptExtraction?,
      statusText: identical(statusText, _sentinel)
          ? this.statusText
          : statusText as String?,
      errorText: identical(errorText, _sentinel)
          ? this.errorText
          : errorText as String?,
      autoSaveMessage: identical(autoSaveMessage, _sentinel)
          ? this.autoSaveMessage
          : autoSaveMessage as String?,
    );
  }
}

const Object _sentinel = Object();

class ScanCubit extends Cubit<ScanState> {
  final SecureStorage _storage;
  final HiveStorage _hive;
  final SyncQueue _syncQueue;
  final CodexProvider _codex;
  final GeminiProvider _gemini;
  final ImagePicker _imagePicker;
  final Uuid _uuid;

  ScanCubit({
    required SecureStorage storage,
    required HiveStorage hive,
    required SyncQueue syncQueue,
    required CodexProvider codex,
    required GeminiProvider gemini,
    ImagePicker? imagePicker,
    Uuid? uuid,
  }) : _storage = storage,
       _hive = hive,
       _syncQueue = syncQueue,
       _codex = codex,
       _gemini = gemini,
       _imagePicker = imagePicker ?? ImagePicker(),
       _uuid = uuid ?? const Uuid(),
       super(ScanState.initial());

  Future<void> init() async {
    await refreshCredentials();
  }

  Future<void> refreshCredentials() async {
    final tokens = await _storage.readCodexTokens();
    final geminiKey = await _storage.readGeminiKey();
    final codexAvailable = tokens != null;
    final geminiAvailable = geminiKey != null && geminiKey.isNotEmpty;
    var selected = state.selectedProvider;
    if (selected == ScanProviderKind.codex &&
        !codexAvailable &&
        geminiAvailable) {
      selected = ScanProviderKind.gemini;
    }
    emit(
      state.copyWith(
        selectedProvider: selected,
        codexAvailable: codexAvailable,
        geminiAvailable: geminiAvailable,
      ),
    );
  }

  void chooseProvider(ScanProviderKind provider) {
    emit(state.copyWith(selectedProvider: provider, errorText: null));
  }

  Future<void> pickFromCamera() async {
    await _pickWithImagePicker(ImageSource.camera);
  }

  Future<void> pickFromGallery() async {
    await _pickWithImagePicker(ImageSource.gallery);
  }

  Future<void> pickFromFiles() async {
    if (state.isBusy) return;
    emit(
      state.copyWith(
        phase: ScanPhase.picking,
        statusText: '이미지 선택 중...',
        errorText: null,
        autoSaveMessage: null,
        extraction: null,
      ),
    );
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        dialogTitle: '영수증 이미지 선택',
      );
      final path = picked?.files.first.path;
      if (path == null) {
        emit(state.copyWith(phase: ScanPhase.idle, statusText: null));
        return;
      }
      await _setPickedImage(path);
    } catch (e, st) {
      emit(
        state.copyWith(
          phase: ScanPhase.error,
          statusText: null,
          errorText: '이미지 선택 실패:\n$e\n\n$st',
        ),
      );
    }
  }

  Future<void> extractSelected() async {
    final sourcePath = state.originalImagePath;
    if (sourcePath == null) {
      emit(state.copyWith(errorText: '영수증 이미지를 먼저 선택하세요.'));
      return;
    }

    await refreshCredentials();
    final provider = _currentProviderOrNull();
    if (provider == null) return;

    emit(
      state.copyWith(
        phase: ScanPhase.preprocessing,
        statusText: '이미지를 1024px JPEG로 압축 중...',
        errorText: null,
        extraction: null,
        autoSaveMessage: null,
      ),
    );

    try {
      final source = File(sourcePath);
      if (!await source.exists()) {
        throw StateError('파일이 존재하지 않습니다: $sourcePath');
      }
      final processed = await _resizeIntoAppStorage(source);

      emit(
        state.copyWith(
          phase: ScanPhase.extracting,
          processedImagePath: processed.path,
          statusText: '${provider.name}로 영수증을 추출 중...',
        ),
      );

      final extraction = await _extractWithFallback(provider, processed);
      final draft = ReceiptDraft.fromExtraction(extraction);
      if (_hive.autoSaveEnabled && draft.confidence >= 0.9) {
        final payload = buildReceiptSavePayload(
          extraction: extraction,
          imagePath: processed.path,
          defaultExpenseType: _hive.defaultExpenseType,
          uuid: _uuid,
        );
        await _hive.saveScanResult(
          receipt: payload.receipt,
          transaction: payload.transaction,
          items: payload.items,
        );
        await _syncQueue.enqueueIfConfigured(payload.transaction.id);
        emit(
          state.copyWith(
            phase: ScanPhase.autoSaved,
            processedImagePath: processed.path,
            extraction: extraction,
            statusText: '자동저장 완료',
            autoSaveMessage: payload.summary,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          phase: ScanPhase.extracted,
          processedImagePath: processed.path,
          extraction: extraction,
          statusText: '추출 완료',
          autoSaveMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          phase: ScanPhase.error,
          statusText: null,
          errorText: _friendlyExtractionError(e),
        ),
      );
    }
  }

  void resetAfterReview() {
    emit(
      state.copyWith(
        phase: ScanPhase.idle,
        originalImagePath: null,
        processedImagePath: null,
        extraction: null,
        statusText: null,
        errorText: null,
        autoSaveMessage: null,
      ),
    );
  }

  Future<void> _pickWithImagePicker(ImageSource source) async {
    if (state.isBusy) return;
    emit(
      state.copyWith(
        phase: ScanPhase.picking,
        statusText: '이미지 선택 중...',
        errorText: null,
        extraction: null,
        autoSaveMessage: null,
      ),
    );
    try {
      final picked = await _imagePicker.pickImage(source: source);
      if (picked == null) {
        emit(state.copyWith(phase: ScanPhase.idle, statusText: null));
        return;
      }
      await _setPickedImage(picked.path);
    } catch (e, st) {
      emit(
        state.copyWith(
          phase: ScanPhase.error,
          statusText: null,
          errorText: '이미지 선택 실패:\n$e\n\n$st',
        ),
      );
    }
  }

  Future<void> _setPickedImage(String path) async {
    debugPrint('[Scan] picked image: $path');
    emit(
      state.copyWith(
        phase: ScanPhase.selected,
        originalImagePath: path,
        processedImagePath: null,
        extraction: null,
        statusText: '이미지 선택 완료',
        errorText: null,
        autoSaveMessage: null,
      ),
    );
  }

  AiProvider? _currentProviderOrNull() {
    if (state.selectedProvider == ScanProviderKind.codex) {
      if (!state.codexAvailable) {
        emit(
          state.copyWith(
            phase: ScanPhase.error,
            errorText: 'ChatGPT 로그인이 필요합니다. 설정 탭에서 먼저 로그인하세요.',
          ),
        );
        return null;
      }
      return _codex;
    }
    if (!state.geminiAvailable) {
      emit(
        state.copyWith(
          phase: ScanPhase.error,
          errorText: 'Gemini API Key가 필요합니다. 설정 탭에서 먼저 저장하세요.',
        ),
      );
      return null;
    }
    return _gemini;
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
    try {
      return await provider.extractReceipt(processed);
    } catch (e) {
      final canFallbackToGemini =
          provider == _codex && _isCodexUsageLimit(e) && state.geminiAvailable;
      if (!canFallbackToGemini) rethrow;

      emit(
        state.copyWith(
          phase: ScanPhase.extracting,
          statusText: 'Codex 사용량 한도 초과. Gemini로 다시 추출 중...',
        ),
      );
      try {
        return await _gemini.extractReceipt(processed);
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
      final waitText = _codexWaitText(text);
      final geminiHint = state.geminiAvailable
          ? 'Gemini fallback도 실패했습니다. 설정 탭의 Gemini API Key가 유효한지 확인하세요.'
          : '바로 계속 쓰려면 설정 탭에서 Gemini API Key를 저장한 뒤 Gemini를 선택하세요.';
      return 'Codex 사용량 한도에 도달했습니다.\n'
          '$waitText\n'
          '$geminiHint\n\n'
          '이미지 선택과 1024px JPEG 압축은 정상 처리됐고, 앱 저장 로직 오류는 아닙니다.';
    }

    if (text.contains('Gemini API Key')) {
      return 'Gemini API Key가 없습니다.\n설정 탭에서 Gemini API Key를 저장하거나 Codex 로그인을 사용하세요.';
    }

    final cleaned = text.replaceFirst('Bad state: ', '').trim();
    return cleaned.isEmpty ? 'AI 추출 중 알 수 없는 오류가 발생했습니다.' : cleaned;
  }

  String _codexWaitText(String text) {
    final match = RegExp(r'"resets_in_seconds"\s*:\s*(\d+)').firstMatch(text);
    if (match == null) {
      return '잠시 후 다시 시도하세요.';
    }
    final seconds = int.tryParse(match.group(1) ?? '');
    if (seconds == null || seconds <= 0) {
      return '잠시 후 다시 시도하세요.';
    }
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) {
      return '약 $minutes분 후 다시 시도할 수 있습니다.';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '약 $hours시간 후 다시 시도할 수 있습니다.';
    }
    return '약 $hours시간 $remainingMinutes분 후 다시 시도할 수 있습니다.';
  }
}
