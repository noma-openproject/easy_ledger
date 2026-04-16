# 쉬운장부 — 아키텍처 v8

> **최종 갱신:** 2026-04-16
> **변경:** v7→v8: Phase 4 완료, Post-Launch 계획(§22), 세무 기능 리서치 계획(§23) 추가
> **코딩 도구:** 클로드코드 (Claude Code)
> **이 문서 위치:** `docs/architecture.md` — 클로드코드 작업 시 이 문서를 먼저 읽어라.

---

## 1. 한 줄 요약

영수증 사진 찍으면 AI가 자동 추출 → 내 폰/PC에 장부 저장 → 팀 구글시트에 동기화까지 되는 앱.
서버 없음. litellm 없음. 설치만 하면 바로 동작.

---

## 2. 핵심 원칙

1. **서버 배포 없음** — 앱 하나만 설치하면 끝
2. **추가 비용 없음** — 기존 ChatGPT 구독($20/월) 또는 Gemini 무료 티어
3. **litellm 없음** — 앱이 직접 AI API 호출 (OpenClaw 방식 PKCE OAuth)
4. **로컬 우선** — 모든 데이터는 내 기기에 저장. 구글시트 동기화는 선택
5. **세무 활용 가능** — 경비 태그, 간편장부 내보내기, 원본 이미지 5년 보관

---

## 3. 이 앱이 해결하는 개인사업자 페인포인트

| # | 페인포인트 | 현재 상태 | 앱이 해결하는 방법 |
|---|----------|---------|-----------------|
| ① | **종이 영수증 분실/변질** — 감열지는 수개월 만에 글씨가 사라짐 | 봉투/파일에 모아두지만 분실됨 | 받자마자 촬영 → 디지털 원본 보관 |
| ② | **개인카드 사업용 미등록** — 홈택스에 등록하면 경비처리 가능한데 대부분 안 함 | 개인카드 영수증은 그냥 버림 | 사진 찍으면 사업경비 태그 가능 |
| ③ | **간이영수증 3만원 룰 무지** — 세탁소/택배/주차장, 3만원 초과 시 가산세 2% | 간이영수증 어디 뒀는지 모름 | AI가 금액 추출 → 3만원 초과 경고 표시 |
| ④ | **5월 종소세에 1년치 몰아서 정리** | 5월에 영수증 더미 꺼내서 엑셀 수작업 | 매일 촬영 → 자동 축적 → 5월에 "내보내기" 1번 |
| ⑤ | **장부 작성 어렵고 안 하면 가산세** — 무기장 가산세 (산출세액 20%) | 장부 없이 추계신고 → 세액이 더 높아짐 | 촬영만 하면 간편장부 양식 자동 정리 |
| ⑥ | **증빙 5년 보관 의무** — 종이세금계산서, 간이영수증은 전자 조회 불가 | 서랍에 쌓아둠, 5년 못 버팀 | 사진으로 디지털 보관 → 5년 자동 관리 |
| ⑦ | **증빙 없어서 경비 인정 못 받음** — 세금 차이 평균 20% 이상 | "쓴 건 맞는데 영수증이 없어요" | 찍는 순간 증빙 확보 완료 |

---

## 4. Sheetify 벤치마크 (핵심 레퍼런스)

Sheetify: AI Receipt Scanner — 가장 유사한 기존 앱. 월 $9.99 구독.

### Sheetify 5단계 플로우 (우리 앱에 그대로 적용)

```
① Scan — 카메라 촬영 + auto-crop + 갤러리 선택 + 배치(여러 장)
② Extract — AI가 price, date, store, tax, currency 자동 추출
③ Review — 추출 결과 + 사용자 수정 + 카테고리 변경 + 라벨 태그
④ Save & Sync — 로컬 저장 + 구글 시트 행 추가 + 오프라인 시 나중 동기화
⑤ Track & Report — 대시보드 + 카테고리별 비율 + 리포트 + 예산 추적
```

### 우리 앱 차별점 vs Sheetify

| | Sheetify | 쉬운장부 |
|--|---------|---------|
| 가격 | $9.99/월 | **무료** (ChatGPT 구독 공유 or Gemini 무료) |
| AI | 자체 OCR (비공개) | ChatGPT Codex / Gemini Flash (선택) |
| 언어 | 영어 위주 | **한국어 영수증 특화** |
| 세무 | 없음 | **간편장부 내보내기, 경비 태그, 사업자번호 추출** |
| PC | 없음 (모바일만) | **macOS + Windows EXE** |
| 자동저장 | 없음 | **confidence 90%+ 시 확인 없이 바로 저장** (V1) |

---

## 5. 기술 스택 (Phase 0 실측 확정)

| 컴포넌트 | 선택 | 버전 (확정) |
|---------|------|-----------|
| 프레임워크 | Flutter | 3.41.6 (stable) |
| 언어 | Dart | 3.11.4 |
| 상태관리 | flutter_bloc (Cubit) | 8.1.6 |
| HTTP | dio | 5.9.2 |
| 시크릿 저장 | flutter_secure_storage | 9.2.4 (macOS: legacy login keychain) |
| OAuth 런처 | url_launcher | 6.3.2 |
| 해시 | crypto | 3.0.7 (PKCE SHA-256) |
| 파일 선택 | file_picker | 8.3.7 (desktop) |
| 이미지 선택 | image_picker | 1.1.2 (mobile, Phase 1+) |
| 로컬 DB | Hive + hive_flutter | Phase 1에서 추가 |
| 차트 | fl_chart | Phase 2에서 추가 |
| 구글시트 | googleapis + google_sign_in | Phase 3에서 추가 |
| 엑셀 | excel 패키지 | Phase 3에서 추가 |

---

## 6. AI 호출 아키텍처 (Phase 0 실측 확정)

> ⚠️ v3까지의 "device flow" 기술은 **오류**였음. 실제 OpenClaw 소스코드(@mariozechner/pi-ai) 확인 결과 PKCE authorization code flow. Phase 0 실측으로 확정.

```
[Flutter 앱]
  ├─ 1순위: ChatGPT Codex OAuth (PKCE authorization code flow)
  │   → url_launcher로 auth.openai.com/oauth/authorize 열기
  │   → 사용자가 ChatGPT 로그인
  │   → localhost:1455/auth/callback으로 code 수신
  │   → code → /oauth/token에서 토큰 교환
  │   → JWT에서 chatgpt_account_id 추출
  │   → flutter_secure_storage에 저장 (legacy login keychain)
  │   → chatgpt.com/backend-api/codex/responses로 SSE 호출
  │
  └─ 2순위: Gemini API Key (사용자 직접 입력)
      → 설정에서 API Key 입력 → 저장
      → generativelanguage.googleapis.com REST 호출
```

### 6.1 확정된 OAuth 상수 (실측 검증 완료)

```
CLIENT_ID         = app_EMoamEEZ73f0CkXaXp7hrann  (Codex CLI 공개 ID, OpenClaw 공용)
AUTHORIZE_URL     = https://auth.openai.com/oauth/authorize
TOKEN_URL         = https://auth.openai.com/oauth/token
REDIRECT_URI      = http://localhost:1455/auth/callback
SCOPE             = openid profile email offline_access
ORIGINATOR        = pi
CODEX_ENDPOINT    = https://chatgpt.com/backend-api/codex/responses
MODEL_FALLBACK    = [gpt-5.4, gpt-5.1, gpt-5.1-codex-mini]
JWT_ACCOUNT_PATH  = payload["https://api.openai.com/auth"]["chatgpt_account_id"]
TOKEN_EXPIRES_IN  = 863999 (약 10일)
```

### 6.2 PKCE Authorization Code Flow

```
1. PKCE 생성: 32바이트 랜덤 → base64url(verifier) → SHA-256 → base64url(challenge)
2. state 생성: 16바이트 랜덤 hex
3. localhost:1455 콜백 HTTP 서버 기동 (HttpServer.bind)
4. authorize URL 조립:
   auth.openai.com/oauth/authorize?
     response_type=code
     &client_id=app_EMoamEEZ73f0CkXaXp7hrann
     &redirect_uri=http://localhost:1455/auth/callback
     &scope=openid+profile+email+offline_access
     &code_challenge={challenge}&code_challenge_method=S256
     &state={state}
     &id_token_add_organizations=true
     &codex_cli_simplified_flow=true
     &originator=pi
5. url_launcher로 외부 브라우저 열기 (인앱 웹뷰 금지)
6. 사용자 로그인 → 브라우저가 localhost:1455/auth/callback?code=...&state=... 리디렉트
7. 콜백 서버가 code 수신 + state 검증 → "로그인 완료" HTML 표시
8. POST auth.openai.com/oauth/token (form-urlencoded):
   grant_type=authorization_code, code, code_verifier, client_id, redirect_uri
9. 응답: access_token, refresh_token, expires_in
10. JWT decode → chatgpt_account_id 추출 → 저장
```

### 6.3 Codex API 호출 (SSE 스트림)

**필수 헤더:**
```
Authorization: Bearer {access_token}
chatgpt-account-id: {JWT에서 추출한 account_id}
originator: pi
OpenAI-Beta: responses=experimental
Accept: text/event-stream
Content-Type: application/json
```

**요청 바디 (Responses API):**
```json
{
  "model": "gpt-5.4",
  "store": false,
  "stream": true,
  "instructions": "<한국어 영수증 OCR 시스템 프롬프트>",
  "input": [{
    "role": "user",
    "content": [
      {"type": "input_text", "text": "영수증 JSON만 출력."},
      {"type": "input_image", "image_url": "data:image/jpeg;base64,<BASE64>"}
    ]
  }]
}
```

**SSE 파싱:**
- 라인 형식: `data: {json}\n\n`, 종료: `data: [DONE]`
- 수집: `response.output_text.delta`의 `delta` 필드 이어붙임
- 종료: `response.completed` / `response.done`
- 실패: `response.failed` → error message 추출
- 401 발생 시 → 1회 refresh 후 재호출

### 6.4 Gemini Fallback (REST)

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={API_KEY}

바디: contents[0].parts = [
  {"text": RECEIPT_PROMPT},
  {"inline_data": {"mime_type": "image/jpeg", "data": BASE64}}
]
generationConfig.response_mime_type = "application/json"

