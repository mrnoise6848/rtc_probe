import 'package:flutter/material.dart';
import 'package:rtc_probe/rtc/models.dart';

/// Display formatting for metrics. Unavailable values are always rendered as
/// an explicit "Not available" — never as a fake 0.
String msLabel(double? v) =>
    v == null ? '—' : '${v.toStringAsFixed(v < 10 ? 2 : (v < 100 ? 1 : 0))} ms';

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
  final dark = scheme.brightness == Brightness.dark;
  return switch (level) {
    RtcQualityLevel.excellent => Color(dark ? 0xFFA7F3D0 : 0xFF1B5E20),
    RtcQualityLevel.good => Color(dark ? 0xFF86EFAC : 0xFF2E7D32),
    RtcQualityLevel.fair => Color(dark ? 0xFFFDE68A : 0xFF854D0E),
    RtcQualityLevel.poor => Color(dark ? 0xFFFDBA74 : 0xFF9A3412),
    RtcQualityLevel.critical => Color(dark ? 0xFFFCA5A5 : 0xFF991B1B),
    RtcQualityLevel.unknown => scheme.onSurfaceVariant,
  };
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
