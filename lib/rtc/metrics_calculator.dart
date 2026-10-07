import 'package:rtc_probe/rtc/models.dart';

/// Computes derived QoS metrics from consecutive normalized snapshots.
///
/// Bitrates and loss are deltas over cumulative counters between two samples;
/// a counter that resets (SSRC change) yields `null` for that interval rather
/// than a fabricated spike. Everything unavailable stays `null`.
class RtcMetricsCalculator {
  const RtcMetricsCalculator();

  RtcDerivedMetrics compute({
    required RtcStatsSnapshot current,
    RtcStatsSnapshot? previous,
  }) {
    // Transport-level RTT from the selected candidate pair; falls back to the
    // RTT the remote side reported for our outbound streams via RTCP.
    final rtt = current.candidatePair?.currentRttMs ?? _remoteRtt(current);

    return RtcDerivedMetrics(
      rttMs: _clean(rtt),
      jitterMs: _clean(_worstJitter(current)),
      packetLossPercent: _lossPercent(current, previous),
      sendBitrateKbps: _bitrateKbps(
        nowBytes: _bytes(current.outboundAudio, current.outboundVideo),
        prevBytes: _bytes(previous?.outboundAudio, previous?.outboundVideo),
        elapsedMs: current.elapsedMs,
        prevElapsedMs: previous?.elapsedMs,
      ),
      recvBitrateKbps: _bitrateKbps(
        nowBytes: _bytes(current.inboundAudio, current.inboundVideo),
        prevBytes: _bytes(previous?.inboundAudio, previous?.inboundVideo),
        elapsedMs: current.elapsedMs,
        prevElapsedMs: previous?.elapsedMs,
      ),
      videoFps: _clean(current.outboundVideo?.framesPerSecond),
      sendResolution: _resolution(current.outboundVideo),
    );
  }

  double? _remoteRtt(RtcStatsSnapshot s) {
    final candidates = [
      s.outboundAudio?.roundTripTimeMs,
      s.outboundVideo?.roundTripTimeMs,
    ].whereType<double>();
    return candidates.isEmpty ? null : candidates.reduce((a, b) => a > b ? a : b);
  }

  double? _worstJitter(RtcStatsSnapshot s) {
    final candidates = [
      s.inboundAudio?.jitterMs,
      s.inboundVideo?.jitterMs,
    ].whereType<double>();
    return candidates.isEmpty ? null : candidates.reduce((a, b) => a > b ? a : b);
  }

  int? _bytes(RtcMediaStreamStats? audio, RtcMediaStreamStats? video) {
    final parts = [audio?.bytes, video?.bytes].whereType<int>();
    if (parts.isEmpty) return null;
    return parts.reduce((a, b) => a + b);
  }

  double? _bitrateKbps({
    required int? nowBytes,
    required int? prevBytes,
    required int elapsedMs,
    required int? prevElapsedMs,
  }) {
    if (nowBytes == null || prevBytes == null || prevElapsedMs == null) return null;
    final dBytes = nowBytes - prevBytes;
    final dtMs = elapsedMs - prevElapsedMs;
    if (dBytes < 0 || dtMs <= 0) return null; // counter reset or clock oddity
    return dBytes * 8 / dtMs; // kbps = bytes*8 / ms
  }

  /// Loss ratio over the interval, pooled across inbound audio+video:
  /// lost / (received + lost). Both counters come from real RTP statistics.
  double? _lossPercent(RtcStatsSnapshot current, RtcStatsSnapshot? previous) {
    if (previous == null) return null;
    var dLost = 0, dReceived = 0;
    var seen = false;
    for (final stream in [current.inboundAudio, current.inboundVideo]) {
      if (stream == null) continue;
      final prev = previous._streamWithSsrc(stream.ssrc);
      if (prev == null) continue;
      final lostNow = stream.packetsLost;
      final lostPrev = prev.packetsLost;
      final recvNow = stream.packets;
      final recvPrev = prev.packets;
      if (lostNow == null || lostPrev == null || recvNow == null || recvPrev == null) continue;
      final dl = lostNow - lostPrev;
      final dr = recvNow - recvPrev;
      if (dl < 0 || dr < 0) return null; // counter reset
      dLost += dl;
      dReceived += dr;
      seen = true;
    }
    if (!seen) return null;
    final total = dReceived + dLost;
    if (total <= 0) return 0;
    return dLost / total * 100.0;
  }

  String? _resolution(RtcMediaStreamStats? video) {
    if (video?.width == null || video?.height == null) return null;
    return '${video!.width}×${video!.height}';
  }

  double? _clean(double? value) {
    if (value == null || value.isNaN || value.isNegative || value > 1e9) return null;
    return value;
  }
}

extension _StreamLookup on RtcStatsSnapshot {
  RtcMediaStreamStats? _streamWithSsrc(int ssrc) {
    for (final s in [inboundAudio, inboundVideo]) {
      if (s?.ssrc == ssrc) return s;
    }
    return null;
  }
}
