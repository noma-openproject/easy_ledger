# 쉬운장부 릴리스 가이드

## 1. 플랫폼별 빌드 명령어

### macOS

```bash
flutter build macos --release
```

생성 결과:

```bash
build/macos/Build/Products/Release/easy_ledger.app
```

배포용 앱 이름 복사:

```bash
cp -R build/macos/Build/Products/Release/easy_ledger.app \
  build/macos/Build/Products/Release/쉬운장부.app
```

설치:
1. `쉬운장부.app`를 `/Applications`로 복사
2. 처음 실행 시 "허용되지 않은 개발자" 경고가 나오면:
   - Finder에서 앱 우클릭 → `열기`
   - 또는 시스템 설정 → `개인정보 보호 및 보안` → `그래도 열기`

### Android 디버그

```bash
flutter build apk --debug
```

### Android 릴리스

1. 키스토어 생성

```bash
keytool -genkeypair \
  -v \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

2. `android/key.properties` 작성

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

3. 키 파일 배치

```bash
mv upload-keystore.jks android/app/upload-keystore.jks
```

4. 릴리스 빌드

```bash
flutter build apk --release
```

### Windows

로컬 Mac에서는 Windows EXE를 직접 빌드할 수 없습니다. GitHub Actions의 Windows 워크플로우를 사용합니다.

## 2. GitHub Actions 자동 빌드

태그 푸시로 자동 실행:

```bash
git tag v0.4.0
git push origin v0.4.0
```

수동 실행:
1. GitHub 저장소의 `Actions` 탭 이동
2. 원하는 워크플로우 선택
3. `Run workflow` 클릭

artifact 다운로드:
1. 실행 완료 후 해당 workflow run 열기
2. 하단 `Artifacts` 섹션에서 macOS / Android / Windows 결과 다운로드
3. macOS artifact에는 `쉬운장부.app` 압축본이 포함됨

### Android 서명용 GitHub Secrets

다음 시크릿을 저장소에 등록:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

`ANDROID_KEYSTORE_BASE64` 생성 예시:

```bash
base64 -i android/app/upload-keystore.jks | pbcopy
```

## 3. GitHub Release 업로드

1. GitHub의 `Releases` 페이지 이동
2. `Draft a new release` 클릭
3. 태그 선택 또는 새 태그 입력
4. 빌드된 `.app`, `.apk`, Windows artifact 압축본 업로드
5. 릴리스 노트 작성 후 게시

## 4. 확인 체크리스트

- macOS: `flutter build macos --release` 성공 확인 후 `쉬운장부.app` 복사본 실행 확인
- Android: 디버그 APK 설치 및 실행 확인
- Android 릴리스: 키스토어 적용 후 서명 빌드 확인
- Windows: GitHub Actions artifact 다운로드 후 실행 확인
