import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rtc_probe/native/network_info_service.dart';
import 'package:rtc_probe/rtc/diagnostic_engine.dart';
import 'package:rtc_probe/rtc/metrics_calculator.dart';
import 'package:rtc_probe/rtc/models.dart';
import 'package:rtc_probe/rtc/quality_classifier.dart';
import 'package:rtc_probe/rtc/sampler.dart';
import 'package:rtc_probe/rtc/timeline.dart';
import 'package:rtc_probe/webrtc/loopback_session.dart';
import 'package:rtc_probe/webrtc/media_access.dart';
import 'package:rtc_probe/webrtc/stats_collector.dart';
import 'package:rtc_probe/webrtc/stats_normalizer.dart';

/// Owns the live session and drives the whole diagnostics pipeline:
///
///   sample → normalize → derive → classify → diagnose → timeline → notify UI
///
/// One [ChangeNotifier] for the app; the UI listens and rebuilds once per
/// sample tick (1 Hz), never per raw event.
class SessionController extends ChangeNotifier {
  SessionController({
    this.samplingInterval = const Duration(seconds: 1),
    NetworkInfoService? networkInfoService,
  }) : _networkInfo = networkInfoService ?? const NetworkInfoService();

  final Duration samplingInterval;
  final NetworkInfoService _networkInfo;

  // Pipeline components (pure Dart, stateless except engine/timeline).
  final RtcStatsNormalizer _normalizer = const RtcStatsNormalizer();
  final RtcMetricsCalculator _calculator = const RtcMetricsCalculator();
  final RtcQualityClassifier _classifier = const RtcQualityClassifier();
  final RtcDiagnosticEngine _diagnostics = RtcDiagnosticEngine();

  LoopbackRtcSession? _session;
  RtcStatsCollector? _collector;
  RtcSampler? _sampler;
  StreamSubscription? _connSub;
  StreamSubscription? _iceSub;
  StreamSubscription? _appRttSub;
  RtcStatsSnapshot? _previousSnapshot;

  final RtcTimeline _timeline = RtcTimeline();
  final List<RtcSessionEvent> _events = <RtcSessionEvent>[];
  static const int _maxEvents = 200;

  // ---- Observable state -------------------------------------------------
  RtcSessionPhase _phase = RtcSessionPhase.idle;
  RtcConnectionState _connectionState = RtcConnectionState.idle;
  RtcIceState _iceState = RtcIceState.idle;
  RtcSession? _sessionModel;
  RtcStatsSnapshot? _snapshot;
  RtcDerivedMetrics _metrics = const RtcDerivedMetrics();
  RtcQualityReport _quality =
      const RtcQualityReport(level: RtcQualityLevel.unknown, assessments: []);
  RtcQualityLevel _lastNotifiedLevel = RtcQualityLevel.unknown;
  NetworkPathInfo _networkPath = const NetworkPathInfo.unavailable();
  double? _appRttMs;
  RtcSessionSummary? _summary;
  bool _videoTrackEnabled = true;
  int? _appliedBitrateCapKbps;
  bool _statsUnavailableLogged = false;

  RtcSessionPhase get phase => _phase;
  RtcConnectionState get connectionState => _connectionState;
  RtcIceState get iceState => _iceState;
  RtcSession? get sessionModel => _sessionModel;
  RtcStatsSnapshot? get snapshot => _snapshot;
  RtcDerivedMetrics get metrics => _metrics;
  RtcQualityReport get quality => _quality;
  NetworkPathInfo get networkPath => _networkPath;
  double? get appRttMs => _appRttMs;
  RtcSessionSummary? get summary => _summary;
  bool get isLive => _phase == RtcSessionPhase.live || _phase == RtcSessionPhase.starting;
  bool get videoTrackEnabled => _videoTrackEnabled;
  int? get appliedBitrateCapKbps => _appliedBitrateCapKbps;
  bool get hasVideoGrant => _sessionModel?.mediaGrant == RtcMediaGrant.audioVideo;
  List<RtcFinding> get findings => _diagnostics.activeFindings;
  List<RtcTimelinePoint> get timelinePoints => _timeline.points;
  List<RtcSessionEvent> get events => List.unmodifiable(_events);

  // ---- Session lifecycle -------------------------------------------------

