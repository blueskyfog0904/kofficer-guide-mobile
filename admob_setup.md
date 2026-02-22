# AdMob 설정 가이드 (Flutter)

현재 코드에는 **테스트 ID fallback 전략**이 적용되어 있습니다.

- Android App ID: `android/local.properties`의 `ADMOB_APP_ID_ANDROID` (없으면 테스트 App ID)
- iOS App ID: `ios/Flutter/KakaoConfig.xcconfig`의 `ADMOB_APP_ID_IOS` (Info.plist는 변수 참조)
- Banner Ad Unit ID (production): `--dart-define`로 주입
  - `ADMOB_ANDROID_BANNER_ID`
  - `ADMOB_IOS_BANNER_ID`
- 위 값이 없으면 Google 공식 **테스트 배너 ID**로 동작합니다.

## 앱 배포 전 교체해야 할 값

1. Android App ID (`ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy`)
   - `android/local.properties`에 `ADMOB_APP_ID_ANDROID=...` 추가
2. iOS App ID (`ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy`)
   - `ios/Flutter/KakaoConfig.xcconfig`의 `ADMOB_APP_ID_IOS=...` 교체
3. Android/iOS Banner Unit ID (`ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz`)

## 앱스토어 정책용 app-ads.txt

웹사이트 루트(`https://kofficer-guide.co.kr/app-ads.txt`)에 아래 라인을 게시하세요.

```txt
google.com, pub-8304778968765929, DIRECT, f08c47fec0942fa0
```