응답: candidates[0].content.parts[0].text → jsonDecode
```

### 6.5 macOS 필수 설정

DebugProfile.entitlements + Release.entitlements 둘 다:
```xml
<key>com.apple.security.network.client</key><true/>
<key>com.apple.security.network.server</key><true/>
```
`network.server` 빠지면 localhost:1455 콜백 서버 기동 불가 → OAuth 전체 실패.

flutter_secure_storage: `MacOsOptions(useDataProtectionKeyChain: false)` 사용.
Data Protection Keychain은 Apple Team ID 필요 → ad-hoc signing에서 -34018 에러.

---

## 7. 팀 공유: 구글 시트 동기화

```
[직원A 폰] → 영수증 스캔 → 로컬 저장 → "시트에 올리기"
[직원B 폰] → 영수증 스캔 → 로컬 저장 → "시트에 올리기"
                                              ↓
                                    [공유 구글 시트]
                                    날짜|상호|금액|카테고리|담당자|사업자번호
                                              ↓
                                    팀장/세무사가 구글시트에서 확인
```

### 구현 방식

1. 설정 → "구글 계정 연결" → google_sign_in → OAuth 토큰
2. 설정 → "공유 시트 ID" 입력 (팀장이 시트 만들고 ID 공유)
3. 영수증 저장 시 → Sheets API `spreadsheets.values.append`로 행 추가
4. 시트 헤더: 날짜 | 시간 | 상호명 | 사업자번호 | 금액 | 부가세 | 합계 | 결제수단 | 카테고리 | 세무분류 | 담당자 | 메모

### 오프라인 처리

- 인터넷 없으면 → 로컬에만 저장 + "동기화 대기" 표시
- 인터넷 복구 시 → 대기 건 자동 동기화

---

## 8. 영수증 OCR 프롬프트

```
시스템: "너는 한국어 영수증 전문 OCR 추출기다.
이미지에서 아래 JSON 스키마에 맞게 추출하라.

규칙:
1. 금액은 정수. 쉼표/원 제거
2. 날짜: YYYY-MM-DD
3. 시간: HH:MM (24시간)
4. 품목명은 영수증 원문 그대로
5. 수량 안 보이면 1
6. 부가세 별도 없으면 tax: null
7. 사업자등록번호 보이면 추출 (000-00-00000), 없으면 null
8. 결제수단: card/cash/transfer/other
9. 카테고리: food/transport/living/medical/culture/education/gift/housing/communication/entertainment/etc
10. 못 읽으면 null. 추측 금지
11. confidence 0.0~1.0

JSON만 출력."
```

---

## 9. 화면 구조

### 하단 5탭

```
📷 스캔    📋 내역    📅 달력    📊 통계    ⚙️ 설정
```

### 레퍼런스 매핑

| 화면 | 레퍼런스 | 핵심 패턴 |
|------|---------|----------|
| 스캔 | Expensify SmartScan, Sheetify | 카메라 버튼 크게, 5단계(Scan→Extract→Review→Save→Report) |
| 내역 | 편한가계부 일별목록 | 날짜 그룹핑, 카테고리 아이콘+금액 |
| 달력 | 편한가계부 달력뷰 | 날짜별 수입/지출 합계, 탭→해당일 목록 |
| 통계 | 뱅크샐러드 도넛차트 + 편한가계부 예산바 | 카테고리 비율, 월별 추이 |
| 설정 | Premo 설정 | AI 연결 + 구글 연결 + 세무 설정 |

### 스캔 플로우

```
📷 탭 → 카메라(모바일)/파일선택(PC)
  → 이미지 리사이즈(max 1024px) + JPEG 압축(80%)
  → 로딩 ("영수증 분석 중...")
  → AI → JSON (SSE 스트림)
  → 확인 화면:
    ┌────────────────────────┐
    │ [원본 썸네일]           │
    │ 상호: GS25 강남역점     │
    │ 날짜: 2026-04-14       │
    │ ──────────────────     │
    │ 삼각김밥  2×1,200 2,400│
    │ 아메리카  1×1,500 1,500│
    │ ──────────────────     │
    │ 합계        3,900원    │
    │ 카테고리: 🍔 식비       │
    │ 태그: 개인지출          │
    │ ⚠️ 3만원 초과 간이영수증│  ← 해당 시 경고
    │                        │
    │ [취소]     [저장 ✅]    │
    └────────────────────────┘
  → 저장 → 로컬 DB (Hive) + (설정 시) 구글시트 동기화
```

---

## 10. DB 스키마 (Hive)

```dart
@HiveType(typeId: 0)
class Receipt {
  @HiveField(0) String id;          // UUID
  @HiveField(1) String imagePath;   // 로컬 이미지 경로
  @HiveField(2) DateTime scannedAt;
  @HiveField(3) double confidence;
  @HiveField(4) String rawJson;     // AI 원본 응답
}

@HiveType(typeId: 1)
class Transaction {
  @HiveField(0)  String id;
  @HiveField(1)  String? receiptId;
  @HiveField(2)  DateTime date;
  @HiveField(3)  String? time;
  @HiveField(4)  String storeName;
  @HiveField(5)  String? businessNumber;   // 사업자등록번호
  @HiveField(6)  int total;
  @HiveField(7)  int? tax;
  @HiveField(8)  String paymentMethod;
  @HiveField(9)  String category;
  @HiveField(10) String expenseType;       // personal/business
  @HiveField(11) String? taxCategory;      // 복리후생비/접대비/...
  @HiveField(12) String? memo;
  @HiveField(13) bool syncedToSheet;       // 구글시트 동기화 여부
  @HiveField(14) DateTime createdAt;
}

@HiveType(typeId: 2)
class TransactionItem {
  @HiveField(0) String id;
  @HiveField(1) String transactionId;
  @HiveField(2) String name;
  @HiveField(3) int quantity;
  @HiveField(4) int unitPrice;
  @HiveField(5) int total;
}
```

---

## 11. 세무 기능

### 경비 태그
- 모든 거래: `personal`(개인) / `business`(사업경비)
- 사업경비 세부: 복리후생비/접대비/소모품비/차량유지비/통신비/교육훈련비/여비교통비

### 간편장부 엑셀 내보내기
- 국세청 간편장부 양식 호환
- 날짜/거래처/적요/수입/비용/고정자산 열
- 월별/카테고리별 소계

### 증빙 보관
- 원본 이미지 로컬 5년 보관 (법적 의무)
- 백업: JSON + 이미지 ZIP 내보내기

---

## 12. 플랫폼별 동작

| | Android | iOS | Windows | macOS |
|--|---------|-----|---------|-------|
| 카메라 | ✅ | ✅ | ❌ 파일선택 | ❌ 파일선택 |
| 구글시트 | ✅ | ✅ | ✅ | ✅ |
| Codex OAuth | ⚠️ Phase 1 실측 | 미검증 | 미검증 | ✅ 실측 완료 |

---

## 13. 로드맵

### ✅ Phase 0 (완료 — 2026-04-15)
- Flutter 3.41.6 프로젝트 + 폴더 구조
- ChatGPT Codex PKCE OAuth 구현 + 실측 성공
- `chatgpt.com/backend-api/codex/responses` SSE 스트림으로 영수증 JSON 추출 성공
- Gemini Flash API Key fallback 구현 + 실측 성공
- macOS debug + Android APK 빌드 통과
- 해결된 이슈: entitlement, Keychain -34018, NDK, Xcode firstLaunch

### ✅ Phase 1 (완료 — 2026-04-15)
- Hive DB (Receipt/Transaction/TransactionItem TypeAdapter + CRUD)
- 5탭 네비게이션 스캐폴드
- 스캔 탭: 촬영/선택 → 이미지 리사이즈(1024px, JPEG 80%) → AI 추출 → 리뷰/수정 → Hive 저장
- 내역 탭: 날짜별 그룹핑 목록 + 거래 상세 (원본 이미지, 품목, 수정/삭제)
- 수동 입력 폼
- 3만원 초과 간이영수증 경고
- 상세 계획: §17 참조

### Phase 2 (2주): 장부 완성 — Sheetify ⑤ Track & Report
- 상세 계획: §19 참조

### ✅ Phase 2 (완료 — 2026-04-15)
- 달력 뷰 (table_calendar + 날짜별 합계 + 탭→거래목록)
- 통계 (fl_chart 도넛차트 + 카테고리 비율 + 월별 추이 바차트 + 카테고리 탭→필터)
- 설정 화면 통합 (AI 연결 + 카테고리 관리 + 일반 설정 + 데이터 현황)
- 자동저장 모드 (confidence 90%+ 시 리뷰 건너뛰기)
- 카테고리 관리 (추가/편집/삭제/순서변경 + 기본 카테고리 삭제 방지)
- 상세 계획: §19 참조

### Phase 3 (2주): 팀 + 세무
- 상세 계획: §20 참조

### ✅ Phase 3 (완료 — 2026-04-16)
- 구글 로그인 (google_sign_in 네이티브 A안, Client ID 3종 플랫폼별 분기)
- Google Sheets 연동 (ensureHeader + appendTransaction + 첫 시트 이름 동적 조회)
- 자동 동기화 (저장 시 sync_queue enqueue + 네트워크 복구 시 자동 처리)
- 오프라인 큐잉 (재시도 5회 + lastError 기록 + 수동 재처리 버튼)
- 간편장부 .xlsx 내보내기 (3시트: 간편장부/전체거래/카테고리요약, 월별 소계, 연간 합계)
- 데이터 백업/복원 (JSON + 이미지 ZIP, 덮어쓰기/병합 옵션)
- 세무 카테고리 10개 드롭다운 (복리후생비/접대비/소모품비/차량유지비/통신비/교육훈련비/여비교통비/지급수수료/광고선전비/기타)
- 실측 완료: 구글 로그인, 시트 헤더 생성, 거래 자동 시트 업로드
- 해결된 이슈: 한국어 시트 탭 이름 동적 조회, sync_queue enqueue 조건 완화
- 상세 계획: §20 참조

### Phase 4 (2주): 고도화 + 정식 배포
- 상세 계획: §21 참조

### ✅ Phase 4 (완료 — 2026-04-16)
- 예산 관리 (카테고리별 월 예산 + 통계 진행 바 + 초록/주황/빨강 3단계 경고)
- 배치 스캔 (최대 10장, 최대 3개 병렬 AI 호출, 건별 상태 표시, 재시도/수동 전환)
- 내역 검색 (상호/메모/품목명) + 필터 (기간/카테고리/경비구분/금액/결제수단 AND)
- 앱 아이콘 + 스플래시 Python PIL로 직접 생성 (영수증 + 체크마크 녹색 테마)
- 앱 이름 "쉬운장부" (macOS/Android/Windows)
- Windows scaffold 추가 (flutter create --platforms=windows)
- Android 릴리스 서명 템플릿 + release_guide.md
- GitHub Actions 3종 (macOS/Android/Windows 자동 빌드, tag v*로 트리거)
- 실측 완료: macOS .app 생성 + /Applications 설치 + Launchpad 아이콘 실행
- 상세 계획: §21 참조

### Post-Launch (사용자 피드백 기반)
- 상세 계획: §22 참조
- 세무 기능 강화 리서치: §23 참조

---

## 14. 주요 레퍼런스

| 이름 | 용도 | 비고 |
|------|------|------|
| Sheetify | 전체 컨셉 (AI 스캔→구글시트) | Play Store, $9.99/월 |
| 편한가계부 | 달력뷰, 통계, 입력폼 UI | 스크린샷 확보 완료 |
| Expensify | SmartScan 3단계 플로우 | 오프라인 큐잉 패턴 |
| Receipt-Manager-App | Flutter 영수증 앱 코드 구조 | github.com/jingjingyang0803 |
| OpenClaw (@mariozechner/pi-ai) | PKCE OAuth + Codex SSE 실제 구현 | 소스 직접 참조하여 구현 |
| 토스 | 미니멀 홈, 큰 숫자 패턴 | |
| 뱅크샐러드 | 도넛차트, AI 분류 | |

---

## 15. 검증 규칙

### 이 채팅에서의 정보 검증 규칙

1. **날짜 강제 확인** — 기술적 사실 주장 시 근거 자료의 날짜를 반드시 함께 명시
2. **확신도 태깅** — 모든 기술적 주장에 [확인됨] / [추정] / [미확인] 태그
3. **반대 검색** — "된다" 주장 전에 "안 된다 error fail" 먼저 검색
4. **최신 상태 확인** — 버그/이슈 언급 시 "현재 수정되었는지"를 반드시 추가 검색

### 클로드코드 검증 규칙 (모든 Phase 완료 후 필수)

```
□ flutter analyze → No issues found
□ flutter build macos --debug → 에러 0
□ flutter build apk --debug → 에러 0
□ flutter run -d macos → 앱 기동 + 핵심 플로우 동작
□ 실제 API 호출: 테스트 영수증 1장 → JSON 반환 확인
□ JSON 파싱 → Transaction 모델 변환 → Hive 저장 성공
□ 에러 시: 에러 메시지 전문 + 검색 결과 첨부
□ "되는 것 같다" 금지 → 실제 실행 결과만 보고
□ 수정한 파일 목록과 이유를 매번 알려줘
□ 이번에 요청하지 않은 것은 건드리지 마
```

---

## 16. Phase 0 산출물 (Phase 1에서 재사용)

```
lib/core/ai/                     → extractReceipt(File) 그대로 재사용
lib/core/oauth/                  → Codex OAuth 그대로 재사용
lib/core/storage/                → flutter_secure_storage 래퍼 그대로
lib/features/phase0_lab/         → 개발 전용 랩으로 유지 (또는 lib/dev/로 이동)
```

Phase 0에서 확인된 주의사항:
- macOS network.server entitlement 필수
- flutter_secure_storage: `useDataProtectionKeyChain: false` (Apple Team ID 없을 때)
- SSE tool_call 이벤트는 현재 무시 중 → Phase 1에서 명시적 스킵 핸들러 추가
- 이미지 리사이즈 미구현 → Phase 1에서 max 1024px + JPEG 80% 추가 필수 (토큰 절약)

---

## 17. Phase 1 상세 계획

### 목표
Sheetify 5단계 중 ①②③④를 구현하여 "영수증 촬영 → AI 추출 → 확인/수정 → Hive 저장" 완전한 루프를 만든다. ⑤(Report)는 Phase 2.

### 신규 의존성 추가 (pubspec.yaml)

```yaml
dependencies:
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  intl: ^0.19.0          # 날짜/금액 포맷
  path: ^1.9.0           # 이미지 경로 처리

