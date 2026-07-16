import Flutter
import UIKit

/// 사이드로딩(AltStore 등) 시 App Group id가 재서명 과정에서 바뀔 수 있다.
/// embedded.mobileprovision의 Entitlements에서 실제 id를 읽는다.
func appGroupFromEmbeddedProfile() -> String? {
  guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
        let data = try? Data(contentsOf: url),
        let start = data.range(of: Data("<plist".utf8)),
        let end = data.range(of: Data("</plist>".utf8))
  else { return nil }
  let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
  guard let plist = try? PropertyListSerialization.propertyList(
          from: plistData, options: [], format: nil) as? [String: Any],
        let entitlements = plist["Entitlements"] as? [String: Any],
        let groups = entitlements["com.apple.security.application-groups"] as? [String]
  else { return nil }
  return groups.first
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "shiftplan/app_group", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        if call.method == "getAppGroupId" {
          result(appGroupFromEmbeddedProfile())
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
