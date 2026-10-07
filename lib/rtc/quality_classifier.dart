import 'package:rtc_probe/rtc/models.dart';

/// Deterministic quality classification thresholds.
///
/// These are RTCProbe's own operating defaults for a *local loopback probe* —
/// deliberately conservative values chosen to make degradation visible during
/// a demo. They are documented constants, not claimed industry standards;
/// see docs/qos.md for the rationale.
class RtcQosThresholds {
  const RtcQosThresholds({
    this.rttGoodMs = 80,
    this.rttFairMs = 150,
    this.rttPoorMs = 300,
    this.rttCriticalMs = 500,
    this.jitterGoodMs = 10,
    this.jitterFairMs = 20,
    this.jitterPoorMs = 40,
    this.jitterCriticalMs = 60,
    this.lossGoodPercent = 0.1,
    this.lossFairPercent = 0.5,
    this.lossPoorPercent = 1.5,
    this.lossCriticalPercent = 4.0,
  });

  final double rttGoodMs, rttFairMs, rttPoorMs, rttCriticalMs;
  final double jitterGoodMs, jitterFairMs, jitterPoorMs, jitterCriticalMs;
  final double lossGoodPercent, lossFairPercent, lossPoorPercent, lossCriticalPercent;

  static const RtcQosThresholds defaults = RtcQosThresholds();
}

/// Maps derived metrics onto a deterministic quality level.
///
/// Same input → same output, always. Unavailable metrics do not influence
/// the level; if every input metric is unavailable the level is `unknown`.
class RtcQualityClassifier {
  const RtcQualityClassifier({this.thresholds = RtcQosThresholds.defaults});

  final RtcQosThresholds thresholds;

  RtcQualityReport classify(RtcDerivedMetrics metrics) {
    final t = thresholds;
    final assessments = <RtcMetricAssessment>[
      if (metrics.rttMs != null)
        RtcMetricAssessment(
          metricId: 'rtt',
          level: _level(
            metrics.rttMs!,
            t.rttGoodMs,
            t.rttFairMs,
            t.rttPoorMs,
            t.rttCriticalMs,
          ),
          evidence: '${metrics.rttMs!.toStringAsFixed(0)} ms round-trip time',
        ),
      if (metrics.jitterMs != null)
        RtcMetricAssessment(
          metricId: 'jitter',
          level: _level(
            metrics.jitterMs!,
            t.jitterGoodMs,
            t.jitterFairMs,
            t.jitterPoorMs,
            t.jitterCriticalMs,
          ),
          evidence: '${metrics.jitterMs!.toStringAsFixed(1)} ms jitter',
        ),
      if (metrics.packetLossPercent != null)
        RtcMetricAssessment(
          metricId: 'packetLoss',
          level: _level(
            metrics.packetLossPercent!,
            t.lossGoodPercent,
            t.lossFairPercent,
            t.lossPoorPercent,
            t.lossCriticalPercent,
          ),
          evidence: '${metrics.packetLossPercent!.toStringAsFixed(2)}% packet loss',
        ),
    ];

    var level = RtcQualityLevel.unknown;
    for (final a in assessments) {
      if (a.level.index > level.index) level = a.level;
    }
    return RtcQualityReport(level: level, assessments: assessments);
  }

  RtcQualityLevel _level(double v, double good, double fair, double poor, double critical) {
    if (v <= good) return RtcQualityLevel.excellent;
    if (v <= fair) return RtcQualityLevel.good;
    if (v <= poor) return RtcQualityLevel.fair;
    if (v <= critical) return RtcQualityLevel.poor;
    return RtcQualityLevel.critical;
  }
}
