# 교대근무 시간표 (ShiftPlan)

Flutter로 만든 **교대근무 시간표 앱**입니다. 근무를 등록해 **달력**으로 보고, **홈 화면 위젯**으로도 확인할 수 있습니다. **갤럭시(Android)와 아이폰(iOS) 모두 지원**합니다.

## Flutter로 가능한가?

**네, 가능합니다.**

- 달력 화면·근무 등록·패턴 입력 등 앱 로직은 Flutter(Dart) 코드 하나로 두 플랫폼에서 동일하게 동작합니다.
- 홈 화면 위젯만 OS가 각각 네이티브로 처리해야 합니다:
  - Android → `AppWidgetProvider` (Kotlin + XML 레이아웃)
  - iOS → `WidgetKit` 확장 (SwiftUI)
- 이 앱은 [`home_widget`](https://pub.dev/packages/home_widget) 패키지로 Flutter에서 저장한 데이터를 두 네이티브 위젯에 전달합니다. 즉 데이터·로직은 공유하고, 위젯 UI만 플랫폼별로 얇게 구현합니다.

## 주요 기능

- **근무 유형 관리** — 주간/오후/야간/휴무 등. 이름·짧은 라벨·색상·시간대를 자유롭게 추가/수정/삭제.
- **달력 등록** — 월간 달력에서 날짜를 눌러 근무를 배정. 날짜 칸에 색상 배지로 표시.
- **교대 패턴 자동 입력** — 예: `주-주-야-야-휴-휴` 순서를 정해 시작일부터 N일간 반복 적용.
- **홈 위젯** — 오늘/내일 근무를 홈 화면에서 바로 확인. 앱에서 변경하면 자동 갱신.
- 로컬 저장(`shared_preferences`), 오프라인 동작, 다크 모드 지원.

## 프로젝트 구조

```
lib/
  main.dart                     앱 진입점, 로케일/위젯 초기화
  models/
    shift_type.dart             근무 유형 모델
    shift_assignment.dart       날짜 배정 모델(날짜 키)
  services/
    shift_repository.dart       상태 관리 + 저장 + 위젯 동기화(ChangeNotifier)
    widget_service.dart         home_widget 데이터 저장/갱신
  screens/
    calendar_screen.dart        메인 달력
    shift_types_screen.dart     근무 유형 관리
    pattern_screen.dart         교대 패턴 적용
  widgets/
    shift_legend.dart           색상 범례
android/app/src/main/
  kotlin/com/example/shiftplan/ShiftWidgetProvider.kt   Android 위젯
  res/layout/shift_widget.xml                           위젯 레이아웃
  res/xml/shift_widget_info.xml                         위젯 메타
ios/ShiftWidget/
  ShiftWidget.swift             iOS WidgetKit 위젯
  Info.plist
test/
  models_test.dart              모델 단위 테스트
```

## 실행 방법

이 저장소에는 앱 소스와 위젯 네이티브 코드가 들어 있습니다. Flutter가 생성하는 스캐폴딩(Gradle 래퍼, iOS Runner 프로젝트 등)은 아래 명령으로 채웁니다.

### 0) 사전 준비
- Flutter SDK 3.19 이상 설치 (`flutter doctor` 통과)
- Android: Android Studio / SDK
- iOS: macOS + Xcode

### 1) 플랫폼 스캐폴딩 생성 및 패키지 설치
```bash
# 저장소 루트에서 (기존 파일은 덮어쓰지 않고 없는 것만 생성됨)
flutter create --org com.example --project-name shiftplan --platforms=android,ios .
flutter pub get
```

### 2) 실행
```bash
flutter run          # 연결된 기기/에뮬레이터에서 실행
```

앱은 이 단계에서 바로 동작합니다(달력·등록·패턴). 위젯은 아래 플랫폼별 설정을 마치면 홈 화면에 추가할 수 있습니다.

## Android 위젯 설정

대부분 이미 준비되어 있습니다. `flutter create` 후 다음만 확인하세요.

- `android/app/src/main/AndroidManifest.xml` 의 `<receiver android:name=".ShiftWidgetProvider">` 블록이 남아 있는지 확인 (이 저장소 매니페스트에 포함되어 있음).
- 앱을 한 번 실행한 뒤, 홈 화면 → 위젯 → **교대근무** 위젯을 추가.

> `flutter create`가 매니페스트를 다시 생성해 receiver가 사라졌다면, 이 저장소의 `AndroidManifest.xml`에 있는 `<receiver>` 블록을 다시 붙여넣으세요.

## iOS 위젯 설정 (Xcode 필요)

iOS 위젯은 Xcode에서 **Widget Extension 타깃**을 한 번 추가해야 합니다(WidgetKit 특성상 불가피).

1. `open ios/Runner.xcworkspace`
2. **File → New → Target… → Widget Extension** 선택.
   - Product Name: `ShiftWidget`
   - "Include Live Activity" 체크 해제.
3. Xcode가 만든 `ShiftWidget.swift`를 이 저장소의 `ios/ShiftWidget/ShiftWidget.swift` 내용으로 교체.
4. **App Group** 추가 (Runner와 ShiftWidget 두 타깃 모두):
   - 각 타깃 → Signing & Capabilities → **+ Capability → App Groups**
   - 그룹 id를 `group.com.example.shiftplan` 로 지정 (양쪽 동일해야 함).
5. `ShiftWidget.swift`의 `appGroupId` 와 `lib/services/widget_service.dart`의 `iosAppGroupId`, 그리고 iOS 번들 id가 위 App Group 값과 일치하는지 확인.
6. 빌드 후 홈 화면에서 **교대근무** 위젯 추가.

> `com.example` 대신 실제 번들 id를 쓰려면, `flutter create --org` 값, `widget_service.dart`의 App Group, `ShiftWidget.swift`의 `appGroupId`를 함께 바꿔주면 됩니다.

## 데이터 흐름 (위젯 동기화)

1. 사용자가 앱에서 근무를 배정/수정 → `ShiftRepository`가 저장.
2. 저장 직후 `WidgetService.update()`가 오늘/내일 근무를 `home_widget` 저장소에 기록하고 `updateWidget()` 호출.
3. Android `ShiftWidgetProvider` / iOS `ShiftWidget`이 해당 데이터를 읽어 홈 화면에 표시.

## 테스트

```bash
flutter test
```

## 참고 / 한계

- 현재 저장은 기기 로컬(`shared_preferences`)입니다. 여러 기기 동기화가 필요하면 Firebase/서버 연동을 추가하면 됩니다.
- iOS 위젯 타깃 추가는 Xcode에서 수동으로 한 번 해야 합니다(플랫폼 제약).
- 이 환경에서는 Flutter SDK가 없어 빌드 검증은 하지 못했습니다. 위 단계대로 로컬에서 `flutter run` 하면 동작하도록 구성했습니다.
