import 'package:flutter_test/flutter_test.dart';
import 'package:rtc_probe/rtc/models.dart';
import 'package:rtc_probe/rtc/quality_classifier.dart';

void main() {
  const classifier = RtcQualityClassifier();

  test('level is the worst assessed metric (deterministic)', () {
    final report = classifier.classify(
      const RtcDerivedMetrics(rttMs: 48, jitterMs: 7.3, packetLossPercent: 5.1),
    );
    expect(report.level, RtcQualityLevel.critical);
    expect(report.assessments.length, 3);
  });

  test(
    'unavailable metrics are excluded and yield unknown when all absent',
    () {
      final report = classifier.classify(const RtcDerivedMetrics());
      expect(report.level, RtcQualityLevel.unknown);
      expect(report.assessments, isEmpty);
    },
  );

  test('threshold boundaries', () {
    RtcQualityLevel level(double rtt) =>
        classifier.classify(RtcDerivedMetrics(rttMs: rtt)).level;

    expect(level(80), RtcQualityLevel.excellent);
    expect(level(80.1), RtcQualityLevel.good);
    expect(level(150.1), RtcQualityLevel.fair);
    expect(level(300.1), RtcQualityLevel.poor);
    expect(level(500.1), RtcQualityLevel.critical);
  });

  test('same input always produces the same output', () {
    const m = RtcDerivedMetrics(
      rttMs: 123,
      jitterMs: 45,
      packetLossPercent: 2.0,
    );
    expect(classifier.classify(m).level, classifier.classify(m).level);
    expect(classifier.classify(m).level, RtcQualityLevel.poor);
  });
}
