# 쉬운장부 — Phase 0 완료 보고

**완료 일자**: 2026-04-15
**플랜 파일**: `~/.claude/plans/bright-enchanting-crane.md`
**대상 레포**: `/Users/suyujeo/Documents/projects/easy_ledger`
**참조 아키텍처**: `docs/easy-ledger-architecture.md` §13 Phase 0

---

## 1. 한 줄 요약

**"영수증 사진 1장 → ChatGPT Codex(OAuth) 또는 Gemini Flash(API Key) → 한국어 OCR JSON 추출"** 엔드투엔드 경로를 Flutter macOS 앱으로 실측 완료. Phase 1 본격 개발 진입 준비 완료.

---

## 2. 목표 대비 달성도 (아키텍처 문서 §13 기준)

| 요구사항 | 상태 | 비고 |
|---|---|---|
| Flutter 프로젝트 + 폴더 구조 | ✅ | `lib/core/{oauth,ai,storage}` + `lib/features/phase0_lab` |
| ChatGPT Codex OAuth "device flow" 구현 | ✅* | **문서 오류 발견·교정** — 실제로는 PKCE authorization code flow + localhost:1455 콜백 서버 |
| `chatgpt.com/backend-api/codex/responses`로 영수증 이미지 → JSON 추출 | ✅ | 실측 성공(accountId `f5aa8072-8…`), SSE 스트림 파싱 동작 |
| Gemini Flash API Key 직접 호출(fallback) | ✅ | `gemini-2.0-flash:generateContent` REST, `response_mime_type: application/json` |
| 검증: `flutter build apk --debug` 에러 0 | ✅ | `build/app/outputs/flutter-apk/app-debug.apk` |
| 검증: 실제 API 호출 → JSON 반환 확인 | ✅ | 사용자 실측(Codex + Gemini 양쪽) |

(*) 아키텍처 v3 문서의 "device flow" 표현은 OpenClaw 실제 구현과 불일치. 구현은 OpenClaw(`@mariozechner/pi-ai`) 실제 소스에 맞춰 **PKCE authorization code flow**로 진행. v4에서 교정 완료.

---

## 3. 최종 기술 스택 (확정)

| 계층 | 선택 | 버전 |
|---|---|---|
| Flutter | stable | 3.41.6 |
| Dart | — | 3.11.4 |
| 상태관리 | flutter_bloc (Cubit) | 8.1.6 |
| HTTP | dio | 5.9.2 |
| 시크릿 저장 | flutter_secure_storage | 9.2.4 (macOS legacy login keychain 모드) |
| OAuth 런처 | url_launcher | 6.3.2 |
| 해시 | crypto | 3.0.7 (PKCE SHA-256) |
| 파일 선택 | file_picker | 8.3.7 (desktop) |
| 이미지 선택 | image_picker | 1.1.2 (mobile; Phase 1+) |

---

## 4. 생성·수정 파일 (17개)

### 신규 Dart 소스 (12)
```
lib/main.dart                                         — DI 조립, MaterialApp 진입
lib/core/oauth/pkce.dart                              — PKCE verifier/challenge + state 생성
lib/core/oauth/jwt.dart                               — JWT payload → chatgpt_account_id 추출
lib/core/oauth/local_callback_server.dart             — 127.0.0.1:1455 콜백 HTTP 서버
lib/core/oauth/codex_oauth.dart                       — PKCE auth-code flow + /oauth/token 교환 + refresh
lib/core/ai/receipt_prompt.dart                       — 한국어 영수증 OCR 시스템 프롬프트 (§8)
lib/core/ai/ai_provider.dart                          — 추상 인터페이스 + ReceiptExtraction 모델
lib/core/ai/codex_provider.dart                       — Codex SSE 스트림 파서 + 모델 폴백 체인
lib/core/ai/gemini_provider.dart                      — Gemini REST one-shot JSON 응답
lib/core/storage/secure_storage.dart                  — 시크릿 스토리지 래퍼 + 디버그 만료 훅
lib/features/phase0_lab/phase0_cubit.dart             — 상태 머신 (Idle/LoggingIn/LoggedIn/Extracting/...)
lib/features/phase0_lab/phase0_page.dart              — 3-섹션 진단용 UI
```

