# 쉬운장부

영수증 스캔, 거래 내역 관리, 월별 통계, Google Sheets 동기화까지 지원하는 Flutter 기반 간편장부 앱입니다.

## 다운로드

- Release 페이지: [https://github.com/noma-openproject/easy_ledger/releases](https://github.com/noma-openproject/easy_ledger/releases)
- Windows 사용자:
  - `easy-ledger-windows-setup-vX.Y.Z.exe` 다운로드
  - 실행 후 설치 마법사 따라가면 바로 사용 가능
- Android 사용자:
  - `easy-ledger-android-vX.Y.Z.apk` 또는 `easy-ledger-android-vX.Y.Z-debug.apk` 다운로드
  - 휴대폰에서 설치
- macOS 사용자:
  - `easy-ledger-macos-vX.Y.Z.zip` 다운로드 후 압축 해제

참고:
- Android signing secrets가 저장소에 설정되어 있으면 release APK가 올라갑니다.
- signing secrets가 없으면 설치 가능한 debug APK가 대신 올라갑니다.
- iPhone은 GitHub Release 파일만으로 바로 설치할 수 없습니다. TestFlight 또는 App Store 배포가 필요합니다.

## 개발

```bash
flutter pub get
flutter run -d macos
```

자세한 배포 방법은 [docs/release_guide.md](docs/release_guide.md)를 참고하세요.
