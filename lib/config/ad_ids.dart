import 'package:flutter/foundation.dart';

/// AdMob 광고 단위 id.
///
/// 현재는 구글 공식 **테스트 id**를 사용한다. AdMob 가입 후 발급받은
/// 실제 id로 아래 상수만 교체하면 된다 (AndroidManifest.xml과
/// ios/Runner/Info.plist의 앱 id도 함께 교체).
class AdIds {
  AdIds._();

  static String get banner {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Android 테스트 배너
    }
    return 'ca-app-pub-3940256099942544/2934735716'; // iOS 테스트 배너
  }
}
