import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:rtc_probe/rtc/models.dart';

/// Translates raw `getStats()` reports into a normalized [RtcStatsSnapshot].
///
/// This is the platform boundary for statistics: everything downstream
/// (metrics, classification, UI) only sees domain types and never plugin
/// field names. Fields a platform does not report stay `null` — never zero.
class RtcStatsNormalizer {
  const RtcStatsNormalizer();

  RtcStatsSnapshot normalize({
    required List<StatsReport> reports,
    required int elapsedMs,
    required RtcConnectionState connectionState,
    required RtcIceState iceState,
  }) {
    final byType = <String, List<StatsReport>>{};
    for (final r in reports) {
      byType.putIfAbsent(r.type, () => []).add(r);
    }
    final byId = {for (final r in reports) r.id: r};

    final transport = _transport(byType['transport']);
    final pair = _candidatePair(
      byType['candidate-pair'] ?? const [],
      transport?.selectedPairId,
      byId,
    );

    RtcMediaStreamStats? outboundAudio;
    RtcMediaStreamStats? outboundVideo;
    RtcMediaStreamStats? inboundAudio;
    RtcMediaStreamStats? inboundVideo;

    for (final r in byType['outbound-rtp'] ?? const []) {
      final stats = _outbound(
        r,
        remoteInbound: _matchingRemoteInbound(r, byType['remote-inbound-rtp']),
      );
      if (stats.kind == 'audio') {
        outboundAudio = stats;
      } else if (stats.kind == 'video') {
        outboundVideo = stats;
      }
    }
    for (final r in byType['inbound-rtp'] ?? const []) {
      final stats = _inbound(r);
      if (stats.kind == 'audio') {
        inboundAudio = stats;
      } else if (stats.kind == 'video') {
        inboundVideo = stats;
      }
    }

    return RtcStatsSnapshot(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      elapsedMs: elapsedMs,
      connectionState: connectionState,
      iceState: iceState,
      candidatePair: pair,
      transport: transport,
      outboundAudio: outboundAudio,
      outboundVideo: outboundVideo,
      inboundAudio: inboundAudio,
      inboundVideo: inboundVideo,
      dataChannel: _dataChannel(byType['data-channel'] ?? const []),
    );
  }

  StatsReport? _matchingRemoteInbound(
    StatsReport outbound,
    List<StatsReport>? remoteInbound,
  ) {
    if (remoteInbound == null || remoteInbound.isEmpty) return null;
    final ssrc = outbound.values['ssrc']?.toString();
    for (final r in remoteInbound) {
      if (r.values['ssrc']?.toString() == ssrc) return r;
    }
    return null;
  }

  _TransportInfo? _transport(List<StatsReport>? reports) {
    if (reports == null || reports.isEmpty) return null;
    final t = reports.first;
    return _TransportInfo(
      dtlsState: t.values['dtlsState']?.toString() ?? 'unknown',
      selectedPairId: t.values['selectedCandidatePairId']?.toString(),
    );
  }

  RtcCandidatePairInfo? _candidatePair(
    List<StatsReport> pairs,
    String? selectedPairId,
    Map<String, StatsReport> byId,
  ) {
    if (pairs.isEmpty) return null;
    StatsReport? selected;
    if (selectedPairId != null) {
      for (final p in pairs) {
        if (p.id == selectedPairId) selected = p;
      }
    }
    selected ??= pairs.firstWhere(
      (p) =>
          p.values['state']?.toString() == 'succeeded' &&
          p.values['nominated'] == true,
      orElse: () => pairs.firstWhere(
        (p) => p.values['state']?.toString() == 'succeeded',
        orElse: () => pairs.first,
      ),
    );

    final localId = selected.values['localCandidateId']?.toString();
    final remoteId = selected.values['remoteCandidateId']?.toString();
    return RtcCandidatePairInfo(
      state: selected.values['state']?.toString() ?? 'unknown',
      nominated: selected.values['nominated'] == true,
      localCandidateType: _candidateType(byId[localId]),
      remoteCandidateType: _candidateType(byId[remoteId]),
      availableOutgoingBitbps: _num(selected.values['availableOutgoingBitrate'])
          ?.round(),
      currentRttMs: _secondsToMs(_num(selected.values['currentRoundTripTime'])),
    );
  }