dev_dependencies:
  hive_generator: ^2.0.1
  build_runner: ^2.4.13
```

### 폴더 구조 변경

```
lib/
├── main.dart                          (5탭 네비게이션으로 교체)
├── app.dart                           (MaterialApp + 라우팅)
├── core/
│   ├── oauth/                         (Phase 0 그대로)
│   ├── ai/                            (Phase 0 그대로 + 이미지 리사이즈 추가)
│   ├── storage/
│   │   ├── secure_storage.dart        (Phase 0 그대로)
│   │   └── hive_storage.dart          (NEW — Hive 초기화 + CRUD)
│   ├── models/
│   │   ├── receipt.dart               (NEW — Hive TypeAdapter)
│   │   ├── transaction.dart           (NEW — Hive TypeAdapter)
│   │   └── transaction_item.dart      (NEW — Hive TypeAdapter)
│   └── utils/
│       ├── image_utils.dart           (NEW — 리사이즈 + JPEG 압축)
│       └── format_utils.dart          (NEW — 금액/날짜 포맷)
├── features/
│   ├── scan/
│   │   ├── scan_page.dart             (NEW — ① Scan + ② Extract)
│   │   ├── scan_cubit.dart            (NEW)
│   │   └── review_page.dart           (NEW — ③ Review + ④ Save)
│   ├── transactions/
│   │   ├── transactions_page.dart     (NEW — 내역 탭, 날짜별 목록)
│   │   ├── transactions_cubit.dart    (NEW)
│   │   └── transaction_detail_page.dart (NEW — 상세 + 수정)
│   ├── manual_input/
│   │   └── manual_input_page.dart     (NEW — 수동 입력 폼)
│   ├── calendar/                      (Phase 2 — 빈 placeholder)
│   ├── statistics/                    (Phase 2 — 빈 placeholder)
│   ├── settings/
│   │   └── settings_page.dart         (NEW — AI 연결 상태 + 카테고리 관리)
│   └── phase0_lab/                    (유지 — 개발 디버그용)
└── widgets/
    ├── receipt_card.dart              (NEW — 영수증 요약 카드)
    ├── category_chip.dart             (NEW — 카테고리 선택 칩)
    └── amount_text.dart               (NEW — 금액 포맷 위젯)
```

### 구현 단계 (2주, 6단계)

**단계 1-1: Hive 초기화 + 모델 (2일)**
- Receipt, Transaction, TransactionItem Hive TypeAdapter 생성
- `build_runner`로 어댑터 코드 생성
- HiveStorage 클래스: CRUD 메서드 (addTransaction, getByDate, update, delete)
- main.dart에서 Hive.initFlutter() + 박스 등록

**단계 1-2: 5탭 네비게이션 (1일)**
- main.dart → app.dart로 MaterialApp 분리
- BottomNavigationBar 5탭: 📷 스캔 / 📋 내역 / 📅 달력 / 📊 통계 / ⚙️ 설정
- 달력/통계는 "Phase 2에서 구현" placeholder 화면
- 설정: Phase 0의 ChatGPT 로그인 + Gemini Key를 여기로 이동

**단계 1-3: 스캔 탭 — ① Scan + ② Extract (3일)**
- 촬영/파일 선택 (모바일: image_picker 카메라, PC: file_picker)
- **이미지 리사이즈**: max 1024px 장변 기준 리사이즈 + JPEG quality 80%
- AI 호출 (Phase 0 ai_provider 재사용) → 로딩 인디케이터
- 에러 처리: AI 실패 시 "수동 입력으로 전환하시겠습니까?" 안내

**단계 1-4: 리뷰 페이지 — ③ Review + ④ Save (3일)**
- AI 추출 결과 표시 (상호/날짜/품목/금액/카테고리)
- 모든 필드 수정 가능 (TextField)
- 카테고리 선택 (칩/드롭다운)
- 경비 태그 (개인지출/사업경비) 토글
- **3만원 초과 간이영수증 경고**: 결제수단이 cash + 금액 > 30,000 시 경고 배너
- [저장] → Hive에 Transaction + Receipt + TransactionItem 저장
- 원본 이미지 앱 내부 스토리지에 복사 (path_provider)

**단계 1-5: 내역 탭 + 상세 (2일)**
- 날짜별 그룹핑 목록 (편한가계부 스타일)
- 각 항목: 카테고리 아이콘 + 상호명 + 금액
- 상단: 이번 달 수입/지출 합계
- 항목 탭 → 상세 페이지: 원본 이미지 + 품목 리스트 + 수정/삭제
- 삭제 시 확인 다이얼로그

**단계 1-6: 수동 입력 + 최종 검증 (1일)**
- 수동 입력 폼: 날짜/상호/금액/카테고리/결제수단/메모
- 내역 탭 또는 스캔 탭에서 "수동 입력" 버튼
- 최종 검증 (§15 체크리스트 전체)

### Phase 1 완료 기준

```
□ flutter analyze → No issues found
□ flutter build macos --debug → 에러 0
□ flutter build apk --debug → 에러 0
□ flutter run -d macos → 5탭 네비게이션 동작
□ 스캔 → AI 추출 → 리뷰 → 저장 → 내역에 표시 (전체 루프)
□ 앱 종료 후 재시작 → 저장된 데이터 유지 (Hive 영속성)
□ 수동 입력 → 저장 → 내역에 표시
□ 원본 이미지 앱 내부 스토리지에 보관 확인
□ 3만원 초과 간이영수증 경고 표시
□ 이미지 리사이즈(1024px) 동작 확인
```

### Phase 1 클로드코드 지시문

> "docs/architecture.md를 먼저 읽고 §17 Phase 1 상세 계획에 따라 단계 1-1부터 순서대로 진행해줘. Phase 0의 lib/core/ai/*, lib/core/oauth/*, lib/core/storage/secure_storage.dart는 그대로 재사용하고, Hive DB + 5탭 네비게이션 + 스캔→리뷰→저장 플로우 + 내역 탭을 구현해라. 이미지 리사이즈(max 1024px + JPEG 80%)를 반드시 추가해라."

---

## 18. 알려진 제한사항

| # | 제한 | 대응 시점 |
|---|------|---------|
| 1 | Android OAuth 실측 미완 (빌드만 통과) | Post-Launch |
| 2 | Android 릴리스 서명 키 미생성 (템플릿만) | 사용자가 직접 작성 (release_guide.md 참조) |
| 3 | Windows EXE 최종 배포 미확인 (GitHub Actions 검증만) | 태그 v* push 후 artifact 다운로드 |
| 4 | Apple Developer Program 미가입 (ad-hoc signing) | 앱스토어 배포 시점 |
| 5 | iOS 빌드 미구성 | Apple Developer 가입 후 |
| 6 | Codex refresh flow 실측 미수행 (토큰 10일 유효) | 10일 이상 사용 시 |
| 7 | 세무 기능이 "분류/태그" 수준 (자동 계산 없음) | §23 세무 강화 리서치 |

---

## 19. Phase 2 상세 계획

### 목표

Sheetify ⑤ Track & Report를 구현하여 "저장된 데이터를 달력/통계로 시각화 + 설정 화면 정리 + 자동저장 모드"를 완성한다. Phase 2가 끝나면 "혼자 쓸 수 있는 완전한 장부 앱"이 된다.

### 신규 의존성 추가 (pubspec.yaml)

```yaml
dependencies:
  fl_chart: ^0.69.0          # 도넛/바/라인 차트
  table_calendar: ^3.1.2     # 달력 위젯
