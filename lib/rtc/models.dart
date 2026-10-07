/// RTCProbe domain models.
///
/// Pure Dart. No Flutter and no WebRTC plugin types are imported here: the UI
/// and analysis layers only see these types, and the engine adapter is the
/// single place that translates plugin statistics into [RtcStatsSnapshot].
library;

/// Peer-level connection state, normalized across platforms.
enum RtcConnectionState {
  idle,
  connecting,
  connected,
  disconnected,
  failed,
  closed,
}

/// ICE connection state, normalized across platforms.
enum RtcIceState {
  idle,
  checking,
  connected,
  completed,
  failed,
  disconnected,
  closed,
}

/// Session-level lifecycle of a probe run.
enum RtcSessionPhase { idle, starting, live, ended, failed }

/// Media kinds the user granted for this session.
enum RtcMediaGrant { none, audioOnly, audioVideo }

/// Deterministic quality classification levels.
enum RtcQualityLevel { unknown, excellent, good, fair, poor, critical }

/// Severity of a diagnostic finding.
enum RtcSeverity { info, warning, critical }

/// Stable identifiers for diagnostic findings.
enum RtcFindingCode {
  elevatedRtt,
  highJitter,
  highPacketLoss,
  lowOutboundBitrate,
  videoFramesStalled,
  connectionInterrupted,
  mediaUnavailable,
}

/// Kinds of entries in the session event log.
enum RtcSessionEventKind {
  sessionStarted,
  sessionEnded,
  connectionState,
  iceState,
  qualityChanged,
  findingRaised,
  findingCleared,
  degradationApplied,
  mediaDenied,
  networkPathChanged,
  error,
}

/// One probe session: identity plus what the user allowed us to capture.
class RtcSession {
  RtcSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.mediaGrant = RtcMediaGrant.none,
  });

  final String id;
  final DateTime startedAt;
  DateTime? endedAt;
  RtcMediaGrant mediaGrant;

  /// Signaling topology label shown in the UI / summary.
  static const String signalingMode =
      'local in-process loopback (probe ↔ mirror)';
}

/// Information about the currently selected ICE candidate pair.
class RtcCandidatePairInfo {
  const RtcCandidatePairInfo({
    required this.state,
    required this.nominated,
    required this.localCandidateType,
    required this.remoteCandidateType,
    required this.availableOutgoingBitbps,
    this.currentRttMs,
  });

  final String state;
  final bool nominated;
  final String localCandidateType; // host / srflx / prflx / relay
  final String remoteCandidateType;
  final int?
  availableOutgoingBitbps; // BPS estimate from the transport, may be null
  final double? currentRttMs; // transport-level RTT from getStats (s → ms)
}

/// DTLS/transport-level state.
class RtcTransportStats {
  const RtcTransportStats({required this.dtlsState});
  final String dtlsState;
}

/// Cumulative counters for one RTP stream direction + kind.
///
/// Fields the platform does not report stay null — never zero-filled.
class RtcMediaStreamStats {
  const RtcMediaStreamStats({
    required this.kind,
    required this.direction,
    required this.ssrc,
    this.bytes,
    this.packets,
    this.packetsLost,
    this.packetsDiscarded,
    this.jitterMs,
    this.roundTripTimeMs,
    this.fractionLost,
    this.framesPerSecond,
    this.frames,
    this.framesDropped,
    this.width,
    this.height,
    this.targetBitrateBps,
  });

  final String kind; // audio | video
  final String direction; // outbound | inbound
  final int ssrc;
  final int? bytes;
  final int? packets;
  final int? packetsLost;
  final int? packetsDiscarded;
  final double? jitterMs;
  final double? roundTripTimeMs; // reported by the remote side via RTCP
  final double? fractionLost; // 0.0–1.0, remote report
  final double? framesPerSecond;
  final int? frames;
  final int? framesDropped;
  final int? width;
  final int? height;
  final int? targetBitrateBps;
}

/// Data-channel counters (session control channel).
class RtcDataChannelStats {
  const RtcDataChannelStats({
    required this.label,
    this.bytesSent,
    this.bytesReceived,
    this.messagesSent,
    this.messagesReceived,
  });

  final String label;
  final int? bytesSent;
  final int? bytesReceived;
  final int? messagesSent;
  final int? messagesReceived;
}

/// Normalized statistics for one sampling tick of the probe peer.
class RtcStatsSnapshot {
  const RtcStatsSnapshot({
    required this.timestampMs,
    required this.elapsedMs,
    required this.connectionState,
    required this.iceState,
    this.candidatePair,
    this.transport,
    this.outboundAudio,
    this.outboundVideo,
    this.inboundAudio,
    this.inboundVideo,
    this.dataChannel,
  });

  final int timestampMs; // wall clock
  final int elapsedMs; // ms since session start
  final RtcConnectionState connectionState;
  final RtcIceState iceState;
  final RtcCandidatePairInfo? candidatePair;
  final RtcTransportStats? transport;
  final RtcMediaStreamStats? outboundAudio;
  final RtcMediaStreamStats? outboundVideo;
  final RtcMediaStreamStats? inboundAudio;
  final RtcMediaStreamStats? inboundVideo;
  final RtcDataChannelStats? dataChannel;
}

