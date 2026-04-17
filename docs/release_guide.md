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

Release 자동 업로드:
1. `v*` 태그가 push되면 macOS / Android / Windows 워크플로우가 자동 실행됩니다.
2. 각 워크플로우는 빌드 산출물을 GitHub Release에 자동 첨부합니다.
3. 최종 사용자는 `Actions`가 아니라 `Releases` 페이지에서 바로 다운로드하면 됩니다.

직접 공유할 링크 예시:

```text
https://github.com/noma-openproject/easy_ledger/releases
```

대표 자산 이름:
- Windows 설치 파일: `easy-ledger-windows-setup-v0.4.1.exe`
- Windows 압축본: `easy-ledger-windows-portable-v0.4.1.zip`
- Android APK: `easy-ledger-android-v0.4.1.apk`
- Android fallback APK: `easy-ledger-android-v0.4.1-debug.apk`
- macOS 압축본: `easy-ledger-macos-v0.4.1.zip`

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

태그 푸시 후 워크플로우가 자동으로 Release 자산을 올립니다.

Windows 사용자 배포:
1. `Releases` 페이지에서 `easy-ledger-windows-setup-vX.Y.Z.exe` 다운로드
2. 실행 후 설치
3. 설치 완료 후 시작 메뉴 또는 바탕화면 아이콘으로 실행

Android 사용자 배포:
1. `Releases` 페이지에서 APK 다운로드
2. 휴대폰에서 `알 수 없는 앱 설치 허용`
3. APK 열기 → 설치

참고:
- Android signing secrets가 설정돼 있으면 release APK가 올라갑니다.
- signing secrets가 없으면 debug APK가 대신 올라갑니다.
- iPhone은 GitHub Release 자산만으로 직접 설치할 수 없고, TestFlight 또는 App Store 배포가 필요합니다.

## 4. 확인 체크리스트

- macOS: `flutter build macos --release` 성공 확인 후 `쉬운장부.app` 복사본 실행 확인
- Android: 디버그 APK 설치 및 실행 확인
- Android 릴리스: 키스토어 적용 후 서명 빌드 확인
- Windows: Release 페이지의 설치용 `.exe` 다운로드 후 설치/실행 확인
- Android: Release 페이지 APK 다운로드 후 설치 확인
