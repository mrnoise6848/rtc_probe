import 'package:rtc_probe/rtc/models.dart';

/// Result of one diagnostic evaluation pass.
class DiagnosticsUpdate {
  const DiagnosticsUpdate({required this.raised, required this.cleared, required this.active});

  final List<RtcFinding> raised; // newly confirmed this tick
  final List<RtcFinding> cleared; // condition gone, removed this tick
  final List<RtcFinding> active; // currently held findings (snapshot)
}

/// Deterministic, rule-based diagnostic engine.
///
/// A condition must persist for a number of consecutive samples before it
/// becomes a finding (avoiding single-sample noise), and must stay gone for
/// a number of samples before the finding clears. Findings quote the actual
/// measured values as evidence and describe *possible* impact with hedged
/// language — they never claim a certain root cause.
class RtcDiagnosticEngine {
  RtcDiagnosticEngine({
    this.sustainTicks = 3,
    this.clearTicks = 3,
    this.stallSustainTicks = 5,
  });

  final int sustainTicks;
  final int clearTicks;
  final int stallSustainTicks;

  final _strikes = <RtcFindingCode, int>{};
  final _calm = <RtcFindingCode, int>{};
  final _findings = <RtcFindingCode, RtcFinding>{};

  List<RtcFinding> get activeFindings => List.unmodifiable(_findings.values);

  void reset() {
    _strikes.clear();
    _calm.clear();
    _findings.clear();
  }

  /// Raises (or refreshes) a finding outside the sustained-rule pipeline —
  /// used for event-driven facts such as denied media permissions.
  void raiseManual(RtcFinding finding) {
    finding.lastSeenMs = finding.firstDetectedMs;
    _findings[finding.code] = finding;
  }

  DiagnosticsUpdate evaluate({
    required RtcStatsSnapshot snapshot,
    required RtcDerivedMetrics metrics,
    required bool videoSending,
    required int elapsedMs,
  }) {
    final raised = <RtcFinding>[];
    final cleared = <RtcFinding>[];

    final rules = <RtcFindingCode, bool Function()>{
      RtcFindingCode.elevatedRtt: () => metrics.rttMs != null && metrics.rttMs! > 300,
      RtcFindingCode.highJitter: () => metrics.jitterMs != null && metrics.jitterMs! > 40,
      RtcFindingCode.highPacketLoss: () =>
          metrics.packetLossPercent != null && metrics.packetLossPercent! > 4.0,
      RtcFindingCode.lowOutboundBitrate: () =>
          videoSending &&
          metrics.sendBitrateKbps != null &&
          metrics.sendBitrateKbps! < 100 &&
          snapshot.connectionState == RtcConnectionState.connected,
      RtcFindingCode.videoFramesStalled: () =>
          videoSending && (metrics.videoFps != null && metrics.videoFps! <= 0.01),
      RtcFindingCode.connectionInterrupted: () =>
          snapshot.connectionState == RtcConnectionState.disconnected ||
          snapshot.connectionState == RtcConnectionState.failed,
    };

    rules.forEach((code, condition) {
      final needed = code == RtcFindingCode.videoFramesStalled ? stallSustainTicks : sustainTicks;
      if (condition()) {
        _strikes[code] = (_strikes[code] ?? 0) + 1;
        _calm[code] = 0;
        if (_strikes[code]! >= needed && !_findings.containsKey(code)) {
          final finding = _buildFinding(code, metrics, snapshot, elapsedMs);
          _findings[code] = finding;
          raised.add(finding);
        } else if (_findings.containsKey(code)) {
          _findings[code]!.lastSeenMs = elapsedMs;
        }
      } else {
        _strikes[code] = 0;
        if (_findings.containsKey(code)) {
          _calm[code] = (_calm[code] ?? 0) + 1;
          if (_calm[code]! >= clearTicks) {
            cleared.add(_findings.remove(code)!);
          }
        }
      }
    });

    return DiagnosticsUpdate(raised: raised, cleared: cleared, active: activeFindings);
  }

  RtcFinding _buildFinding(
    RtcFindingCode code,
    RtcDerivedMetrics m,
    RtcStatsSnapshot s,
    int elapsedMs,
  ) {
    switch (code) {
      case RtcFindingCode.elevatedRtt:
        return RtcFinding(
          code: code,
          severity: RtcSeverity.warning,
          title: 'Elevated round-trip time',
          evidence:
              'RTT ${m.rttMs!.toStringAsFixed(0)} ms sustained over $sustainTicks samples (threshold 300 ms).',
          impact: 'Conversation overlap may increase; interactive media likely feels laggy.',
          firstDetectedMs: elapsedMs,
        );
      case RtcFindingCode.highJitter:
        return RtcFinding(
          code: code,
          severity: RtcSeverity.warning,
          title: 'High jitter',
          evidence:
              'Jitter ${m.jitterMs!.toStringAsFixed(1)} ms sustained over $sustainTicks samples (threshold 40 ms).',
          impact: 'Audio may sound choppy and video may stutter; buffers may need to grow.',
          firstDetectedMs: elapsedMs,
        );
      case RtcFindingCode.highPacketLoss:
        return RtcFinding(
          code: code,
          severity: RtcSeverity.critical,
          title: 'High packet loss',
          evidence:
              'Packet loss ${m.packetLossPercent!.toStringAsFixed(2)}% sustained over $sustainTicks samples (threshold 4.0%).',
          impact: 'Video quality may visibly degrade and audio may glitch as loss concealment kicks in.',
          firstDetectedMs: elapsedMs,
        );
      case RtcFindingCode.lowOutboundBitrate:
        return RtcFinding(
          code: code,
          severity: RtcSeverity.warning,
          title: 'Low outbound bitrate',
          evidence:
              'Send bitrate ${m.sendBitrateKbps!.toStringAsFixed(0)} kbps while the connection stayed established (threshold 100 kbps).',
          impact: 'The encoder may be starved — video resolution and quality may drop significantly.',
          firstDetectedMs: elapsedMs,
        );
      case RtcFindingCode.videoFramesStalled:
        return RtcFinding(
          code: code,
          severity: RtcSeverity.warning,
          title: 'Outbound video frames stalled',
          evidence:
              'The encoder reported 0 fps for $stallSustainTicks consecutive samples while video was enabled.',
          impact: 'Remote participants may see a frozen picture while audio continues.',
          firstDetectedMs: elapsedMs,
        );
      case RtcFindingCode.connectionInterrupted:
        return RtcFinding(
          code: code,
          severity: RtcSeverity.critical,
          title: 'Connection interrupted',
          evidence: 'Connection state reported ${s.connectionState.name} for $sustainTicks samples.',
          impact: 'Media flow stops until connectivity is re-established or the session is restarted.',
          firstDetectedMs: elapsedMs,
        );
      case RtcFindingCode.mediaUnavailable:
        return RtcFinding(
          code: code,
          severity: RtcSeverity.info,
          title: 'Media unavailable',
          evidence: 'Camera/microphone permission denied; session runs on data channel only.',
          impact: 'Media metrics will report "Not available" — transport diagnostics remain valid.',
          firstDetectedMs: elapsedMs,
        );
    }
  }
}
