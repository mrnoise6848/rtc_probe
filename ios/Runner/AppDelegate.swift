import Flutter
import Network
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // RTCProbe native bridge: exposes the OS network path to Flutter.
    // This is the only iOS-native addition — WebRTC itself lives inside the
    // flutter_webrtc plugin's prebuilt binaries.
    let bridge = NetworkInfoBridge.shared
    bridge.start()
    FlutterMethodChannel(
      name: "rtc_probe/network_info",
      binaryMessenger: engineBridge.applicationRegistrar.binaryMessenger
    ).setMethodCallHandler { call, result in
      switch call.method {
      case "getCurrentPath":
        result(bridge.snapshot)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// Reports the current network path using `NWPathMonitor`.
///
/// Kept in this file (not a separate .swift file) so the Xcode project file
/// stays untouched. It answers one question: which interface type carries the
/// connection right now, and is it expensive/constrained.
final class NetworkInfoBridge {
  static let shared = NetworkInfoBridge()

  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "rtc_probe.network_info")
  private var started = false

  func start() {
    guard !started else { return }
    started = true
    monitor.start(queue: queue)
  }

  var snapshot: [String: Any] {
    let path = monitor.currentPath
    let interfaceType: String
    switch path.status {
    case .unsatisfied, .requiresConnection:
      interfaceType = "none"
    default:
      if path.usesInterfaceType(.wifi) {
        interfaceType = "wifi"
      } else if path.usesInterfaceType(.cellular) {
        interfaceType = "cellular"
      } else if path.usesInterfaceType(.wiredEthernet) {
        interfaceType = "ethernet"
      } else {
        interfaceType = "unknown"
      }
    }
    return [
      "interfaceType": interfaceType,
      "isExpensive": path.isExpensive,
      "isConstrained": path.isConstrained,
      "source": "swift-nwpathmonitor",
    ]
  }
}
