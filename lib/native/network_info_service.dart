import 'package:flutter/services.dart';
import 'package:rtc_probe/rtc/models.dart';

/// Dart side of the `rtc_probe/network_info` platform channel.
///
/// Falls back to [NetworkPathInfo.unavailable] on platforms without the
/// bridge (web/desktop) or when the channel fails — diagnostics must degrade,
/// never crash.
class NetworkInfoService {
  static const MethodChannel _channel = MethodChannel('rtc_probe/network_info');

  const NetworkInfoService();

  /// Keeps the diagnostics display awake only while a probe is active.
  Future<void> setProbeActive(bool active) async {
    try {
      await _channel.invokeMethod<void>('setProbeActive', active);
    } on PlatformException {
      // Unsupported platforms still retain transport diagnostics.
    } on MissingPluginException {
      // Widget tests and unsupported targets have no native bridge.
    }
  }

  Future<NetworkPathInfo> current() async {
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getCurrentPath',
      );
      if (map == null) return const NetworkPathInfo.unavailable();
      return NetworkPathInfo(
        interfaceType: (map['interfaceType'] as String?) ?? 'unavailable',
        isExpensive: map['isExpensive'] == true,
        isConstrained: map['isConstrained'] == true,
        source: (map['source'] as String?) ?? 'unavailable',
      );
    } on PlatformException {
      return const NetworkPathInfo.unavailable();
    } on MissingPluginException {
      return const NetworkPathInfo.unavailable();
    }
  }
}