  Future<void> start() async {
    if (isLive) return;
    _phase = RtcSessionPhase.starting;
    _resetSessionState();
    _log(RtcSessionEventKind.sessionStarted, 'Session starting (${RtcSession.signalingMode})');
    notifyListeners();

    _networkPath = await _networkInfo.current();
    _log(
      RtcSessionEventKind.networkPathChanged,
      'Network path: ${_networkPath.interfaceType}'
      '${_networkPath.isExpensive ? " (expensive)" : ""}'
      '${_networkPath.isConstrained ? " (constrained)" : ""}',
    );

    // Contextual permission request with graceful degradation.
    final access = await const MediaAccess().acquire();
    if (access.deniedKinds.isNotEmpty) {
      _log(RtcSessionEventKind.mediaDenied,
          'Media denied: ${access.deniedKinds.join(", ")} — falling back to data-channel-only session');
      _diagnostics.raiseManual(RtcFinding(
        code: RtcFindingCode.mediaUnavailable,
        severity: RtcSeverity.info,
        title: 'Media unavailable',
        evidence: 'Permission denied for ${access.deniedKinds.join(", ")}.',
        impact: 'Media metrics will report "Not available"; transport diagnostics remain valid.',
        firstDetectedMs: 0,
      ));
    }

    try {
      _session = await LoopbackRtcSession.start(media: access.stream);
    } catch (e) {
      _phase = RtcSessionPhase.failed;
      _log(RtcSessionEventKind.error, 'Session failed to start: $e');
      notifyListeners();
      return;
    }

    _sessionModel = RtcSession(
      id: 'probe-${DateTime.now().millisecondsSinceEpoch}',
      startedAt: _session!.startedAt!,
      mediaGrant: access.grant,
    );

    _collector = RtcStatsCollector(_session!);
    _connSub = _session!.connectionStates.listen(_onConnectionState);
    _iceSub = _session!.iceStates.listen(_onIceState);
    _appRttSub = _session!.appRttMs.listen((rtt) {
      _appRttMs = rtt;
      // No notifyListeners: surfaced with the next sample tick.
    });

    _phase = RtcSessionPhase.live;
    _videoTrackEnabled = true;
    _log(RtcSessionEventKind.sessionStarted,
        'Session live — media grant: ${access.grant.name}');
    notifyListeners();

    _sampler = RtcSampler(interval: samplingInterval)..start(_tick);
  }

  Future<void> stop() async {
    if (_phase != RtcSessionPhase.live && _phase != RtcSessionPhase.starting) return;
    _sampler?.stop();
    _sampler = null;
    await _cancelSubscriptions();
    final session = _session;
    _session = null;
    _collector = null;

    if (_sessionModel != null) {
      _sessionModel!.endedAt = DateTime.now();
    }
    await session?.close();

    _summary = summarizeSession(
      startedAt: _sessionModel?.startedAt ?? DateTime.now(),
      durationMs: _timeline.last?.elapsedMs ?? 0,
      points: _timeline.points,
      findingsCount: _totalFindingsRaised,
    );
    _phase = RtcSessionPhase.ended;
    _log(RtcSessionEventKind.sessionEnded, 'Session ended after ${_formatDuration(_summary!.durationMs)}');
    notifyListeners();
  }

  int _totalFindingsRaised = 0;

  Future<void> _cancelSubscriptions() async {
    await _connSub?.cancel();
    await _iceSub?.cancel();
    await _appRttSub?.cancel();
    _connSub = _iceSub = _appRttSub = null;
  }

  void _resetSessionState() {
    _timeline.clear();
    _diagnostics.reset();
    _events.clear();
    _totalFindingsRaised = 0;
    _previousSnapshot = null;
    _snapshot = null;
    _metrics = const RtcDerivedMetrics();
    _quality = const RtcQualityReport(level: RtcQualityLevel.unknown, assessments: []);
    _lastNotifiedLevel = RtcQualityLevel.unknown;
    _summary = null;
    _appRttMs = null;
    _videoTrackEnabled = true;
    _appliedBitrateCapKbps = null;
    _statsUnavailableLogged = false;
    _connectionState = RtcConnectionState.idle;
    _iceState = RtcIceState.idle;
  }

  // ---- Sample pipeline ----------------------------------------------------

