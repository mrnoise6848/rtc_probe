import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rtc_probe/native/network_info_service.dart';
import 'package:rtc_probe/rtc/models.dart';
import 'package:rtc_probe/ui/session_controller.dart';

class DelayedNetwork extends NetworkInfoService {
  final pending = Completer<NetworkPathInfo>();
  int calls = 0;
  @override
  Future<void> setProbeActive(bool active) async {}
  @override
  Future<NetworkPathInfo> current() {
    calls++;
    return pending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'end during startup rejects late network result before native capture',
    () async {
      final network = DelayedNetwork();
      final controller = SessionController(networkInfoService: network);
      final starting = controller.start();
      expect(controller.phase, RtcSessionPhase.starting);
      final stopping = controller.stop();
      network.pending.complete(const NetworkPathInfo.unavailable());
      await starting;
      await stopping;
      expect(controller.phase, RtcSessionPhase.ended);
      expect(controller.sessionModel, isNull);
      expect(controller.summary!.sampleCount, 0);
      expect(controller.summary!.avgRttMs, isNull);
      controller.dispose();
    },
  );
  test('background prevents a new capture request until foreground', () async {
    final network = DelayedNetwork();
    final controller = SessionController(networkInfoService: network);
    controller.handleAppLifecycle(false);
    await controller.start();
    expect(network.calls, 0);
    expect(controller.phase, RtcSessionPhase.idle);
    controller.dispose();
  });
  test(
    'dispose during startup prevents notifications from late results',
    () async {
      final network = DelayedNetwork();
      final controller = SessionController(networkInfoService: network);
      var notifications = 0;
      controller.addListener(() {
        notifications++;
      });
      final starting = controller.start();
      controller.dispose();
      final count = notifications;
      network.pending.complete(const NetworkPathInfo.unavailable());
      await starting;
      await Future<void>.delayed(Duration.zero);
      expect(notifications, count);
    },
  );
}