```

### 폴더 구조 변경 (Phase 1 기준 추가분만)

```
lib/features/
├── calendar/
│   ├── calendar_page.dart           (NEW — 달력 뷰)
│   └── calendar_cubit.dart          (NEW)
├── statistics/
│   ├── statistics_page.dart         (NEW — 통계 메인: 도넛+카테고리 리스트)
│   ├── statistics_cubit.dart        (NEW)
│   └── monthly_chart.dart           (NEW — 월별 추이 바 차트)
├── settings/
│   ├── settings_page.dart           (수정 — AI연결 + 카테고리 관리 + 일반 설정 통합)
│   ├── category_manager_page.dart   (NEW — 카테고리 추가/편집/삭제/순서)
│   └── settings_cubit.dart          (NEW)
└── scan/
    └── scan_cubit.dart              (수정 — 자동저장 모드 분기 추가)

lib/core/
├── models/
│   ├── category.dart                (NEW — Hive TypeAdapter)
│   └── budget.dart                  (NEW — Hive TypeAdapter, Phase 4 예산용 선행)
└── utils/
    └── statistics_calculator.dart   (NEW — 카테고리별/월별 집계 로직)
```

### 구현 단계 (2주, 5단계)

**단계 2-1: 달력 뷰 (3일)**

편한가계부 달력뷰 패턴 그대로:

```
┌──────────────────────────────┐
│  일일  [달력]  주별  월별  요약  │
│  수입 3,000,000  지출 1,234,500│
│                               │
│  월  화  수  목  금  토  일    │
│  각 날짜 셀에 수입(파랑)/지출(빨강) 합계 │
│  지출 있는 날에 색상 점(dot)    │
│                               │
│  ── 선택된 날짜 (14일) ──      │
│  GS25  3,900원  식비           │
│  스타벅스  5,500원  식비        │
└──────────────────────────────┘
```

구현 사항:
- `table_calendar` 패키지 사용
- Hive에서 해당 월 거래 목록 조회 → 날짜별 집계
- 날짜 셀에 지출 합계 표시 + 색상 마커 (지출 있는 날)
- 날짜 탭 → 하단에 해당일 거래 목록 표시
- 월 이동 (< > 화살표)
- 상단: 선택 월의 총 수입/지출 합계

**단계 2-2: 통계 — 도넛 차트 + 카테고리 비율 (3일)**

뱅크샐러드 + 편한가계부 통계 탭 패턴:

```
┌──────────────────────────────┐
│  [통계]  [예산]               │
│  < 2026년 4월 >  지출 1,234,500│
│                               │
│     ┌─────────────┐          │
│     │   🍩 도넛    │          │
│     │   차트       │          │
│     │  중앙: 총액   │          │
│     └─────────────┘          │
│                               │
│  🍔 식비      42%   518,490원 │
│  🚗 교통비    27%   333,315원 │
│  🛒 생활용품  18%   222,210원 │
│  📱 통신비     8%    98,760원 │
│  🎁 기타       5%    61,725원 │
│                               │
│  ── 월별 추이 ──              │
│  ▐▐▐▐ ▐▐▐▐▐ ▐▐▐ ▐▐▐▐▐▐     │
│  1월   2월   3월   4월        │
└──────────────────────────────┘
```

구현 사항:
- `fl_chart` PieChart → 도넛 차트 (카테고리별 색상)
- 도넛 중앙에 총 지출 금액 표시
- 카테고리별 리스트: 아이콘 + 이름 + 퍼센트 + 금액
- 카테고리 항목 탭 → 해당 카테고리 거래 필터 목록
- 월별 추이 바 차트 (최근 6개월)
- 월 이동 (< > 화살표)
- `statistics_calculator.dart`: Hive 데이터 → 카테고리별/월별 집계 순수 함수

**단계 2-3: 설정 화면 통합 정리 (2일)**

```
┌──────────────────────────────┐
│  ⚙️ 설정                      │
│                               │
│  ── AI 연결 ──                │
│  ChatGPT: ✅ 연결됨 (acc_f5aa..)│
│           [로그아웃]           │
│  Gemini:  ✅ 키 저장됨         │
│           [키 변경] [삭제]     │
│                               │
│  ── 카테고리 관리 ──           │
│  [카테고리 편집 →]             │
│                               │
│  ── 일반 설정 ──              │
│  월 시작일: [1일 ▾]           │
│  기본 경비 태그: [개인지출 ▾]  │
│  자동저장: [OFF ▾]            │
│                               │
│  ── 데이터 ──                 │
│  [데이터 백업]  [데이터 복원]  │
│  거래 수: 127건 / 이미지: 89장 │
│                               │
│  앱 버전: 0.2.0               │
└──────────────────────────────┘
```

구현 사항:
- Phase 0의 ChatGPT 로그인 + Gemini Key UI를 설정 탭으로 이동 (이미 Phase 1에서 진행했으면 정리만)
- 카테고리 관리 화면: 기본 카테고리 목록 + 아이콘/색상 + 추가/편집/삭제/순서변경
- Category Hive 모델 추가 (id, name, icon emoji, colorHex, isDefault, taxCategory)
- 일반 설정: 월 시작일 (1~28), 기본 경비 태그 (personal/business), 자동저장 on/off
- 데이터 현황: 거래 건수, 이미지 수, 저장 용량

**단계 2-4: 자동저장 모드 (1일)**

스캔 플로우에 분기 추가:
```
스캔 → AI 추출 → confidence 확인
  ├─ confidence ≥ 0.9 AND 자동저장 ON → 리뷰 건너뛰고 바로 Hive 저장 → 토스트 "저장 완료"
  └─ confidence < 0.9 OR 자동저장 OFF → 리뷰 화면으로 이동 (기존 플로우)
```

구현 사항:
- 설정의 `autoSave` 플래그를 Hive Settings 박스에 저장
- scan_cubit.dart에서 AI 추출 후 confidence + autoSave 체크 분기
- 자동저장 시 SnackBar/Toast로 "✅ GS25 강남역점 3,900원 저장됨" 알림
- 자동저장이어도 내역 탭에서 나중에 수정 가능

**단계 2-5: 최종 검증 (1일)**

- §15 체크리스트 전체 실행
- 달력 뷰: 거래 있는 날짜에 마커 표시 + 탭 → 목록
- 통계: 도넛 차트 정확도 (합계 = 100%)
- 자동저장: confidence 90%+ 영수증으로 실측
- 카테고리 관리: 추가/삭제 후 기존 거래에 영향 없는지

### Phase 2 완료 기준

```
□ flutter analyze → No issues found
□ flutter build macos --debug → 에러 0
□ flutter build apk --debug → 에러 0
□ 달력 탭: 월 이동 + 날짜별 합계 + 탭→거래목록
□ 통계 탭: 도넛 차트 + 카테고리 비율 + 월별 추이 바 차트
□ 설정: AI 연결 상태 + 카테고리 관리 + 일반 설정
□ 자동저장: confidence 90%+ 시 리뷰 건너뛰고 저장 + 토스트
□ 카테고리 추가/편집/삭제 동작 + 기존 거래 무영향
□ 앱 재시작 후 달력/통계 데이터 유지
```

### Phase 2 클로드코드 지시문

> "docs/architecture.md를 먼저 읽고 §19 Phase 2 상세 계획에 따라 단계 2-1부터 순서대로 진행해줘. Phase 0~1의 기존 코드(lib/core/*, lib/features/scan/*, lib/features/transactions/*)는 그대로 재사용하고, 달력 뷰(table_calendar) + 통계(fl_chart 도넛+바) + 설정 화면 통합 + 자동저장 모드를 구현해라. 달력/통계의 데이터는 Hive에서 조회하되, 집계 로직은 statistics_calculator.dart에 순수 함수로 분리해라."

---

## 20. Phase 3 상세 계획

### 목표

"혼자 쓰는 장부"를 "팀이 쓰는 장부 + 세무 신고 도구"로 확장한다.
구체적으로 4가지를 만든다:
1. 구글 시트 동기화 (팀원 영수증 → 공유 시트에 자동 적재)
2. 오프라인 큐잉 (인터넷 없이 저장 → 복구 시 자동 동기화)
3. 간편장부 엑셀 내보내기 (국세청 양식 호환)
4. 데이터 백업/복원 (JSON + 이미지 ZIP)

### 신규 의존성 (pubspec.yaml에 추가)

```yaml
dependencies:
  googleapis: ^13.2.0               # Google Sheets API v4
  googleapis_auth: ^1.6.0           # Google OAuth2 (서비스 계정 아님, 사용자 동의 방식)
  google_sign_in: ^6.2.2            # 구글 로그인 UI
  excel: ^4.0.6                     # 엑셀 파일 생성 (.xlsx)
  archive: ^3.6.1                   # ZIP 압축 (이미지 백업용)
  connectivity_plus: ^6.1.0         # 네트워크 상태 감지 (오프라인 큐잉)
  share_plus: ^10.1.2               # 파일 공유 (내보내기 후 공유 시트에 전송)
```

### 폴더 구조 변경 (Phase 2 기준 추가분만)

```
lib/core/
├── sheets/
│   ├── google_auth_service.dart       (NEW — google_sign_in + googleapis_auth 연결)
│   ├── sheets_service.dart            (NEW — Sheets API v4 CRUD: 헤더 생성, 행 추가, 시트 존재 확인)
│   └── sync_queue.dart                (NEW — 오프라인 큐: Hive 'sync_queue' 박스 + 재시도 로직)
├── export/
│   ├── simple_ledger_exporter.dart    (NEW — 간편장부 양식 .xlsx 생성)
│   └── backup_service.dart            (NEW — JSON + 이미지 ZIP 내보내기/복원)
└── models/
    └── sync_item.dart                 (NEW — Hive TypeAdapter: 동기화 대기 항목)