  String _candidateType(StatsReport? candidate) {
    if (candidate == null) return 'unknown';
    return candidate.values['candidateType']?.toString() ?? 'unknown';
  }

  RtcMediaStreamStats _outbound(StatsReport r, {StatsReport? remoteInbound}) {
    return RtcMediaStreamStats(
      kind: _kind(r),
      direction: 'outbound',
      ssrc: _num(r.values['ssrc'])?.toInt() ?? 0,
      bytes: _num(r.values['bytesSent'])?.toInt(),
      packets: _num(r.values['packetsSent'])?.toInt(),
      jitterMs: null, // outbound reports carry no jitter; see remote-inbound
      roundTripTimeMs: _secondsToMs(
        _num(remoteInbound?.values['roundTripTime']),
      ),
      fractionLost: _num(remoteInbound?.values['fractionLost'])?.toDouble(),
      framesPerSecond: _num(r.values['framesPerSecond'])?.toDouble(),
      frames: _num(r.values['framesEncoded'])?.toInt(),
      width: _num(r.values['frameWidth'])?.toInt(),
      height: _num(r.values['frameHeight'])?.toInt(),
      targetBitrateBps: _num(r.values['targetBitrate'])?.toInt(),
    );
  }

  RtcMediaStreamStats _inbound(StatsReport r) {
    return RtcMediaStreamStats(
      kind: _kind(r),
      direction: 'inbound',
      ssrc: _num(r.values['ssrc'])?.toInt() ?? 0,
      bytes: _num(r.values['bytesReceived'])?.toInt(),
      packets: _num(r.values['packetsReceived'])?.toInt(),
      packetsLost: _num(r.values['packetsLost'])?.toInt(),
      packetsDiscarded: _num(r.values['packetsDiscarded'])?.toInt(),
      jitterMs: _secondsToMs(_num(r.values['jitter'])),
      framesPerSecond: _num(r.values['framesPerSecond'])?.toDouble(),
      frames: _num(r.values['framesDecoded'])?.toInt(),
      framesDropped: _num(r.values['framesDropped'])?.toInt(),
      width: _num(r.values['frameWidth'])?.toInt(),
      height: _num(r.values['frameHeight'])?.toInt(),
    );
  }

  RtcDataChannelStats? _dataChannel(List<StatsReport> reports) {
    for (final r in reports) {
      if (r.values['label']?.toString() == 'probe-ctl') {
        return RtcDataChannelStats(
          label: 'probe-ctl',
          bytesSent: _num(r.values['bytesSent'])?.toInt(),
          bytesReceived: _num(r.values['bytesReceived'])?.toInt(),
          messagesSent: _num(r.values['messagesSent'])?.toInt(),
          messagesReceived: _num(r.values['messagesReceived'])?.toInt(),
        );
      }
    }
    return null;
  }

  String _kind(StatsReport r) {
    final kind =
        r.values['kind']?.toString() ?? r.values['mediaType']?.toString();
    if (kind == 'audio' || kind == 'video') return kind;
    // Fall back to heuristics on the report id used by some native builds.
    final id = r.id.toLowerCase();
    if (id.contains('audio')) return 'audio';
    if (id.contains('video')) return 'video';
    return 'unknown';
  }

  /// Reports may deliver numbers as num or numeric strings depending on the
  /// platform codec layer; accepts both.
  num? _num(dynamic value) {
    if (value is num) return value.isFinite ? value : null;
    if (value is String) {
      final parsed = num.tryParse(value);
      return parsed?.isFinite == true ? parsed : null;
    }
    return null;
  }

  double? _secondsToMs(num? seconds) {
    if (seconds == null) return null;
    return seconds.toDouble() * 1000.0;
  }
}

/// Internal transport wrapper carrying the selected pair id forward.
class _TransportInfo implements RtcTransportStats {
  _TransportInfo({required this.dtlsState, this.selectedPairId});

  @override
  final String dtlsState;
  final String? selectedPairId;
}
