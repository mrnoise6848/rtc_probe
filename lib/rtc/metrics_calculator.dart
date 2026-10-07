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
      sendBitrateKbps: _streamBitrate(current, previous, outbound: true),
      recvBitrateKbps: _streamBitrate(current, previous, outbound: false),
      videoFps: _clean(
        current.outboundVideo?.framesPerSecond ?? _frameRate(current, previous),
      ),
      sendResolution: _resolution(current.outboundVideo),
    );
  }

  double? _remoteRtt(RtcStatsSnapshot s) {
    final candidates = [
      s.outboundAudio?.roundTripTimeMs,
      s.outboundVideo?.roundTripTimeMs,
    ].whereType<double>();
    return candidates.isEmpty
        ? null
        : candidates.reduce((a, b) => a > b ? a : b);
  }

  double? _worstJitter(RtcStatsSnapshot s) {
    final candidates = [
      s.inboundAudio?.jitterMs,
      s.inboundVideo?.jitterMs,
    ].whereType<double>();
    return candidates.isEmpty
        ? null
        : candidates.reduce((a, b) => a > b ? a : b);
  }

  double? _streamBitrate(
    RtcStatsSnapshot current,
    RtcStatsSnapshot? previous, {
    required bool outbound,
  }) {
    if (previous == null) return null;
    final dt = current.elapsedMs - previous.elapsedMs;
    if (dt <= 0) return null;
    final now = outbound
        ? [current.outboundAudio, current.outboundVideo]
        : [current.inboundAudio, current.inboundVideo];
    final old = outbound
        ? [previous.outboundAudio, previous.outboundVideo]
        : [previous.inboundAudio, previous.inboundVideo];
    var bytes = 0;
    var seen = false;
    for (var i = 0; i < now.length; i++) {
      final a = now[i], b = old[i];
      if (a == null && b == null) continue;
      if (a == null ||
          b == null ||
          a.ssrc != b.ssrc ||
          a.kind != b.kind ||
          a.bytes == null ||
          b.bytes == null) {
        return null;
      }
      final delta = a.bytes! - b.bytes!;
      if (delta < 0) return null;
      bytes += delta;
      seen = true;
    }
    return seen ? bytes * 8 / dt : null;
  }

  double? _frameRate(RtcStatsSnapshot current, RtcStatsSnapshot? previous) {
    final a = current.outboundVideo, b = previous?.outboundVideo;
    if (a == null ||
        b == null ||
        a.ssrc != b.ssrc ||
        a.frames == null ||
        b.frames == null) {
      return null;
    }
    final dt = current.elapsedMs - previous!.elapsedMs;
    final frames = a.frames! - b.frames!;
    return dt > 0 && frames >= 0 ? frames * 1000 / dt : null;
  }

  /// Loss ratio over the interval, pooled across inbound audio+video:
  /// lost / (received + lost). Both counters come from real RTP statistics.
  double? _lossPercent(RtcStatsSnapshot current, RtcStatsSnapshot? previous) {
    if (previous == null || current.elapsedMs <= previous.elapsedMs) {
      return null;
    }
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
      if (lostNow == null ||
          lostPrev == null ||
          recvNow == null ||
          recvPrev == null) {
        continue;
      }
      final dl = lostNow - lostPrev;
      final dr = recvNow - recvPrev;
      if (dl < 0 || dr < 0) return null; // counter reset
      dLost += dl;
      dReceived += dr;
      seen = true;
    }
    if (!seen) return null;
    final total = dReceived + dLost;
    if (total <= 0) return null;
    return dLost / total * 100.0;
  }

  String? _resolution(RtcMediaStreamStats? video) {
    if (video?.width == null || video?.height == null) return null;
    return '${video!.width}×${video.height}';
  }

  double? _clean(double? value) {
    if (value == null || value.isNaN || value.isNegative || value > 1e9) {
      return null;
    }
    return value;
  }
}

extension _StreamLookup on RtcStatsSnapshot {
  RtcMediaStreamStats? _streamWithSsrc(int ssrc) {
    for (final s in [inboundAudio, inboundVideo]) {
      if (s != null && s.ssrc == ssrc) return s;
    }
    return null;
  }
}
