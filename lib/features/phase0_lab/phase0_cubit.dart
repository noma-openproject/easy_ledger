import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ai/ai_provider.dart';
import '../../core/ai/codex_provider.dart';
import '../../core/ai/gemini_provider.dart';
import '../../core/oauth/codex_oauth.dart';
import '../../core/storage/secure_storage.dart';

enum CodexStatus { loggedOut, loggingIn, loggedIn }

enum ProviderKind { codex, gemini }

enum ExtractPhase { idle, running, success, error }

class Phase0State {
  final CodexStatus codexStatus;
  final String? accountIdShort;
  final bool geminiKeySaved;
  final String? pickedImagePath;
  final ProviderKind selectedProvider;
  final ExtractPhase phase;
  final ReceiptExtraction? result;
  final String? errorText;

  const Phase0State({
    required this.codexStatus,
    this.accountIdShort,
    required this.geminiKeySaved,
    this.pickedImagePath,
    required this.selectedProvider,
    required this.phase,
    this.result,
    this.errorText,
  });

  factory Phase0State.initial() => const Phase0State(
    codexStatus: CodexStatus.loggedOut,
    geminiKeySaved: false,
    selectedProvider: ProviderKind.codex,
    phase: ExtractPhase.idle,
  );

  Phase0State copyWith({
    CodexStatus? codexStatus,
    Object? accountIdShort = _sentinel,
    bool? geminiKeySaved,
    Object? pickedImagePath = _sentinel,
    ProviderKind? selectedProvider,
    ExtractPhase? phase,
    Object? result = _sentinel,
    Object? errorText = _sentinel,
  }) {
    return Phase0State(
      codexStatus: codexStatus ?? this.codexStatus,
      accountIdShort: identical(accountIdShort, _sentinel)
          ? this.accountIdShort
          : accountIdShort as String?,
      geminiKeySaved: geminiKeySaved ?? this.geminiKeySaved,
      pickedImagePath: identical(pickedImagePath, _sentinel)
          ? this.pickedImagePath
          : pickedImagePath as String?,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      phase: phase ?? this.phase,
      result: identical(result, _sentinel)
          ? this.result
          : result as ReceiptExtraction?,
      errorText: identical(errorText, _sentinel)
          ? this.errorText
          : errorText as String?,
    );
  }
}

const Object _sentinel = Object();

class Phase0Cubit extends Cubit<Phase0State> {
  final SecureStorage _storage;
  final CodexOAuth _oauth;
  final CodexProvider _codex;
  final GeminiProvider _gemini;

  Phase0Cubit({
    required SecureStorage storage,
    required CodexOAuth oauth,
    required CodexProvider codex,
    required GeminiProvider gemini,
  }) : _storage = storage,
       _oauth = oauth,
       _codex = codex,
       _gemini = gemini,
       super(Phase0State.initial());

  /// 앱 시작 시 저장된 상태 복원.
  Future<void> init() async {
    debugPrint('[OAuth] init: reading storage...');
    final tokens = await _storage.readCodexTokens();
    final geminiKey = await _storage.readGeminiKey();
    debugPrint(
      '[OAuth] init: tokens=${tokens == null ? "null" : "present(accountId=${_short(tokens.accountId)}, expired=${tokens.isExpired})"}, '
      'geminiKey=${geminiKey == null ? "null" : "present(len=${geminiKey.length})"}',
    );
    emit(
      state.copyWith(
        codexStatus: tokens != null
            ? CodexStatus.loggedIn
            : CodexStatus.loggedOut,
        accountIdShort: tokens != null ? _short(tokens.accountId) : null,
        geminiKeySaved: geminiKey != null && geminiKey.isNotEmpty,
      ),
    );
    debugPrint(
      '[OAuth] init: emitted codexStatus=${tokens != null ? "loggedIn" : "loggedOut"}',
    );
  }

  // ──────────────── Codex OAuth ────────────────

