import 'dart:async';

typedef RtcSampleTick = Future<void> Function();

/// Single periodic sampling driver for a session.
///
/// One timer per app, a configurable interval (1 s by default), overlap-safe:
/// a slow tick is skipped rather than queued. Cancellation is explicit and
/// unambiguous — [stop] is idempotent and safe from any state.
class RtcSampler {
  RtcSampler({this.interval = const Duration(seconds: 1)});

  /// Sampling period. 1 Hz keeps UI updates cheap while giving the classifier
  /// enough resolution to observe degradation within a few seconds.
  final Duration interval;

  Timer? _timer;
  bool _ticking = false;

  bool get isRunning => _timer != null;

  void start(RtcSampleTick onTick) {
    stop();
    _timer = Timer.periodic(interval, (_) async {
      if (_ticking) return; // previous tick still in flight — skip this one
      _ticking = true;
      try {
        await onTick();
      } finally {
        _ticking = false;
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _ticking = false;
  }
}