### 플랫폼/빌드 설정 수정 (3)
```
pubspec.yaml                                          — Phase 0 의존성 추가 (dio/bloc/secure_storage/...)
macos/Runner/DebugProfile.entitlements                — network.client/server + files.user-selected
macos/Runner/Release.entitlements                     — 동일
```

### 기타 (2)
```
test/widget_test.dart                                 — EasyLedgerApp 스모크 테스트로 교체
docs/easy-ledger-architecture.md                      — v4 업데이트 (v3 → v4)
```

---

## 5. 툴체인 설치 (세션 내 누적)

이 프로젝트를 위해 **무(無)부터 설치**한 시스템 툴:

| 도구 | 설치 경로 | 방식 |
|---|---|---|
| Flutter 3.41.6 | `/opt/homebrew/share/flutter` | `brew install --cask flutter` |
| Xcode 26.4 (+ firstLaunch 컴포넌트) | `/Applications/Xcode.app` | App Store + `sudo xcodebuild -runFirstLaunch` |
| CocoaPods 1.16.2 | `/opt/homebrew/Cellar/cocoapods` | `brew install cocoapods` |
| OpenJDK 17.0.18 | `/opt/homebrew/opt/openjdk@17` | `brew install openjdk@17` |
| Android cmdline-tools | `/opt/homebrew/share/android-commandlinetools` | `brew install --cask android-commandlinetools` |
| Android Platform 34, 35 + build-tools 35.0.0 | 위 경로 하위 | `sdkmanager` |
| Android NDK 28.2.13676358 (r28c) | 위 경로 하위 | `sdkmanager` (초기 다운로드 실패 후 재설치) |
| Xcode license | 시스템 | `sudo xcodebuild -license accept` (사용자 직접) |
| Android SDK licenses | 위 경로 하위 | `flutter doctor --android-licenses` |

---

## 6. 검증 결과

### 정적 검증
```
✅ flutter pub get            → 69 packages resolved
✅ flutter analyze            → No issues found
✅ flutter build macos --debug → build/macos/.../easy_ledger.app
✅ flutter build apk --debug  → build/app/outputs/flutter-apk/app-debug.apk
```

### 실측 검증 (사용자 실행)
```
✅ flutter run -d macos              → Phase 0 Lab 앱 창 기동
✅ [ChatGPT 로그인]                   → 외부 브라우저 → ChatGPT 로그인
✅ localhost:1455/auth/callback       → 앱 복귀, accountId 표시
✅ 토큰 교환 (/oauth/token)            → status 200, refresh_token + access_token
✅ JWT 디코드                         → chatgpt_account_id=present, len=36
✅ Keychain 저장·재읽기                → 앱 재시작 후에도 로그인 유지
✅ 영수증 이미지 → JSON 추출           → 양쪽 경로 모두 동작
```

스크린샷상 확인: `로그인됨 (account: f5aa8072-8…)` + 영수증 추출 정상.

---

## 7. 이번 세션에서 해결한 핵심 이슈 4건

### 이슈 1 — 아키텍처 문서의 "device flow" 오기
**증상**: Phase 0 플랜 시 `POST /oauth/device/code` 가정
**근본 원인**: OpenClaw `@mariozechner/pi-ai` 실제 구현을 읽어보니 PKCE authorization code flow + localhost 콜백 서버
**해결**: 실제 소스에 맞춰 `local_callback_server.dart` + `codex_oauth.dart` 설계. 문서는 v4에서 교정

### 이슈 2 — macOS 빌드 실패 (`IDESimulatorFoundation` 로드 실패)
**증상**: `xcodebuild failed to load a required plug-in` (`CoreSimulator.framework` not found)
**근본 원인**: Xcode 26.4 신규 설치 직후 firstLaunch 컴포넌트 미설치
**해결**: 사용자가 `sudo xcodebuild -runFirstLaunch` 수행

### 이슈 3 — Android NDK 부분 다운로드
**증상**: `[CXX1101] NDK at .../28.2.13676358 did not have a source.properties file`
**근본 원인**: sdkmanager 다운로드 중단으로 불완전 설치물
**해결**: 해당 디렉토리 삭제 후 sdkmanager 재설치

