import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:rtc_probe/webrtc/loopback_session.dart';

/// Result of one stats pull from the probe peer.
class StatsCollectionResult {
  const StatsCollectionResult({required this.reports, this.error});

  final List<StatsReport>? reports;
  final String? error;

  bool get available => reports != null;
}

/// Pulls the raw WebRTC statistics report from the live session.
///
/// Failures (session ended, peer gone, native hiccup) are converted into an
/// unavailable result — the pipeline then marks metrics "Not available"
/// instead of fabricating values.
class RtcStatsCollector {
  const RtcStatsCollector(this._session);

  final LoopbackRtcSession _session;

  Future<StatsCollectionResult> collect() async {
    if (_session.isClosed) {
      return const StatsCollectionResult(reports: null, error: 'session closed');
    }
    try {
      final reports = await _session.collectStats();
      return StatsCollectionResult(reports: reports);
    } catch (_) {
      return const StatsCollectionResult(reports: null, error: 'native stats pull failed');
    }
  }
}
