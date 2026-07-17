# Play 스토어 출시 절차

## 1회성 준비

1. **Play Console 개발자 등록** — https://play.google.com/console
   - 등록비 $25 (일회성), 신분 확인에 1~2일 소요
2. **개인정보처리방침 게시** — `privacy-policy-ko.md` 내용을 웹에 올리고 URL 확보
   - 가장 쉬운 방법: https://gist.github.com 에 공개 Gist로 붙여넣기 → 그 URL 사용
3. **AdMob ↔ Play 연결** — AdMob 콘솔에서 앱을 Play 스토어 등록 앱과 연결
   (출시 후에 가능. 연결해야 광고 게재 제한이 풀린다)

## 출시할 때마다

1. `pubspec.yaml`의 `version: 1.0.0+1` 을 올린다
   - `+` 뒤 숫자(빌드 번호)는 **반드시 이전보다 커야** Play가 받아준다
2. main 브랜치에 푸시 → GitHub Actions가 서명된 AAB 생성
3. Actions에서 `shiftplan-aab` 아티팩트 다운로드 → Play Console에 업로드
4. 심사 대기 (신규 앱은 최초 며칠, 이후 업데이트는 보통 수 시간)

## 서명 키 (중요)

- 위치: `~/keystores/shiftplan-upload.jks` + `shiftplan-key.properties`
- **이 파일을 잃어버리면 앱 업데이트를 영구히 할 수 없다.** 반드시 별도 백업.
- GitHub Secrets에도 등록되어 있음:
  - `ANDROID_KEYSTORE_BASE64` — 키 파일 (base64)
  - `ANDROID_KEY_PROPERTIES` — 비밀번호/별칭
- Play App Signing을 사용하면 이 키는 "업로드 키" 역할이며,
  분실 시 Google 지원을 통해 재설정 가능하다 (활성화 권장).

## 유지보수

- Google Play는 매년 targetSdk 상향을 요구한다 (미이행 시 신규 노출 제한).
  Flutter 버전을 올리고 재빌드하면 대부분 해결된다. 연 1회, 1~2시간.