  Future<void> loginCodex() async {
    if (state.codexStatus == CodexStatus.loggingIn) return;
    debugPrint('[OAuth] loginCodex: START');
    emit(state.copyWith(codexStatus: CodexStatus.loggingIn, errorText: null));
    try {
      final tokens = await _oauth.login(
        onOpenBrowser: (uri) async {
          debugPrint('[OAuth] launching browser: ${uri.origin}${uri.path}');
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          debugPrint('[OAuth] launchUrl returned: $ok');
          if (!ok) {
            throw StateError('외부 브라우저를 열 수 없습니다. URL: $uri');
          }
        },
      );
      debugPrint(
        '[OAuth] loginCodex: tokens OK accountId=${_short(tokens.accountId)} '
        'access.len=${tokens.access.length} refresh.len=${tokens.refresh.length} '
        'expiresAtMs=${tokens.expiresAtMs}',
      );
      await _storage.writeCodexTokens(tokens);
      debugPrint('[OAuth] loginCodex: writeCodexTokens DONE');

      // 즉시 read-back으로 Keychain 실제 저장 여부 검증
      final readBack = await _storage.readCodexTokens();
      debugPrint(
        '[OAuth] loginCodex: read-back after write = '
        '${readBack == null ? "NULL (저장 실패!)" : "OK (accountId=${_short(readBack.accountId)})"}',
      );

      emit(
        state.copyWith(
          codexStatus: CodexStatus.loggedIn,
          accountIdShort: _short(tokens.accountId),
          errorText: null,
        ),
      );
      debugPrint('[OAuth] loginCodex: emitted loggedIn');
    } catch (e, st) {
      debugPrint('[OAuth] loginCodex: CAUGHT EXCEPTION: $e');
      debugPrint('[OAuth] stacktrace:\n$st');
      emit(
        state.copyWith(
          codexStatus: CodexStatus.loggedOut,
          errorText: 'ChatGPT 로그인 실패:\n$e\n\n$st',
        ),
      );
      debugPrint('[OAuth] loginCodex: emitted loggedOut (error)');
    }
  }

  Future<void> logoutCodex() async {
    await _storage.clearCodexTokens();
    emit(
      state.copyWith(codexStatus: CodexStatus.loggedOut, accountIdShort: null),
    );
  }

  /// 디버그: 토큰 만료 강제(401 → refresh 플로우 테스트).
  Future<void> debugExpireCodexToken() async {
    await _storage.debugExpireCodexToken();
  }

  // ──────────────── Gemini ────────────────

  Future<void> saveGeminiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await _storage.clearGeminiKey();
      emit(state.copyWith(geminiKeySaved: false));
      return;
    }
    await _storage.writeGeminiKey(trimmed);
    emit(state.copyWith(geminiKeySaved: true));
  }

  // ──────────────── 영수증 추출 ────────────────

  void setPickedImagePath(String? path) {
    emit(
      state.copyWith(
        pickedImagePath: path,
        phase: ExtractPhase.idle,
        result: null,
        errorText: null,
      ),
    );
  }

  void chooseProvider(ProviderKind kind) {
    emit(state.copyWith(selectedProvider: kind));
  }

  Future<void> extract() async {
    final path = state.pickedImagePath;
    if (path == null) {
      emit(state.copyWith(errorText: '이미지를 먼저 선택하세요.'));
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      emit(state.copyWith(errorText: '파일이 존재하지 않습니다: $path'));
      return;
    }

    emit(
      state.copyWith(
        phase: ExtractPhase.running,
        result: null,
        errorText: null,
      ),
    );

    try {
      final AiProvider p = switch (state.selectedProvider) {
        ProviderKind.codex => _codex,
        ProviderKind.gemini => _gemini,
      };
      final extraction = await p.extractReceipt(file);
      emit(state.copyWith(phase: ExtractPhase.success, result: extraction));
    } catch (e, st) {
      emit(state.copyWith(phase: ExtractPhase.error, errorText: '$e\n\n$st'));
    }
  }

  String _short(String id) => id.length <= 10 ? id : '${id.substring(0, 10)}…';
}
