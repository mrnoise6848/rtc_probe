import 'package:flutter_test/flutter_test.dart';
import 'package:rtc_probe/rtc/models.dart';
import 'package:rtc_probe/rtc/timeline.dart';

void main() {
  test('timeline is bounded — oldest points are dropped', () {
    final timeline = RtcTimeline(maxPoints: 5);
    for (var i = 0; i < 12; i++) {
      timeline.push(
        RtcTimelinePoint(elapsedMs: i * 1000, level: RtcQualityLevel.good),
      );
    }
    expect(timeline.length, 5);
    expect(timeline.points.first.elapsedMs, 7 * 1000);
    expect(timeline.last!.elapsedMs, 11 * 1000);
  });

  test('trailing window returns only recent points', () {
    final timeline = RtcTimeline();
    for (var i = 0; i < 20; i++) {
      timeline.push(
        RtcTimelinePoint(elapsedMs: i * 1000, level: RtcQualityLevel.good),
      );
    }
    final window = timeline.trailing(5000);
    expect(window.first.elapsedMs, 14 * 1000);
    expect(window.last.elapsedMs, 19 * 1000);
  });

  test('session summary aggregates real values only', () {
    final now = DateTime.now();
    final summary = summarizeSession(
      startedAt: now,
      durationMs: 4000,
      findingsCount: 2,
      points: const [
        RtcTimelinePoint(
          elapsedMs: 1000,
          rttMs: 40,
          jitterMs: 5,
          packetLossPercent: 0.1,
          level: RtcQualityLevel.excellent,
        ),
        RtcTimelinePoint(
          elapsedMs: 2000,
          rttMs: 60,
          jitterMs: 82,
          packetLossPercent: 1.0,
          level: RtcQualityLevel.poor,
        ),
        RtcTimelinePoint(
          elapsedMs: 3000,
          rttMs: 53,
          jitterMs: 10,
          packetLossPercent: 0.4,
          level: RtcQualityLevel.good,
        ),
      ],
    );

    expect(summary.avgRttMs, closeTo(51, 0.001));
    expect(summary.peakJitterMs, 82);
    expect(summary.avgLossPercent, closeTo(0.5, 0.001));
    expect(summary.worstLevel, RtcQualityLevel.poor);
    expect(summary.findingsCount, 2);
    expect(summary.sampleCount, 3);
  });
}
