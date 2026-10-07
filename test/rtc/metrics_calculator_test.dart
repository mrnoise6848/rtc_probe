import 'package:flutter_test/flutter_test.dart';
import 'package:rtc_probe/rtc/metrics_calculator.dart';
import 'package:rtc_probe/rtc/models.dart';

RtcStatsSnapshot _snapshot({
  required int elapsedMs,
  RtcCandidatePairInfo? pair,
  RtcMediaStreamStats? outboundVideo,
  RtcMediaStreamStats? inboundAudio,
}) {
  return RtcStatsSnapshot(
    timestampMs: 1700000000000 + elapsedMs,
    elapsedMs: elapsedMs,
    connectionState: RtcConnectionState.connected,
    iceState: RtcIceState.connected,
    candidatePair: pair,
    outboundVideo: outboundVideo,
    inboundAudio: inboundAudio,
  );
}

void main() {
  const calculator = RtcMetricsCalculator();

  test('bitrate and loss are derived from counter deltas', () {
    final prev = _snapshot(
      elapsedMs: 1000,
      outboundVideo: const RtcMediaStreamStats(
        kind: 'video',
        direction: 'outbound',
        ssrc: 1,
        bytes: 100000,
      ),
      inboundAudio: const RtcMediaStreamStats(
        kind: 'audio',
        direction: 'inbound',
        ssrc: 2,
        bytes: 50000,
        packets: 500,
        packetsLost: 2,
      ),
    );
    final curr = _snapshot(
      elapsedMs: 2000,
      pair: const RtcCandidatePairInfo(
        state: 'succeeded',
        nominated: true,
        localCandidateType: 'host',
        remoteCandidateType: 'host',
        availableOutgoingBitbps: null,
        currentRttMs: 42,
      ),
      outboundVideo: const RtcMediaStreamStats(
        kind: 'video',
        direction: 'outbound',
        ssrc: 1,
        bytes: 250000,
        framesPerSecond: 29,
        width: 1280,
        height: 720,
      ),
      inboundAudio: const RtcMediaStreamStats(
        kind: 'audio',
        direction: 'inbound',
        ssrc: 2,
        bytes: 51000,
        packets: 996,
        packetsLost: 8,
        jitterMs: 7.3,
      ),
    );

    final m = calculator.compute(current: curr, previous: prev);

    expect(m.sendBitrateKbps, closeTo(1200, 0.001)); // 150000*8/1000
    expect(m.rttMs, 42);
    expect(m.jitterMs, 7.3);
    // lost delta 6, received delta 496 → 6/502
    expect(m.packetLossPercent, closeTo(6 / 502 * 100, 0.001));
    expect(m.videoFps, 29);
    expect(m.sendResolution, '1280×720');
  });

  test('counter reset yields null instead of a fabricated spike', () {
    final prev = _snapshot(
      elapsedMs: 1000,
      inboundAudio: const RtcMediaStreamStats(
        kind: 'audio',
        direction: 'inbound',
        ssrc: 2,
        bytes: 50000,
        packets: 500,
        packetsLost: 2,
      ),
    );
    final curr = _snapshot(
      elapsedMs: 2000,
      inboundAudio: const RtcMediaStreamStats(
        kind: 'audio',
        direction: 'inbound',
        ssrc: 9, // new SSRC — counters restart
        bytes: 10,
        packets: 3,
        packetsLost: 0,
      ),
    );

    final m = calculator.compute(current: curr, previous: prev);
    expect(m.packetLossPercent, isNull);
    expect(m.recvBitrateKbps, isNull);
  });

  test('first sample has no derived deltas but keeps direct metrics', () {
    final curr = _snapshot(
      elapsedMs: 500,
      pair: const RtcCandidatePairInfo(
        state: 'succeeded',
        nominated: true,
        localCandidateType: 'host',
        remoteCandidateType: 'host',
        availableOutgoingBitbps: null,
        currentRttMs: 12.5,
      ),
    );
    final m = calculator.compute(current: curr);
    expect(m.rttMs, 12.5);
    expect(m.sendBitrateKbps, isNull);
    expect(m.packetLossPercent, isNull);
  });
}
