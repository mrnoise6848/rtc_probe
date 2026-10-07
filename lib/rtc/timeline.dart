import 'package:rtc_probe/rtc/models.dart';

/// Bounded metric timeline for one session.
///
/// Default capacity is 600 points ≈ 10 minutes at 1 Hz. Oldest points are
/// dropped first; memory usage is therefore constant for any session length.
class RtcTimeline {
  RtcTimeline({this.maxPoints = 600});

  final int maxPoints;

  final List<RtcTimelinePoint> _points = <RtcTimelinePoint>[];

  List<RtcTimelinePoint> get points => List.unmodifiable(_points);

  RtcTimelinePoint? get last => _points.isEmpty ? null : _points.last;

  int get length => _points.length;

  void push(RtcTimelinePoint point) {
    _points.add(point);
    if (_points.length > maxPoints) {
      _points.removeRange(0, _points.length - maxPoints);
    }
  }

  /// Points within the trailing [windowMs], for chart rendering.
  List<RtcTimelinePoint> trailing(int windowMs) {
    if (_points.isEmpty) return const [];
    final cutoff = _points.last.elapsedMs - windowMs;
    final start = _points.indexWhere((p) => p.elapsedMs >= cutoff);
    return start <= 0 ? points : List.unmodifiable(_points.sublist(start));
  }

  void clear() => _points.clear();
}

/// Builds the session summary from a finished timeline.
RtcSessionSummary summarizeSession({
  required DateTime startedAt,
  required int durationMs,
  required List<RtcTimelinePoint> points,
  required int findingsCount,
}) {
  double? avg(Iterable<double?> values) {
    final v = values.whereType<double>().toList();
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a + b) / v.length;
  }

  double? peak(Iterable<double?> values) {
    final v = values.whereType<double>().toList();
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a > b ? a : b);
  }

  var worst = RtcQualityLevel.unknown;
  for (final p in points) {
    if (p.level.index > worst.index) worst = p.level;
  }

  return RtcSessionSummary(
    startedAt: startedAt,
    durationMs: durationMs,
    sampleCount: points.length,
    avgRttMs: avg(points.map((p) => p.rttMs)),
    peakRttMs: peak(points.map((p) => p.rttMs)),
    peakJitterMs: peak(points.map((p) => p.jitterMs)),
    avgLossPercent: avg(points.map((p) => p.packetLossPercent)),
    peakLossPercent: peak(points.map((p) => p.packetLossPercent)),
    avgSendKbps: avg(points.map((p) => p.sendBitrateKbps)),
    avgRecvKbps: avg(points.map((p) => p.recvBitrateKbps)),
    worstLevel: worst,
    findingsCount: findingsCount,
  );
}

/// Constant-memory aggregates over the entire session, independent of chart eviction.
class RtcSummaryAccumulator {
  final _rtt = _Aggregate();
  final _jitter = _Aggregate();
  final _loss = _Aggregate();
  final _send = _Aggregate();
  final _recv = _Aggregate();
  int _count = 0;
  RtcQualityLevel _worst = RtcQualityLevel.unknown;

  void add(RtcTimelinePoint point) {
    _count++;
    _rtt.add(point.rttMs);
    _jitter.add(point.jitterMs);
    _loss.add(point.packetLossPercent);
    _send.add(point.sendBitrateKbps);
    _recv.add(point.recvBitrateKbps);
    if (point.level.index > _worst.index) _worst = point.level;
  }

  RtcSessionSummary finish({required DateTime startedAt, required int durationMs, required int findingsCount}) => RtcSessionSummary(
    startedAt: startedAt, durationMs: durationMs, sampleCount: _count,
    avgRttMs: _rtt.average, peakRttMs: _rtt.peak, peakJitterMs: _jitter.peak,
    avgLossPercent: _loss.average, peakLossPercent: _loss.peak,
    avgSendKbps: _send.average, avgRecvKbps: _recv.average,
    worstLevel: _worst, findingsCount: findingsCount,
  );
}

class _Aggregate {
  double _sum = 0;
  int _count = 0;
  double? peak;
  double? get average => _count == 0 ? null : _sum / _count;
  void add(double? value) {
    if (value == null || !value.isFinite) return;
    _sum += value;
    _count++;
    if (peak == null || value > peak!) peak = value;
  }
}
