import 'package:flutter/material.dart';
import 'package:rtc_probe/rtc/models.dart';

/// Display formatting for metrics. Unavailable values are always rendered as
/// an explicit "Not available" — never as a fake 0.
String msLabel(double? v) => v == null ? '—' : '${v.toStringAsFixed(0)} ms';

String kbpsLabel(double? v) =>
    v == null ? '—' : '${v.toStringAsFixed(v >= 100 ? 0 : 1)} kbps';

String percentLabel(double? v) => v == null ? '—' : '${v.toStringAsFixed(2)}%';

String fpsLabel(double? v) => v == null ? '—' : v.toStringAsFixed(0);

String countLabel(int? v) => v == null ? '—' : v.toString();

String bytesLabel(int? v) {
  if (v == null) return '—';
  if (v >= 1024 * 1024) return '${(v / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (v >= 1024) return '${(v / 1024).toStringAsFixed(1)} KB';
  return '$v B';
}

String durationLabel(int ms) {
  final m = (ms ~/ 60000).toString().padLeft(2, '0');
  final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
  return '$m:$s';
}

String clockLabel(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

Color qualityColor(RtcQualityLevel level, ColorScheme scheme) {
  switch (level) {
    case RtcQualityLevel.excellent:
      return const Color(0xFF2E7D32);
    case RtcQualityLevel.good:
      return const Color(0xFF43A047);
    case RtcQualityLevel.fair:
      return const Color(0xFFF9A825);
    case RtcQualityLevel.poor:
      return const Color(0xFFEF6C00);
    case RtcQualityLevel.critical:
      return const Color(0xFFC62828);
    case RtcQualityLevel.unknown:
      return scheme.outlineVariant;
  }
}

Color severityColor(RtcSeverity severity, ColorScheme scheme) {
  switch (severity) {
    case RtcSeverity.critical:
      return const Color(0xFFC62828);
    case RtcSeverity.warning:
      return const Color(0xFFEF6C00);
    case RtcSeverity.info:
      return scheme.outline;
  }
}
