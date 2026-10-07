import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rtc_probe/rtc/diagnostic_engine.dart';
import 'package:rtc_probe/rtc/metrics_calculator.dart';
import 'package:rtc_probe/rtc/models.dart';
import 'package:rtc_probe/rtc/sampler.dart';
import 'package:rtc_probe/rtc/timeline.dart';

RtcStatsSnapshot snapshot(
  int ms,
  int ssrc,
  int bytes, {
  int packets = 10,
  int lost = 1,
  int frames = 10,
}) => RtcStatsSnapshot(
  timestampMs: ms,
  elapsedMs: ms,
  connectionState: RtcConnectionState.connected,
  iceState: RtcIceState.connected,
  outboundVideo: RtcMediaStreamStats(
    kind: 'video',
    direction: 'outbound',
    ssrc: ssrc,
    bytes: bytes,
    frames: frames,
  ),
  inboundAudio: RtcMediaStreamStats(
    kind: 'audio',
    direction: 'inbound',
    ssrc: 3,
    bytes: bytes,
    packets: packets,
    packetsLost: lost,
  ),
);

void main() {
  const calc = RtcMetricsCalculator();
  test('increasing counters on changed SSRC must not become a bitrate', () {
    final m = calc.compute(
      current: snapshot(2000, 2, 90000),
      previous: snapshot(1000, 1, 100),
    );
    expect(m.sendBitrateKbps, isNull);
    expect(m.videoFps, isNull);
    expect(m.packetLossPercent, isNull); // no received traffic in interval
  });
  test('encoded frame deltas provide FPS only over valid time', () {
    expect(
      calc
          .compute(
            current: snapshot(2000, 1, 200, frames: 40),
            previous: snapshot(1000, 1, 100),
          )
          .videoFps,
      30,
    );
    expect(
      calc
          .compute(
            current: snapshot(1000, 1, 200),
            previous: snapshot(1000, 1, 100),
          )
          .videoFps,
      isNull,
    );
  });
  test('unavailable evidence does not falsely resolve a finding', () {
    final engine = RtcDiagnosticEngine(sustainTicks: 1, clearTicks: 1);
    final s = snapshot(1000, 1, 1);
    engine.evaluate(
      snapshot: s,
      metrics: const RtcDerivedMetrics(packetLossPercent: 9),
      videoSending: false,
      elapsedMs: 1000,
    );
    final unknown = engine.evaluate(
      snapshot: s,
      metrics: const RtcDerivedMetrics(),
      videoSending: false,
      elapsedMs: 2000,
    );
    expect(unknown.cleared, isEmpty);
    expect(unknown.active.single.code, RtcFindingCode.highPacketLoss);
  });
  test('summary includes samples evicted from the chart', () {
    final chart = RtcTimeline(maxPoints: 2);
    final total = RtcSummaryAccumulator();
    for (var i = 1; i <= 4; i++) {
      final p = RtcTimelinePoint(
        elapsedMs: i * 1000,
        rttMs: i * 10.0,
        level: RtcQualityLevel.good,
      );
      chart.push(p);
      total.add(p);
    }
    final s = total.finish(
      startedAt: DateTime(2026),
      durationMs: 4000,
      findingsCount: 0,
    );
    expect(chart.length, 2);
    expect(s.sampleCount, 4);
    expect(s.avgRttMs, 25);
    expect(s.peakRttMs, 40);
  });
  testWidgets('sampler restart cannot overlap an outstanding tick', (
    tester,
  ) async {
    final sampler = RtcSampler(interval: const Duration(milliseconds: 10));
    final pending = Completer<void>();
    var calls = 0;
    Future<void> tick() async {
      calls++;
      await pending.future;
    }

    sampler.start(tick);
    await tester.pump(const Duration(milliseconds: 10));
    sampler.stop();
    sampler.start(tick);
    await tester.pump(const Duration(milliseconds: 50));
    expect(calls, 1);
    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(calls, 2);
    sampler.stop();
  });
}