lib/features/
├── settings/
│   └── settings_page.dart             (수정 — 구글 계정 연결 + 시트 ID + 백업/복원 + 내보내기 추가)
├── transactions/
│   └── transactions_cubit.dart        (수정 — 저장 시 sync_queue에 동기화 대기 항목 추가)
└── scan/
    └── review_page.dart               (수정 — 저장 시 sync_queue에 동기화 대기 항목 추가)
```

### 구현 단계 (2주, 6단계)

**단계 3-1: 구글 로그인 + Sheets API 연결 (3일)**

구현할 파일:
- `lib/core/sheets/google_auth_service.dart`
- `lib/core/sheets/sheets_service.dart`
- `lib/features/settings/settings_page.dart` (구글 계정 섹션 추가)

상세 스펙:

1. `google_auth_service.dart`:
   - `GoogleSignIn(scopes: ['https://www.googleapis.com/auth/spreadsheets'])` 인스턴스 생성
   - `Future<AuthClient?> signIn()` → google_sign_in 로그인 → googleapis_auth AuthClient 반환
   - `Future<void> signOut()` → 로그아웃 + 저장된 시트 ID 클리어
   - `bool get isSignedIn` → 현재 로그인 상태
   - `String? get userEmail` → 로그인된 이메일 (UI 표시용)
   - AuthClient를 flutter_secure_storage에 캐싱하지 않음 (google_sign_in이 자체 관리)

2. `sheets_service.dart`:
   - 생성자: `SheetsService(AuthClient client)`
   - `Future<void> ensureHeader(String spreadsheetId)`:
     - Sheet1의 1행 조회 → 비어있으면 헤더 행 삽입
     - 헤더: `날짜 | 시간 | 상호명 | 사업자번호 | 공급가액 | 부가세 | 합계 | 결제수단 | 카테고리 | 세무분류 | 경비구분 | 담당자 | 메모`
   - `Future<void> appendTransaction(String spreadsheetId, Transaction tx)`:
     - `spreadsheets.values.append` 호출
     - valueInputOption: `USER_ENTERED` (숫자 자동 인식)
     - range: `Sheet1!A:M`
   - `Future<void> appendBatch(String spreadsheetId, List<Transaction> txList)`:
     - 여러 건 한번에 추가 (오프라인 큐 처리용)

3. 설정 화면 구글 계정 섹션:
   ```
   ── 팀 공유 (구글 시트) ──
   구글 계정: ✅ user@gmail.com  [로그아웃]
   시트 ID:  [____________________] [연결 테스트]
   자동 동기화: [ON ▾]
   동기화 대기: 3건  [지금 동기화]
   ```
   - 시트 ID는 Hive Settings 박스에 저장
   - [연결 테스트] → ensureHeader 호출 → 성공/실패 표시
   - 시트 ID는 구글 시트 URL에서 `/d/{여기}/edit` 부분을 안내 텍스트로 설명

**단계 3-2: 오프라인 큐잉 + 자동 동기화 (2일)**

구현할 파일:
- `lib/core/sheets/sync_queue.dart`
- `lib/core/models/sync_item.dart`
- `lib/features/scan/review_page.dart` (수정)
- `lib/features/transactions/transactions_cubit.dart` (수정)

상세 스펙:

1. `sync_item.dart` (Hive TypeAdapter typeId: 4):
   ```dart
   @HiveType(typeId: 4)
   class SyncItem {
     @HiveField(0) String id;              // UUID
     @HiveField(1) String transactionId;   // 연결된 Transaction ID
     @HiveField(2) DateTime createdAt;
     @HiveField(3) int retryCount;         // 재시도 횟수 (최대 5)
     @HiveField(4) String? lastError;      // 마지막 에러 메시지
   }
   ```

2. `sync_queue.dart`:
   - `Future<void> enqueue(String transactionId)` → SyncItem 생성 → Hive 'sync_queue' 박스에 저장
   - `Future<void> processQueue(SheetsService sheets, String spreadsheetId)`:
     - 큐의 모든 SyncItem 순회
     - 각 항목: transactionId로 Transaction 조회 → sheets.appendTransaction 호출
     - 성공 시: SyncItem 삭제 + Transaction.syncedToSheet = true
     - 실패 시: retryCount++ + lastError 갱신. retryCount >= 5면 스킵 (설정에서 수동 재시도)
   - `int get pendingCount` → 대기 건수 (설정 화면 표시용)
   - connectivity_plus로 네트워크 상태 감지:
     - 오프라인 → 큐에만 쌓음
     - 온라인 복구 시 → processQueue 자동 호출

3. 저장 시 동기화 연결:
   - review_page.dart의 [저장] 로직 끝에: `if (settings.sheetId != null && settings.autoSync) syncQueue.enqueue(tx.id)`
   - 수동 입력 저장 시에도 동일하게 enqueue

**단계 3-3: 간편장부 엑셀 내보내기 (2일)**

구현할 파일:
- `lib/core/export/simple_ledger_exporter.dart`
- `lib/features/settings/settings_page.dart` (내보내기 버튼 추가)

상세 스펙:

1. `simple_ledger_exporter.dart`:
   - `Future<File> exportToXlsx({required int year, int? month})`:
     - excel 패키지로 .xlsx 파일 생성
     - **시트 1: 간편장부** (국세청 양식 호환)
       - 헤더: `날짜 | 거래처 | 적요 | 수입금액 | 비용금액 | 고정자산증감 | 비고`
       - 각 Transaction → 1행. expenseType이 'business'인 것만 포함
       - 적요: `{category} - {storeName}` (예: "식비 - GS25 강남역점")
       - 수입금액: 수입 거래면 total, 아니면 0
       - 비용금액: 지출 거래면 total, 아니면 0
       - 고정자산증감: 0 (간편장부 수준에서는 미사용)
       - 월별 소계 행 삽입
       - 맨 아래 연간 합계 행
     - **시트 2: 전체 거래 상세**
       - 모든 거래 (personal + business 모두)
       - 날짜/시간/상호/사업자번호/공급가액/부가세/합계/결제수단/카테고리/세무분류/경비구분/메모
     - **시트 3: 카테고리별 요약**
       - 카테고리별 건수/합계/비율
     - 파일 저장: `path_provider`의 getApplicationDocumentsDirectory() + `간편장부_2026.xlsx`

2. 설정 화면 내보내기 섹션:
   ```
   ── 내보내기 ──
   [간편장부 내보내기 (.xlsx)]  → 연도 선택 → 생성 → share_plus로 공유
   [월별 내보내기]              → 연월 선택 → 생성 → share_plus로 공유
   ```
   - 생성 후 `Share.shareXFiles`로 공유 시트 열기 (카카오톡, 이메일 등으로 전송 가능)

**단계 3-4: 데이터 백업/복원 (2일)**

구현할 파일:
- `lib/core/export/backup_service.dart`
- `lib/features/settings/settings_page.dart` (백업/복원 버튼 추가)

상세 스펙:

1. `backup_service.dart`:
   - `Future<File> createBackup()`:
     - 임시 디렉토리에 폴더 구조 생성:
       ```
       easy_ledger_backup_20260415/
       ├── data.json          (모든 Hive 박스 → JSON 직렬화)
       │   ├── receipts: [...]
       │   ├── transactions: [...]
       │   ├── transaction_items: [...]
       │   ├── categories: [...]
       │   └── settings: {...}
       └── images/
           ├── uuid1.jpg
           ├── uuid2.jpg
           └── ...
       ```
     - archive 패키지로 ZIP 압축 → `easy_ledger_backup_20260415.zip`
     - share_plus로 공유

   - `Future<BackupResult> restoreFromZip(File zipFile)`:
     - ZIP 해제 → data.json 파싱 → 유효성 검증
     - 복원 전 확인 다이얼로그: "현재 데이터 {N}건이 있습니다. 백업 데이터 {M}건으로 교체할까요?"
     - 옵션: "덮어쓰기" (전체 교체) / "병합" (중복 ID 스킵, 신규만 추가)
     - Hive 박스 클리어 → JSON에서 객체 복원 → 이미지 파일 복사
     - BackupResult: 복원된 거래 수, 이미지 수, 스킵된 수

2. 설정 화면 데이터 섹션:
   ```
   ── 데이터 관리 ──
   거래: 127건 / 이미지: 89장 / 용량: 45.2MB
   [백업 생성 (.zip)]     → 생성 → share_plus
   [백업에서 복원]         → file_picker로 zip 선택 → 확인 → 복원
   [전체 삭제]            → 2단계 확인 ("정말 삭제하시겠습니까?" + "되돌릴 수 없습니다")
   ```

**단계 3-5: 세무 태그 강화 (1일)**

구현할 파일:
- `lib/features/scan/review_page.dart` (수정)
- `lib/features/transactions/transaction_detail_page.dart` (수정)
- `lib/features/manual_input/manual_input_page.dart` (수정)

상세 스펙:
- 리뷰/상세/수동입력에서 expenseType이 'business'일 때 세무 카테고리(taxCategory) 선택 드롭다운 활성화:
  - 복리후생비 / 접대비 / 소모품비 / 차량유지비 / 통신비 / 교육훈련비 / 여비교통비 / 지급수수료 / 광고선전비 / 기타
- 세무 카테고리는 간편장부 엑셀의 적요란에 반영
- 내역 탭의 거래 카드에 사업경비 뱃지 표시 (작은 태그)

**단계 3-6: 최종 검증 (2일)**

§15 체크리스트 전체 + Phase 3 전용 검증:
```
□ flutter analyze → No issues found
□ flutter build macos --debug → 에러 0
□ flutter build apk --debug → 에러 0
□ 구글 로그인 → 이메일 표시 → 로그아웃 → 재로그인
□ 시트 ID 입력 → [연결 테스트] → 헤더 자동 생성 확인 (구글 시트 직접 열어서 확인)
□ 영수증 저장 → 구글 시트에 행 추가 확인 (실제 시트에서 확인)
□ 오프라인 테스트: 와이파이 끄고 → 영수증 3건 저장 → 와이파이 켜기 → 자동 동기화 → 시트에 3건 추가
□ 간편장부 내보내기 → .xlsx 파일 → 엑셀/구글시트에서 열기 → 헤더/금액/소계 확인
□ 백업 생성 → .zip 파일 → 앱 데이터 전체 삭제 → 복원 → 거래/이미지 복원 확인
□ 세무 태그: business 선택 시 taxCategory 드롭다운 활성 → 간편장부에 반영
□ 동기화 대기 건수 설정 화면에 정확히 표시
```

### Phase 3 완료 기준

```
□ 구글 로그인 + 시트 ID 연결 + 헤더 자동 생성
□ 영수증 저장 시 자동으로 구글 시트에 행 추가
□ 오프라인 → 온라인 복귀 시 대기 건 자동 동기화
□ 간편장부 .xlsx 내보내기 (국세청 양식 호환, 월별 소계, 연간 합계)
□ 데이터 백업 .zip (JSON + 이미지) + 복원 (덮어쓰기/병합)
□ 세무 카테고리 선택 → 간편장부에 반영
□ 빌드 검증 (analyze + macos + apk)
```

### Phase 3 클로드코드 지시문

```
docs/architecture.md를 먼저 읽고 §20 Phase 3 상세 계획을 따라라.

