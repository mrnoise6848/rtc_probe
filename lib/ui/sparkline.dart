import 'package:flutter/material.dart';
import 'package:rtc_probe/rtc/models.dart';

/// Lightweight sparkline for the bounded timeline. Redraws only when the
/// controller notifies (1 Hz) — no animations, no charting dependency.
class MetricSparkline extends StatelessWidget {
  const MetricSparkline({
    super.key,
    required this.series,
    required this.color,
    required this.value,
    this.windowMs = 60000,
    this.height = 56,
  });

  final List<RtcTimelinePoint> series;
  final double? Function(RtcTimelinePoint) value;
  final Color color;
  final int windowMs;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Metric timeline chart for the last ${windowMs ~/ 1000} seconds',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparklinePainter(
            series: series,
            value: value,
            color: color,
            windowMs: windowMs,
          ),
        ),
      ),
    );
  }
}

typedef _ValueFn = double? Function(RtcTimelinePoint p);

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.series,
    required this.value,
    required this.color,
    required this.windowMs,
  });

  final List<RtcTimelinePoint> series;
  final _ValueFn value;
  final Color color;
  final int windowMs;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2) return;

    final last = series.last.elapsedMs;
    final cutoff = last - windowMs;
    final points = <Offset>[];
    double? minV, maxV;
    for (final p in series) {
      if (p.elapsedMs < cutoff) continue;
      final v = value(p);
      if (v == null || v.isNaN) continue;
      minV = minV == null || v < minV ? v : minV;
      maxV = maxV == null || v > maxV ? v : maxV;
      points.add(Offset(p.elapsedMs.toDouble(), v));
    }
    if (points.length < 2 || minV == null || maxV == null) return;

    final range = (maxV! - minV!) == 0 ? 1.0 : maxV - minV;
    final t0 = points.first.dx;
    final t1 = points.last.dx;
    final timeRange = (t1 - t0) == 0 ? 1.0 : t1 - t0;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = (points[i].dx - t0) / timeRange * size.width;
      final y =
          size.height - (points[i].dy - minV) / range * (size.height - 4) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.series != series ||
      oldDelegate.color != color ||
      oldDelegate.value != value ||
      oldDelegate.windowMs != windowMs;
}
