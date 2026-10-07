import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rtc_probe/native/network_info_service.dart';
import 'package:rtc_probe/rtc/models.dart';
import 'package:rtc_probe/webrtc/loopback_session.dart';
import 'package:rtc_probe/webrtc/stats_normalizer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native local ICE/DTLS, echo, stats and repeated cleanup', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('RTCProbe native transport verification')),
      ),
    );
    final path = await const NetworkInfoService().current();
    expect(
      path.source,
      isNot('unavailable'),
      reason: 'Custom Swift/Kotlin bridge must register.',
    );
    for (var run = 0; run < 2; run++) {
      final session = await LoopbackRtcSession.start();
      try {
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (session.connectionState != RtcConnectionState.connected &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(session.connectionState, RtcConnectionState.connected);
        expect(
          session.iceState,
          anyOf(RtcIceState.connected, RtcIceState.completed),
        );
        final echo = Completer<double?>();
        final subscription = session.appRttMs.listen((value) {
          if (!echo.isCompleted) echo.complete(value);
        });
        try {
          final pingDeadline = DateTime.now().add(const Duration(seconds: 10));
          while (!echo.isCompleted && DateTime.now().isBefore(pingDeadline)) {
            session.ping();
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          final rtt = await echo.future.timeout(const Duration(seconds: 1));
          expect(rtt, isNotNull);
          expect(rtt, greaterThanOrEqualTo(0));
          final raw = await session.collectStats();
          expect(raw, isNotEmpty);
          final s = const RtcStatsNormalizer().normalize(
            reports: raw,
            elapsedMs: 1000,
            connectionState: session.connectionState,
            iceState: session.iceState,
          );
          expect(s.candidatePair?.state, 'succeeded');
          expect(s.transport?.dtlsState, 'connected');
          expect(s.outboundAudio, isNull);
          expect(s.outboundVideo, isNull);
          expect(s.dataChannel?.messagesSent, greaterThan(0));
          expect(s.dataChannel?.messagesReceived, greaterThan(0));
        } finally {
          await subscription.cancel();
        }
        await session.dropMirrorPeer();
      } finally {
        await session.close();
        await session.close();
      }
      expect(session.isClosed, isTrue);
    }
  });
}