### 이슈 4 — ⭐ Keychain 쓰기 실패 (`errSecMissingEntitlement -34018`)
**증상**: 웹에서 로그인 성공 + 토큰 교환 성공하지만, 앱이 "로그인되었다가 풀림"
**근본 원인**: `flutter_secure_storage` 기본값이 macOS Data Protection Keychain 사용. 이건 Apple Team ID 기반 `keychain-access-groups` entitlement 필요. Flutter 기본 ad-hoc signing에는 Team ID가 없어 `-34018` 반환
**해결**: `MacOsOptions(useDataProtectionKeyChain: false, accessibility: unlocked)`로 **legacy login keychain** 사용. ad-hoc signing에서도 Team ID 없이 Keychain R/W 동작. `keychain-access-groups` entitlement는 되돌려 제거(ad-hoc signing과 비호환)

---

## 8. 구현에서 확정된 OAuth 상수 (Phase 1+ 참조용)

```
CLIENT_ID           = app_EMoamEEZ73f0CkXaXp7hrann   (OpenAI Codex CLI 공개 ID, OpenClaw 공용)
AUTHORIZE_URL       = https://auth.openai.com/oauth/authorize
TOKEN_URL           = https://auth.openai.com/oauth/token
REDIRECT_URI        = http://localhost:1455/auth/callback
SCOPE               = openid profile email offline_access
ORIGINATOR          = pi
CODEX_ENDPOINT      = https://chatgpt.com/backend-api/codex/responses
MODEL_FALLBACK      = [gpt-5.4, gpt-5.1, gpt-5.1-codex-mini]
JWT_ACCOUNT_PATH    = payload["https://api.openai.com/auth"]["chatgpt_account_id"]

Required Codex Headers:
  Authorization: Bearer <access_token>
  chatgpt-account-id: <JWT에서 추출>
  originator: pi
  OpenAI-Beta: responses=experimental
  Accept: text/event-stream
  Content-Type: application/json
```

실측 시 JWT 응답 키:
```
top-level: [aud, client_id, exp, https://api.openai.com/auth,
            https://api.openai.com/profile, iat, iss, jti, nbf,
            pwd_auth_time, scp, session_id, sl, sub]

"https://api.openai.com/auth" 클레임:
  [chatgpt_account_id, chatgpt_account_user_id, chatgpt_compute_residency,
   chatgpt_plan_type, chatgpt_user_id, localhost, user_id]
```

`expires_in=863999` (약 10일) 확인 — Phase 1에서 refresh 플로우 실측 권장.

---

## 9. 알려진 제한사항 (Phase 0 범위 밖, 다음 단계 대상)

1. **macOS 우선 완성만** — Android APK는 빌드만 통과, 실제 OAuth 실행은 Phase 1+에서 검증.
2. **Data Protection Keychain 미사용** — Apple Developer Program 가입 전까지 legacy login keychain 유지.
3. **Windows/iOS scaffold 생략** — `--platforms=macos,android`만. 필요 시 추가.
4. **`gpt-5.4` 모델 가용성 미확정** — 계정 플랜에 따라 다름. 폴백 로직은 구현됨.
5. **Hive/구글시트/간편장부**는 Phase 1~3 범위로 의도적 제외.
6. **Codex refresh flow 실측 미수행** — 토큰 10일 유효라 세션 내 자연 트리거 없음.
7. **이미지 리사이즈 미구현** — 원본 base64 그대로 전송. Phase 1 필수 추가 항목.
8. **SSE tool_call 이벤트 무시** — Phase 1에서 명시적 스킵 핸들러 추가 검토.

---

## 10. Phase 1 재사용 지침 (§16 매핑)

```
lib/core/ai/                     → extractReceipt(File) 그대로 재사용, 이미지 리사이즈 전처리만 추가
lib/core/oauth/                  → Codex OAuth 그대로 재사용
lib/core/storage/secure_storage.dart → 그대로
lib/features/phase0_lab/         → 개발 전용 랩으로 유지
```

`debugPrint('[OAuth] ...')` / `[Storage]` 로그는 Phase 1 동안 유지, Phase 4 프로덕션 빌드 전 정리 예정.

---

## 11. 다음 단계

아키텍처 문서 §17 Phase 1 상세 계획에 따라 단계 1-1(Hive 초기화 + 모델)부터 6단계 순서 진행.
