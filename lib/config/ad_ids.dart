import 'package:flutter/foundation.dart';

/// AdMob 광고 단위 id.
///
/// - Android(Play 스토어 배포): 실제 id 사용.
/// - iOS(개인 사이드로딩): 실수로 실제 광고를 클릭해 무효 트래픽이
///   생기지 않도록 구글 공식 테스트 id를 유지한다.
class AdIds {
  AdIds._();

  // [임시 확인용] 연동 점검 동안 구글 테스트 배너 ID 사용. 확인 후 아래
  // 실제 ID로 되돌린다: 'ca-app-pub-4072566205952525/1063396694'
  static const String _androidBanner =
      'ca-app-pub-3940256099942544/6300978111';

  static String get banner {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidBanner;
    }
    return 'ca-app-pub-3940256099942544/2934735716'; // iOS 테스트 배너
  }
}