/// Metrics derived by comparing consecutive snapshots.
///
/// Every value is either computed from real counters or null (= not available).
class RtcDerivedMetrics {
  const RtcDerivedMetrics({
    this.rttMs,
    this.jitterMs,
    this.packetLossPercent,
    this.sendBitrateKbps,
    this.recvBitrateKbps,
    this.videoFps,
    this.sendResolution,
  });

  final double? rttMs;
  final double? jitterMs;
  final double? packetLossPercent;
  final double? sendBitrateKbps;
  final double? recvBitrateKbps;
  final double? videoFps;
  final String? sendResolution; // e.g. "1280×720"
}

/// Per-metric assessment feeding the overall quality level.
class RtcMetricAssessment {
  const RtcMetricAssessment({
    required this.metricId,
    required this.level,
    required this.evidence,
  });

  final String metricId; // rtt | jitter | packetLoss
  final RtcQualityLevel level;
  final String evidence; // human readable, includes the real value
}

/// Result of the deterministic quality classifier.
class RtcQualityReport {
  const RtcQualityReport({required this.level, required this.assessments});

  final RtcQualityLevel level; // worst of assessments
  final List<RtcMetricAssessment> assessments;
}

/// A diagnostic finding: what was detected, the evidence, and likely impact.
///
/// Findings use hedged language — they describe what the data suggests, not
/// certain root causes.
class RtcFinding {
  RtcFinding({
    required this.code,
    required this.severity,
    required this.title,
    required this.evidence,
    required this.impact,
    required this.firstDetectedMs,
  });

  final RtcFindingCode code;
  final RtcSeverity severity;
  final String title;
  final String evidence; // concrete numbers from real stats
  final String impact; // possible effect, phrased with "may/might"
  final int firstDetectedMs;
  int lastSeenMs = 0;

  /// True while the underlying condition keeps being observed.
  bool active = true;
}

/// One point of the bounded metric timeline.
class RtcTimelinePoint {
  const RtcTimelinePoint({
    required this.elapsedMs,
    this.rttMs,
    this.jitterMs,
    this.packetLossPercent,
    this.sendBitrateKbps,
    this.recvBitrateKbps,
    this.videoFps,
    required this.level,
  });

  final int elapsedMs;
  final double? rttMs;
  final double? jitterMs;
  final double? packetLossPercent;
  final double? sendBitrateKbps;
  final double? recvBitrateKbps;
  final double? videoFps;
  final RtcQualityLevel level;
}

/// One entry in the bounded session event log.
class RtcSessionEvent {
  const RtcSessionEvent({
    required this.wallClock,
    required this.elapsedMs,
    required this.kind,
    required this.message,
  });

  final DateTime wallClock; // only for display; diagnostics metadata only
  final int elapsedMs;
  final RtcSessionEventKind kind;
  final String message;
}

/// Aggregates computed from the timeline when a session ends.
class RtcSessionSummary {
  const RtcSessionSummary({
    required this.startedAt,
    required this.durationMs,
    required this.sampleCount,
    this.avgRttMs,
    this.peakRttMs,
    this.peakJitterMs,
    this.avgLossPercent,
    this.peakLossPercent,
    this.avgSendKbps,
    this.avgRecvKbps,
    required this.worstLevel,
    required this.findingsCount,
  });

  final DateTime startedAt;
  final int durationMs;
  final int sampleCount;
  final double? avgRttMs;
  final double? peakRttMs;
  final double? peakJitterMs;
  final double? avgLossPercent;
  final double? peakLossPercent;
  final double? avgSendKbps;
  final double? avgRecvKbps;
  final RtcQualityLevel worstLevel;
  final int findingsCount;
}

/// Generic display metric (label + formatted value or "not available").
class RtcMetric {
  const RtcMetric(this.id, this.label, this.value, this.unit);

  const RtcMetric.unavailable(this.id, this.label) : value = null, unit = '';

  final String id;
  final String label;
  final String? value; // null → UI shows "Not available"
  final String unit;
}

/// Current state of the device network path, reported by the native layer.
class NetworkPathInfo {
  const NetworkPathInfo({
    required this.interfaceType,
    required this.isExpensive,
    required this.isConstrained,
    required this.source,
  });

  const NetworkPathInfo.unavailable()
    : interfaceType = 'unavailable',
      isExpensive = false,
      isConstrained = false,
      source = 'unavailable';

  final String interfaceType; // wifi | cellular | ethernet | none | unavailable
  final bool isExpensive; // e.g. cellular / hotspot
  final bool isConstrained; // OS reports low-data mode
  final String
  source; // swift-nwpathmonitor | kotlin-connectivity | unavailable

  /// True when the native layer reported something usable.
  bool get isAvailable =>
      interfaceType != 'unavailable' && interfaceType != 'none';
}
