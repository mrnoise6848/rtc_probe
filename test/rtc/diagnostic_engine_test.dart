import 'package:flutter_test/flutter_test.dart';
import 'package:rtc_probe/rtc/diagnostic_engine.dart';
import 'package:rtc_probe/rtc/models.dart';

RtcStatsSnapshot _snapshot({
  RtcConnectionState state = RtcConnectionState.connected,
}) {
  return RtcStatsSnapshot(
    timestampMs: 0,
    elapsedMs: 0,
    connectionState: state,
    iceState: RtcIceState.connected,
  );
}

void main() {
  test('a condition must persist before a finding is raised', () {
    final engine = RtcDiagnosticEngine(sustainTicks: 3, clearTicks: 3);
    const metrics = RtcDerivedMetrics(packetLossPercent: 6.2);
    final snapshot = _snapshot();

    var update = engine.evaluate(
      snapshot: snapshot,
      metrics: metrics,
      videoSending: false,
      elapsedMs: 1000,
    );
    expect(update.raised, isEmpty);
    update = engine.evaluate(
      snapshot: snapshot,
      metrics: metrics,
      videoSending: false,
      elapsedMs: 2000,
    );
    expect(update.raised, isEmpty);
    update = engine.evaluate(
      snapshot: snapshot,
      metrics: metrics,
      videoSending: false,
      elapsedMs: 3000,
    );
    expect(update.raised.length, 1);
    expect(update.raised.first.code, RtcFindingCode.highPacketLoss);
    expect(update.active.length, 1);
    expect(update.raised.first.evidence, contains('6.20%'));
  });

  test('findings clear only after the condition stays gone', () {
    final engine = RtcDiagnosticEngine(sustainTicks: 1, clearTicks: 3);
    final bad = _snapshot();

    var update = engine.evaluate(
      snapshot: bad,
      metrics: const RtcDerivedMetrics(packetLossPercent: 9.9),
      videoSending: false,
      elapsedMs: 1000,
    );
    expect(update.raised.length, 1);

    const healthy = RtcDerivedMetrics(packetLossPercent: 0.0);
    update = engine.evaluate(
      snapshot: bad,
      metrics: healthy,
      videoSending: false,
      elapsedMs: 2000,
    );
    expect(update.cleared, isEmpty); // calm 1
    update = engine.evaluate(
      snapshot: bad,
      metrics: healthy,
      videoSending: false,
      elapsedMs: 3000,
    );
    expect(update.cleared, isEmpty); // calm 2
    update = engine.evaluate(
      snapshot: bad,
      metrics: healthy,
      videoSending: false,
      elapsedMs: 4000,
    );
    expect(update.cleared.length, 1); // calm 3 → cleared
    expect(update.active, isEmpty);
  });

  test('connection interruption is detected from connection state', () {
    final engine = RtcDiagnosticEngine(sustainTicks: 2, clearTicks: 2);
    final snapshot = _snapshot(state: RtcConnectionState.disconnected);
    var update = engine.evaluate(
      snapshot: snapshot,
      metrics: const RtcDerivedMetrics(),
      videoSending: false,
      elapsedMs: 1000,
    );
    update = engine.evaluate(
      snapshot: snapshot,
      metrics: const RtcDerivedMetrics(),
      videoSending: false,
      elapsedMs: 2000,
    );
    expect(
      update.active.map((f) => f.code),
      contains(RtcFindingCode.connectionInterrupted),
    );
    expect(
      update.active
          .firstWhere((f) => f.code == RtcFindingCode.connectionInterrupted)
          .severity,
      RtcSeverity.critical,
    );
  });

  test('video stall requires the sustained stall window', () {
    final engine = RtcDiagnosticEngine(
      sustainTicks: 1,
      clearTicks: 1,
      stallSustainTicks: 5,
    );
    final snapshot = _snapshot();
    for (var i = 1; i <= 4; i++) {
      final update = engine.evaluate(
        snapshot: snapshot,
        metrics: const RtcDerivedMetrics(videoFps: 0),
        videoSending: true,
        elapsedMs: i * 1000,
      );
      expect(update.raised, isEmpty, reason: 'tick $i should not raise yet');
    }
    final update = engine.evaluate(
      snapshot: snapshot,
      metrics: const RtcDerivedMetrics(videoFps: 0),
      videoSending: true,
      elapsedMs: 5000,
    );
    expect(
      update.raised.map((f) => f.code),
      contains(RtcFindingCode.videoFramesStalled),
    );
  });

  test('healthy metrics raise nothing', () {
    final engine = RtcDiagnosticEngine();
    final update = engine.evaluate(
      snapshot: _snapshot(),
      metrics: const RtcDerivedMetrics(
        rttMs: 40,
        jitterMs: 5,
        packetLossPercent: 0.01,
        videoFps: 29,
      ),
      videoSending: true,
      elapsedMs: 1000,
    );
    expect(update.raised, isEmpty);
    expect(update.active, isEmpty);
  });
}