■ 사전 작업
1. pubspec.yaml에 아래 의존성 추가 후 flutter pub get:
   googleapis: ^13.2.0, googleapis_auth: ^1.6.0, google_sign_in: ^6.2.2,
   excel: ^4.0.6, archive: ^3.6.1, connectivity_plus: ^6.1.0, share_plus: ^10.1.2
2. lib/core/models/sync_item.dart 생성 (Hive TypeAdapter typeId: 4)
3. build_runner 실행: dart run build_runner build --delete-conflicting-outputs

■ 단계 3-1: 구글 시트 연결
- lib/core/sheets/google_auth_service.dart 생성: GoogleSignIn(scopes: spreadsheets) + signIn/signOut/isSignedIn/userEmail
- lib/core/sheets/sheets_service.dart 생성: ensureHeader(spreadsheetId) + appendTransaction(spreadsheetId, tx) + appendBatch(spreadsheetId, txList)
- 설정 화면에 구글 계정 섹션 추가: 로그인 상태 + 시트 ID 입력 + [연결 테스트] 버튼
- Sheets API: spreadsheets.values.append, valueInputOption=USER_ENTERED, range=Sheet1!A:M

■ 단계 3-2: 오프라인 큐잉
- lib/core/sheets/sync_queue.dart 생성: enqueue(txId) + processQueue(sheets, sheetId) + pendingCount
- review_page.dart와 manual_input 저장 로직 끝에 enqueue 호출 추가
- connectivity_plus로 네트워크 상태 감지: 온라인 복귀 시 processQueue 자동 호출
- 재시도 최대 5회, 초과 시 스킵 + lastError 기록

■ 단계 3-3: 간편장부 엑셀
- lib/core/export/simple_ledger_exporter.dart 생성
- 시트1: 간편장부 (날짜/거래처/적요/수입/비용/고정자산/비고) — business만
- 시트2: 전체 거래 상세 — 모든 거래
- 시트3: 카테고리별 요약
- 월별 소계 행 + 연간 합계 행 삽입
- 생성 후 share_plus.Share.shareXFiles로 공유

■ 단계 3-4: 백업/복원
- lib/core/export/backup_service.dart 생성
- createBackup(): Hive 전체 → data.json + images/ → ZIP
- restoreFromZip(file): ZIP 해제 → 확인 다이얼로그 → 덮어쓰기 or 병합 → Hive 복원
- 설정 화면에 백업/복원/전체삭제 버튼 추가

■ 단계 3-5: 세무 태그 강화
- expenseType='business' 선택 시 taxCategory 드롭다운 활성화
- 세무 카테고리: 복리후생비/접대비/소모품비/차량유지비/통신비/교육훈련비/여비교통비/지급수수료/광고선전비/기타
- 간편장부 적요란에 taxCategory 반영

■ 단계 3-6: 검증
- flutter analyze, flutter build macos --debug, flutter build apk --debug
- 구글 시트 실제 연결 + 행 추가 확인
- 오프라인 큐잉 테스트 (네트워크 끊고 → 복구 → 자동 동기화)
- .xlsx 파일 생성 → 엑셀에서 열어서 양식 확인
- 백업 → 전체 삭제 → 복원 → 데이터 무결성 확인