  Future<void> _tick() async {
    final session = _session;
    final collector = _collector;
    if (session == null || collector == null || _phase != RtcSessionPhase.live) return;

    session.ping();

    final collected = await collector.collect();
    if (!collected.available) {
      if (!_statsUnavailableLogged) {
        _statsUnavailableLogged = true;
        _log(RtcSessionEventKind.error, 'Stats unavailable: ${collected.error}');
      }
      return;
    }
    _statsUnavailableLogged = false;

    final elapsed = DateTime.now().millisecondsSinceEpoch -
        (_sessionModel?.startedAt.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch);

    final snapshot = _normalizer.normalize(
      reports: collected.reports!,
      elapsedMs: elapsed < 0 ? 0 : elapsed,
      connectionState: _connectionState,
      iceState: _iceState,
    );
    _snapshot = snapshot;

    final metrics = _calculator.compute(current: snapshot, previous: _previousSnapshot);
    _metrics = metrics;
    _previousSnapshot = snapshot;

    final quality = _classifier.classify(metrics);
    _quality = quality;
    if (quality.level != _lastNotifiedLevel && quality.level != RtcQualityLevel.unknown) {
      _lastNotifiedLevel = quality.level;
      _log(RtcSessionEventKind.qualityChanged, 'Network quality: ${quality.level.name.toUpperCase()}');
    }

    final diagnostics = _diagnostics.evaluate(
      snapshot: snapshot,
      metrics: metrics,
      videoSending: hasVideoGrant && _videoTrackEnabled,
      elapsedMs: snapshot.elapsedMs,
    );
    for (final raised in diagnostics.raised) {
      _totalFindingsRaised++;
      _log(RtcSessionEventKind.findingRaised, 'Finding: ${raised.title} — ${raised.evidence}');
    }
    for (final cleared in diagnostics.cleared) {
      _log(RtcSessionEventKind.findingCleared, 'Resolved: ${cleared.title}');
    }

    _timeline.push(RtcTimelinePoint(
      elapsedMs: snapshot.elapsedMs,
      rttMs: metrics.rttMs,
      jitterMs: metrics.jitterMs,
      packetLossPercent: metrics.packetLossPercent,
      sendBitrateKbps: metrics.sendBitrateKbps,
      recvBitrateKbps: metrics.recvBitrateKbps,
      videoFps: metrics.videoFps,
      level: quality.level,
    ));

    notifyListeners();
  }

  // ---- Event sources -------------------------------------------------------

  void _onConnectionState(RtcConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    _log(RtcSessionEventKind.connectionState, 'Connection state: ${state.name}');
    notifyListeners();
  }

  void _onIceState(RtcIceState state) {
    if (_iceState == state) return;
    _iceState = state;
    _log(RtcSessionEventKind.iceState, 'ICE state: ${state.name}');
    notifyListeners();
  }

  void _log(RtcSessionEventKind kind, String message) {
    final started = _sessionModel?.startedAt;
    final now = DateTime.now();
    _events.add(RtcSessionEvent(
      wallClock: now,
      elapsedMs: started == null ? 0 : now.difference(started).inMilliseconds,
      kind: kind,
      message: message,
    ));
    if (_events.length > _maxEvents) {
      _events.removeRange(0, _events.length - _maxEvents);
    }
  }

  String _formatDuration(int ms) {
    final m = (ms ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ---- Degradation controls (Phase 17) --------------------------------------

  Future<void> setVideoTrackEnabled(bool enabled) async {
    final session = _session;
    if (session == null) return;
    session.setVideoEnabled(enabled);
    _videoTrackEnabled = enabled;
    _log(RtcSessionEventKind.degradationApplied,
        enabled ? 'Video track resumed' : 'Video track paused (real encoder stall)');
    notifyListeners();
  }

  Future<bool> applyBitrateCapKbps(int? kbps) async {
    final session = _session;
    if (session == null) return false;
    final ok = await session.applyMaxVideoBitrate(kbps == null ? null : kbps * 1000);
    _appliedBitrateCapKbps = ok ? kbps : null;
    _log(
      RtcSessionEventKind.degradationApplied,
      ok
          ? (kbps == null
              ? 'Encoder bitrate cap removed'
              : 'Encoder bitrate capped at $kbps kbps (real encoder behavior)')
          : 'Encoder bitrate cap rejected by platform',
    );
    notifyListeners();
    return ok;
  }

  Future<void> dropMirrorPeer() async {
    final session = _session;
    if (session == null) return;
    _log(RtcSessionEventKind.degradationApplied, 'Mirror peer dropped — probe should observe ICE failure');
    await session.dropMirrorPeer();
    notifyListeners();
  }

  Future<void> restart() async {
    await stop();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await start();
  }

  /// App lifecycle: stop sampling while invisible, resume when visible again.
  /// The session itself stays up — the OS suspends the process anyway.
  void handleAppLifecycle(bool visible) {
    if (visible) {
      if (_phase == RtcSessionPhase.live && _sampler?.isRunning != true) {
        _sampler?.start(_tick);
        _networkInfo.current().then((path) {
          if (path.interfaceType != _networkPath.interfaceType) {
            _networkPath = path;
            _log(RtcSessionEventKind.networkPathChanged, 'Network path changed: ${path.interfaceType}');
            notifyListeners();
          }
        });
      }
    } else {
      _sampler?.stop();
    }
  }

  @override
  void dispose() {
    _sampler?.stop();
    _cancelSubscriptions();
    _session?.close();
    super.dispose();
  }
}