■ 규칙
- Phase 0~2의 기존 코드(lib/core/ai/*, lib/core/oauth/*, lib/features/scan/*, lib/features/transactions/*, lib/features/calendar/*, lib/features/statistics/*)는 기능 변경하지 마. 저장 로직 끝에 sync enqueue 추가만 허용.
- 수정한 파일 목록과 이유를 매번 보고해.
- 이번에 요청하지 않은 것은 건드리지 마.
- "되는 것 같다" 금지 → 실제 실행 결과만 보고.
- 각 단계 완료 후 flutter analyze 통과 확인.
```

---

## 21. Phase 4 상세 계획

### 목표

**"개발자용 디버그 앱"을 "실제 사용자가 설치해서 쓰는 앱"으로 전환한다.**
핵심은 UX 개선 + 정식 배포 가능한 빌드 파이프라인 구축이다.

구체적으로 6가지:
1. 예산 설정 + 초과 알림 (돈 관리 기능 강화)
2. 배치 스캔 (여러 장 한번에 처리)
3. 검색 + 필터 (데이터 누적 대비)
4. 앱 아이콘 + 스플래시 (정식 앱 외형)
5. 릴리스 빌드 (macOS .app, Android APK, Windows EXE)
6. GitHub Actions 자동 빌드 (Windows EXE를 Mac에서 push만으로 생성)

### 신규 의존성 (pubspec.yaml)

```yaml
dependencies:
  flutter_launcher_icons: ^0.14.1    # dev, 앱 아이콘 자동 생성
  flutter_native_splash: ^2.4.2      # dev, 스플래시 자동 생성

dev_dependencies:
  flutter_launcher_icons: ^0.14.1
  flutter_native_splash: ^2.4.2
```

### 폴더 구조 변경 (Phase 3 기준 추가분)

```
lib/
├── core/
│   └── models/
│       └── budget.dart                   (NEW — Hive TypeAdapter typeId:5)
├── features/
│   ├── budget/
│   │   ├── budget_page.dart              (NEW — 카테고리별 예산 설정)
│   │   ├── budget_cubit.dart             (NEW)
│   │   └── budget_widget.dart            (NEW — 예산 진행 바, 통계 탭에 삽입)
│   ├── scan/
│   │   └── batch_scan_page.dart          (NEW — 여러 장 스캔)
│   └── transactions/
│       ├── search_bar.dart               (NEW — 검색 위젯)
│       └── filter_sheet.dart             (NEW — 필터 바텀시트)

프로젝트 루트/
├── assets/
│   ├── icon/
│   │   └── app_icon.png                  (NEW — 1024×1024 원본)
│   └── splash/
│       └── splash_logo.png               (NEW — 512×512)
├── .github/
│   └── workflows/
│       ├── build_macos.yml               (NEW — macOS 릴리스 자동 빌드)
│       ├── build_android.yml             (NEW — APK 릴리스 자동 빌드)
│       └── build_windows.yml             (NEW — Windows EXE 자동 빌드)
└── windows/                              (NEW — flutter create --platforms=windows로 생성)
```

### 구현 단계 (2주, 6단계)

**단계 4-1: 예산 설정 + 초과 알림 (2일)**

구현할 파일:
- `lib/core/models/budget.dart` (Hive TypeAdapter)
- `lib/features/budget/budget_page.dart`, `budget_cubit.dart`, `budget_widget.dart`

상세 스펙:

1. `budget.dart` (typeId: 5):
   ```
   Budget {
     String id
     String categoryId       // 어느 카테고리의 예산인지
     int monthlyAmount       // 월 예산 금액
     int year                // 적용 연도
     int? month              // null이면 매월 고정, 값이 있으면 특정 월만
   }
   ```

2. 예산 설정 페이지:
   ```
   ┌──────────────────────────────┐
   │  💰 예산 설정                 │
   │  < 2026년 4월 >              │
   │                              │
   │  총 예산        [1,500,000원] │
   │                              │
   │  ── 카테고리별 ──             │
   │  🍔 식비       [500,000원] > │
   │  🚗 교통비     [200,000원] > │
   │  🛒 생활용품   [300,000원] > │
   │  (카테고리 추가...)           │
   │                              │
   │  [저장]                      │
   └──────────────────────────────┘
   ```

3. 통계 탭에 예산 진행 바 삽입:
   ```
   ── 이번 달 예산 ──
   식비     ▓▓▓▓▓▓▓░░░  518,490 / 500,000 ⚠️ 초과 3.7%
   교통비   ▓▓▓▓▓░░░░░  108,500 / 200,000  54%
   생활용품 ▓▓░░░░░░░░   72,210 / 300,000  24%
   ```
   - 100% 초과 시 빨간색 + ⚠️ 아이콘
   - 80~100%는 주황색
   - 80% 미만은 초록색

4. 설정 탭에 "예산 관리" 항목 추가

**단계 4-2: 배치 스캔 (3일)**

구현할 파일:
- `lib/features/scan/batch_scan_page.dart`
- `lib/features/scan/scan_cubit.dart` (수정)

상세 스펙:

1. 스캔 탭 상단에 "단일 / 배치" 토글 추가

2. 배치 스캔 플로우:
   ```
   ┌──────────────────────────────┐
   │  📷 배치 스캔 (5장 선택됨)    │
   │                              │
   │  [1] ✅ GS25 강남역 3,900원  │
   │  [2] ⏳ 처리 중...           │
   │  [3] ⏳ 대기 중              │
   │  [4] ❌ 실패 [재시도] [수동] │
   │  [5] ⏳ 대기 중              │
   │                              │
   │  ▓▓▓▓▓░░░░░ 1 / 5 완료      │
   │                              │
   │  [모두 저장]   [선택 저장]    │
   └──────────────────────────────┘
   ```

3. 구현:
   - file_picker/image_picker로 multi-select 허용
   - 최대 10장 제한 (토큰 비용 폭증 방지)
   - 병렬 처리 (Future.wait로 최대 3개 동시 AI 호출)
   - 각 영수증마다 개별 상태 표시 (대기/처리중/성공/실패)
   - 실패 건: [재시도] 또는 [수동 입력으로] 선택
   - 성공 건은 모두 confidence와 상관없이 리뷰 화면 거치지 않고 바로 저장 준비 상태
   - [모두 저장] → 성공한 건만 일괄 Hive 저장 + sync_queue enqueue
   - 저장 후 내역 탭으로 이동

4. 품질 이슈 방지:
   - 배치 모드에서는 자동저장 flag와 무관하게 리뷰 옵션 제공
   - 체크박스로 각 영수증 선택/해제 가능

**단계 4-3: 검색 + 필터 (2일)**

구현할 파일:
- `lib/features/transactions/search_bar.dart`
- `lib/features/transactions/filter_sheet.dart`
- `lib/features/transactions/transactions_page.dart` (수정)

상세 스펙:

1. 내역 탭 상단에 검색/필터 UI 추가:
   ```
   ┌──────────────────────────────┐
   │  [🔍 검색]      [⚙️ 필터]    │
   │  < 2026년 4월 >              │
   └──────────────────────────────┘
   ```

2. 검색:
   - TextField 탭 시 검색 모드 진입
   - 검색 대상: 상호명, 메모, 품목명
   - 실시간 검색 (debounce 300ms)
   - Hive 전체 거래에서 검색 (월 필터 무시)

3. 필터 바텀시트:
   ```
   ┌──────────────────────────────┐
   │  ⚙️ 필터                     │
   │                              │
   │  기간: [이번 달 ▾]            │
   │        (이번 달/지난 달/올해/  │
   │         사용자 지정)          │
   │                              │
   │  카테고리: ☑️ 식비            │
   │           ☑️ 교통비           │
   │           ☐ 생활용품         │
   │           ... (다중 선택)     │
   │                              │
   │  경비 구분: ◉ 전체            │
   │           ○ 개인지출         │
   │           ○ 사업경비         │
   │                              │
   │  금액: [최소] ~ [최대]        │
   │                              │
   │  결제수단: ☑️ 카드 ☑️ 현금    │
   │                              │
   │  [초기화]      [적용]         │
   └──────────────────────────────┘
   ```

4. 필터 조건 동시 적용 (AND 연산)

5. 결과 상단에 필터 요약 표시 + [X] 버튼으로 개별 해제

**단계 4-4: 앱 아이콘 + 스플래시 + 앱 이름 (2일)**

구현:

1. 앱 아이콘 원본 제작 (사용자가 준비):
   - 1024×1024 PNG, 여백 포함
   - 테마: 영수증 + 체크 아이콘
   - 배경색 우리 앱 메인 녹색 (현재 UI 녹색 톤)
   - `assets/icon/app_icon.png`에 배치

2. 스플래시 이미지:
   - 512×512 PNG, 투명 배경
   - `assets/splash/splash_logo.png`에 배치

3. pubspec.yaml에 설정 추가:
   ```yaml
   flutter_launcher_icons:
     android: true
     ios: true
     image_path: "assets/icon/app_icon.png"
     macos:
       generate: true
       image_path: "assets/icon/app_icon.png"
     windows:
       generate: true
       image_path: "assets/icon/app_icon.png"
       icon_size: 256

   flutter_native_splash:
     color: "#2E7D32"
     image: "assets/splash/splash_logo.png"
     android: true
     ios: true
   ```

4. 자동 생성:
   - `dart run flutter_launcher_icons`
   - `dart run flutter_native_splash:create`

5. 앱 이름 설정:
   - macOS: `macos/Runner/Info.plist`의 `CFBundleName`, `CFBundleDisplayName` → `쉬운장부`
   - Android: `android/app/src/main/AndroidManifest.xml`의 `android:label` → `쉬운장부`
   - Windows: `windows/runner/main.cpp`의 window.CreateAndShow 제목 → `쉬운장부`

**단계 4-5: 릴리스 빌드 (2일)**

1. **macOS 릴리스 빌드**:
   - `flutter build macos --release`
   - 결과물: `build/macos/Build/Products/Release/쉬운장부.app`
   - `/Applications`에 복사 → Launchpad에 아이콘 생성
   - Apple Developer Program 없이 배포하려면 사용자가 "시스템 설정 → 보안 → 이 앱 열기 허용" 클릭 필요 (경고 문서 추가)

2. **Android APK 릴리스 빌드**:
   - 서명 키 생성: `keytool -genkey -v -keystore ~/easy_ledger_release.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
   - `android/key.properties` 생성 (gitignore에 추가)
   - `android/app/build.gradle.kts`에 signingConfigs + release 블록 설정
   - `flutter build apk --release` or `flutter build appbundle --release`
   - 결과물: `build/app/outputs/flutter-apk/app-release.apk`
   - 테스트 기기에서 설치 확인

3. **Windows 빌드 scaffold 추가**:
   - `flutter create --platforms=windows .`
   - `windows/` 폴더 생성 확인
   - (실제 EXE 빌드는 단계 4-6의 GitHub Actions에서 처리)

4. 문서 추가: `docs/release_guide.md`
   - 각 플랫폼 릴리스 빌드 명령어
   - 설치 방법
   - 앱 서명 관련 주의사항

**단계 4-6: GitHub Actions 자동 빌드 (1일)**

구현할 파일:
- `.github/workflows/build_macos.yml`
- `.github/workflows/build_android.yml`
- `.github/workflows/build_windows.yml`

상세 스펙:

1. **build_windows.yml** (핵심 — Mac에서 Windows EXE 불가 해결):
   ```yaml
   name: Build Windows
   on:
     push:
       tags: ['v*']
     workflow_dispatch:
   jobs:
     build:
       runs-on: windows-latest
       steps:
         - uses: actions/checkout@v4
         - uses: subosito/flutter-action@v2
           with:
             flutter-version: '3.41.6'
             channel: 'stable'
         - run: flutter config --enable-windows-desktop
         - run: flutter pub get
         - run: flutter build windows --release
         - uses: actions/upload-artifact@v4
           with:
             name: easy-ledger-windows
             path: build/windows/x64/runner/Release/
   ```
   - `v0.4.0` 같은 태그 push하면 자동 빌드
   - Actions → Artifacts에서 Windows 빌드 결과물 다운로드
   - GitHub Release로 자동 업로드 (옵션)

2. **build_macos.yml**:
   - `runs-on: macos-latest`
   - 같은 패턴으로 `flutter build macos --release`
   - .app 압축해서 artifact 업로드

3. **build_android.yml**:
   - `runs-on: ubuntu-latest`
   - Android SDK 설정 + `flutter build apk --release`
   - 키스토어는 GitHub Secrets로 주입 (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD` 등)
   - APK artifact 업로드

4. 릴리스 플로우:
   ```
   개발자가 Mac에서 코드 작성
     → git tag v0.4.0
     → git push origin v0.4.0
     → GitHub Actions 3개 워크플로우 동시 실행
     → 1) macOS .app   (클라우드 Mac 빌드)
        2) Android APK (클라우드 Linux 빌드)
        3) Windows EXE (클라우드 Windows 빌드)
     → 각 artifact 다운로드 → 사용자에게 배포
   ```

### Phase 4 완료 기준

```
□ flutter analyze → No issues found
□ flutter build macos --release → 쉬운장부.app 생성
□ flutter build apk --release → app-release.apk 생성 (서명 완료)
□ GitHub Actions Windows 워크플로우 성공 → .exe artifact 생성
□ macOS .app을 /Applications에 설치 → Launchpad 아이콘으로 실행 가능
□ Android APK를 실기기에 설치 → 아이콘으로 실행 가능
□ Windows .exe 실행 가능 (Windows PC 있으면)
□ 예산 설정 → 통계 탭에서 진행 바 표시 + 초과 경고
□ 배치 스캔: 3~5장 한번에 AI 추출 → 선택 저장
□ 내역 탭 검색: "GS25" 입력 → 해당 거래 필터링
□ 내역 탭 필터: 카테고리 + 기간 + 금액 범위 동시 적용
□ 앱 아이콘이 모든 플랫폼에서 표시됨
□ 스플래시 화면이 앱 시작 시 뜸
```

### Phase 4 Codex 지시문

```
docs/architecture.md를 먼저 읽고 §21 Phase 4 상세 계획을 따라라.

■ 사전 작업
1. pubspec.yaml dev_dependencies에 flutter_launcher_icons: ^0.14.1, flutter_native_splash: ^2.4.2 추가
2. flutter pub get

■ 단계 4-1: 예산 설정
- lib/core/models/budget.dart 생성 (Hive TypeAdapter typeId:5, id/categoryId/monthlyAmount/year/month)
- build_runner로 어댑터 생성
- lib/features/budget/budget_page.dart, budget_cubit.dart, budget_widget.dart 생성
- 설정 탭에 "예산 관리" 항목 추가 → 카테고리별 월 예산 설정 UI
- lib/features/statistics/statistics_page.dart 수정: 상단에 예산 진행 바 삽입 (초록/주황/빨강 3단계)
- 예산 대비 지출률 계산 로직은 statistics_calculator.dart에 순수 함수로 추가

■ 단계 4-2: 배치 스캔
- lib/features/scan/batch_scan_page.dart 생성
- 스캔 탭 상단에 "단일/배치" 토글 추가
- 배치: file_picker multi-select (최대 10장) → Future.wait로 최대 3개 병렬 AI 호출
- 각 영수증 상태 표시 (대기/처리중/성공/실패)
- 실패 건: [재시도] [수동 입력] 선택
- [모두 저장] → 성공 건만 Hive 저장 + sync_queue enqueue

■ 단계 4-3: 검색 + 필터
- lib/features/transactions/search_bar.dart: TextField + debounce 300ms, 상호명/메모/품목명 검색
- lib/features/transactions/filter_sheet.dart: 바텀시트, 기간/카테고리 다중선택/경비구분/금액범위/결제수단
- transactions_page.dart 수정: 상단에 검색/필터 UI 추가, 필터 적용 시 요약 배지 표시
- 필터는 AND 연산

■ 단계 4-4: 앱 아이콘 + 스플래시 + 앱 이름
- assets/icon/app_icon.png (사용자가 1024x1024 제공), assets/splash/splash_logo.png (512x512)
- pubspec.yaml에 flutter_launcher_icons, flutter_native_splash 설정 추가 (android/ios/macos/windows 모두)
- dart run flutter_launcher_icons
- dart run flutter_native_splash:create
- macOS Info.plist CFBundleName/CFBundleDisplayName → "쉬운장부"
- Android AndroidManifest.xml android:label → "쉬운장부"
- Windows main.cpp 윈도우 제목 → "쉬운장부"

■ 단계 4-5: 릴리스 빌드 설정
- Android 서명 키 생성 가이드를 docs/release_guide.md에 작성 (키 파일은 커밋하지 않음, gitignore에 추가)
- android/app/build.gradle.kts에 signingConfigs + buildTypes.release 설정
- android/key.properties 템플릿 생성 (실제 값은 사용자가 채움)
- flutter create --platforms=windows . 실행 → windows/ 폴더 scaffold 생성
- flutter build macos --release, flutter build apk --release 성공 확인
- docs/release_guide.md에 각 플랫폼 빌드/설치 가이드 작성

■ 단계 4-6: GitHub Actions
- .github/workflows/build_macos.yml 생성 (macos-latest, flutter 3.41.6, flutter build macos --release, artifact 업로드)
- .github/workflows/build_android.yml 생성 (ubuntu-latest, keystore를 secrets에서 base64 디코드, flutter build apk --release, artifact 업로드)
- .github/workflows/build_windows.yml 생성 (windows-latest, flutter build windows --release, artifact 업로드)
- 트리거: push tag v* + workflow_dispatch
- docs/release_guide.md에 "태그 푸시 → Actions에서 artifact 다운로드" 플로우 문서화

■ 규칙
- Phase 0~3의 기존 코드는 건드리지 마. UI 통합이 필요한 statistics_page.dart와 transactions_page.dart, 스캔 탭 토글만 최소 수정 허용.
- 수정한 파일 목록과 이유를 매번 보고해.
- 이번에 요청하지 않은 것은 건드리지 마.
- "되는 것 같다" 금지 → 실제 실행 결과만 보고.
- 각 단계 완료 후 flutter analyze 통과 확인.

■ 검증
- flutter analyze, flutter build macos --debug, flutter build apk --debug (단계별)
- 단계 4-5 완료 후: flutter build macos --release, flutter build apk --release
- 단계 4-6 완료 후: GitHub Actions 워크플로우 파일 문법 검증 (실제 실행은 사용자가 push해서 확인)
```

---

## 22. Post-Launch 계획

Phase 4까지 원래 기획한 기능은 모두 구현되었다. 이 섹션부터는 **사용자 피드백 기반의 반복 개선 루프**다.

### 단계 구분

**단계 P-1: 개인 테스트 (1주)**
- 개발자(911) 본인이 1주일간 실제 영수증으로 매일 사용
- 발견된 UX 이슈/버그를 일지로 기록
- 주간 회고 후 우선순위 결정

**단계 P-2: 클로즈드 베타 (2주)**
- 지인/의료 네트워크 5~10명에게 직접 APK/app 배포
- 익명 피드백 폼 또는 KakaoTalk 1:1
- 실제 사용 패턴 수집:
  - 가장 많이 쓰는 기능
  - 가장 자주 막히는 지점
  - 영수증 실패 케이스 (어떤 영수증에서 AI가 틀리는가)

**단계 P-3: Play Store 배포 준비 (1~2주)**
- Google Play Developer 계정 생성 ($25 1회)
- 앱 설명, 스크린샷, 개인정보처리방침 준비
- Closed Testing 트랙에 업로드
- 20명 테스터로 14일 이상 운영 후 Production 승격 가능

**단계 P-4: App Store 배포 (Apple Developer 가입 후)**
- Apple Developer Program 가입 ($99/년)
- iOS 빌드 scaffold 추가 (`flutter create --platforms=ios .`)
- Xcode에서 signing 설정 + TestFlight 배포
- Codex OAuth가 iOS에서도 동작하는지 실측

### Post-Launch에서 가장 먼저 수정될 가능성이 높은 항목

과거 Phase별 실측에서 드러난 패턴 기반 예측:
1. **영수증 실패 케이스 대응** — 감열지 흐린 영수증, 가로로 긴 영수증 등
2. **Codex 토큰 만료 실측** — 10일 지나면 refresh flow 필요
3. **배치 스캔 중 앱 꺼짐 방지** — 병렬 AI 호출 중 메모리 이슈 가능성
4. **카테고리 자동 추론 정확도** — AI가 "GS25" → 식비로 잘 분류하는지

---

## 23. 세무 기능 강화 리서치 계획

### 현재 상태 (Phase 0~4 기준)

이미 구현된 세무 관련 기능:
- 사업자등록번호 추출 (AI가 영수증에서 파싱)
- 경비 구분 태그 (personal/business)
- 세무 카테고리 10개 (복리후생비/접대비/소모품비 등)
- 간편장부 .xlsx 내보내기 (국세청 양식 호환, 월별 소계, 연간 합계)
- 증빙 이미지 5년 로컬 보관 + 백업

**한계:**
- "분류와 기록"까지만 지원. "계산과 신고"는 미지원
- 부가세 자동 계산 없음 (공급가액/부가세 필드는 있으나 신고용 집계 없음)
- 종합소득세 예상 세액 계산 없음
- 세무사 전달용 포맷 한정적 (.xlsx만 지원)

### 리서치 목표

**"쉬운장부"를 기록 도구에서 '개인사업자가 세무사 없이 5월 종소세 신고 80%까지 끝낼 수 있는 도구'로 확장하는 것이 실현 가능한가?**

1순위: 실현 가능한 기능 도출
2순위: 규제/법적 리스크 파악 (세무사법, 전자세금계산서 연동 제약 등)
3순위: 참고할 오픈소스/공공 API 리서치

### 리서치 범위 (4가지 축)

**축 1: 한국 세무 신고 프로세스 역공학**

질문:
- 개인사업자 종합소득세 신고의 실제 단계는?
- 각 단계에서 필요한 입력값과 계산식은?
- 홈택스 API가 외부 앱 연동을 허용하는가? 스크래핑만 가능한가?
- "간편장부 대상자"와 "복식부기 의무자"의 차이와 앱에서 어떻게 구분해야 하는가?
- 부가가치세 신고는 어디까지 자동화 가능한가?

리서치 소스:
- 국세청 홈택스 공식 가이드
- 기획재정부 세법 해설
- 국세청 API 포털 (hometax.go.kr 개발자 섹션)
- 네이버/블로그/유튜브 "개인사업자 종소세 직접 신고" 후기

**축 2: 오픈소스 레퍼런스 조사**

조사할 대상:
- 한국 세무/장부 관련 오픈소스 (GitHub "korean tax", "간편장부", "homeTax", "종합소득세")
- 해외 유사 도구 오픈소스 (TurboTax 대안, GnuCash, Firefly III 등)
- 전자세금계산서 파싱 라이브러리
- 사업자번호 검증 API (공공데이터포털 "사업자등록정보 진위확인")

확인 항목:
- 라이선스 (상업 사용 가능 여부)
- 마지막 커밋 날짜 (유지보수 여부)
- 한국 세법 반영 여부
- 코드 품질 및 참고 가능성

**축 3: 공공 API 및 연동 가능성**

조사할 API:
- 공공데이터포털 "국세청 사업자등록정보 진위확인 및 상태조회" (ksp.go.kr)
- 홈택스 "전자(세금)계산서 조회" API 존재 여부
- 카드사 API (VAN사 영수증 데이터 직접 수신 가능한가)
- 한국은행 "ECOS" API (환율, 이자율 등)
- 국세청 공식 앱 "손택스" 기능 범위

확인 항목:
- 무료/유료 여부
- 일일 호출 제한
- 개인정보 처리 요건
- 앱에서 직접 호출 가능한가 (CORS, 인증 구조)

**축 4: 법률/규제 리스크**

확인할 이슈:
- 세무사법 제2조: "세무대리" 행위 금지 범위 (개인 기록 보조는 합법, 신고 대행은 세무사 자격 필요)
- 앱이 "세액 계산"을 제공해도 되는가? (계산기 수준은 OK, 자동 신고는 NG 추정)
- 개인정보보호법: 사업자등록번호, 매출 데이터는 민감정보인가?
- 전자금융거래법: 카드 영수증 저장 관련 제약
- 홈택스 스크래핑의 법적 상태 (약관 금지인지, 기술적으로 막혀있는지)

### 리서치 산출물 (2주 예상)

1. **docs/tax_research.md** — 리서치 결과 종합 문서
   - 한국 세무 프로세스 다이어그램
   - 자동화 가능 구간과 불가능 구간 명확화
   - 법적 한계선 (여기까지는 앱이 해도 됨, 여기부터는 세무사 영역)

2. **docs/tax_oss_references.md** — 오픈소스 레퍼런스 정리
   - 각 프로젝트별: 이름/라이선스/최근 업데이트/참고 가능 코드/라이선스 호환성

3. **docs/tax_feature_roadmap.md** — 기능 로드맵
   - 각 기능을 "구현 가능 여부 × 사용자 가치 × 개발 난이도" 매트릭스로 우선순위화
   - 예시 후보:
     - [쉬움] 사업자번호 실시간 검증 (공공데이터포털 API)
     - [쉬움] 부가세 자동 집계 (이미 보유한 공급가액/부가세 필드 활용)
     - [중간] 월별 예상 종소세 계산 (간편장부 대상자 기준)
     - [중간] 홈택스 로그인 후 전자세금계산서 자동 수집 (스크래핑)
     - [어려움] 종소세 신고서 양식 자동 생성
     - [불가] 홈택스 자동 제출 (세무사법 저촉 가능)

### 리서치 실행 방법

**Option A: 한 번에 몰아서 (2주 집중)**
- 장점: 전체 맥락 파악 후 한번에 로드맵 수립
- 단점: 2주간 다른 작업 중단

**Option B: 병렬로 (매주 하루씩, 6~8주)**
- 장점: Post-Launch 사용자 테스트와 병행 가능
- 단점: 컨텍스트 스위칭 비용

**Option C: 실제 사용 후 판단 (3~6개월 뒤)**
- 장점: Phase 4 앱을 실제로 써본 뒤 진짜 필요한 세무 기능이 뭔지 확실해짐
- 단점: 그만큼 후순위로 밀림

**추천: Option C**. Phase 4까지 기본 장부는 완성됐고, Post-Launch(§22)에서 실제 쓰면서 "아, 이거 있으면 좋겠다"가 자연스럽게 드러남. 그 시점에 Option A로 집중 리서치하는 게 리서치 자원 낭비 없음.

### 빠른 승부: 사업자번호 검증만 먼저 (2~3일)

세무 전체 리서치 전이라도, 가장 가치가 크고 구현이 쉬운 한 기능은 먼저 넣을 수 있음:

**공공데이터포털 "사업자등록정보 진위확인 및 상태조회" API 연동**
- 무료, 일일 10,000건
- 영수증의 사업자번호 추출 → API로 검증 → "✅ 정상 영업 중" 또는 "⚠️ 폐업 신고됨" 표시
- 폐업 사업자 영수증은 세금계산서 발급 불가 → 사용자가 미리 알 수 있음
- 구현 난이도 낮음 (REST API 1회 호출)

이 기능은 Post-Launch P-1 기간에 1일 작업으로 넣을 수 있다.
