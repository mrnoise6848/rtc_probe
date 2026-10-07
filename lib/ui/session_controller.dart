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
    this.captureRequested = true,
    NetworkInfoService? networkInfoService,
  }) : _networkInfo = networkInfoService ?? const NetworkInfoService();

  final Duration samplingInterval;
  bool captureRequested;

  void setCaptureRequested(bool requested) {
    if (isLive) return;
    captureRequested = requested;
    notifyListeners();
  }

  final NetworkInfoService _networkInfo;

  // Pipeline components (pure Dart, stateless except engine/timeline).
  final RtcStatsNormalizer _normalizer = const RtcStatsNormalizer();
  final RtcMetricsCalculator _calculator = const RtcMetricsCalculator();
  final RtcQualityClassifier _classifier = const RtcQualityClassifier();
  final RtcDiagnosticEngine _diagnostics = RtcDiagnosticEngine();

  bool _disposed = false;
  bool _visible = true;
  int _generation = 0;
  Future<void>? _starting;
  Future<void>? _stopping;
  final Stopwatch _clock = Stopwatch();

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  LoopbackRtcSession? _session;
  RtcStatsCollector? _collector;
  RtcSampler? _sampler;
  StreamSubscription? _connSub;
  StreamSubscription? _iceSub;
  StreamSubscription? _appRttSub;
  RtcStatsSnapshot? _previousSnapshot;

  final RtcTimeline _timeline = RtcTimeline();
  RtcSummaryAccumulator _aggregates = RtcSummaryAccumulator();
  final List<RtcSessionEvent> _events = <RtcSessionEvent>[];
  static const int _maxEvents = 200;

  // ---- Observable state -------------------------------------------------
  RtcSessionPhase _phase = RtcSessionPhase.idle;
  RtcConnectionState _connectionState = RtcConnectionState.idle;
  RtcIceState _iceState = RtcIceState.idle;
  RtcSession? _sessionModel;
  RtcStatsSnapshot? _snapshot;
  RtcDerivedMetrics _metrics = const RtcDerivedMetrics();
  RtcQualityReport _quality = const RtcQualityReport(
    level: RtcQualityLevel.unknown,
    assessments: [],
  );
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
  bool get isLive =>
      _phase == RtcSessionPhase.live || _phase == RtcSessionPhase.starting;
  bool get videoTrackEnabled => _videoTrackEnabled;
  int? get appliedBitrateCapKbps => _appliedBitrateCapKbps;
  bool get hasVideoGrant =>
      _sessionModel?.mediaGrant == RtcMediaGrant.audioVideo;
  List<RtcFinding> get findings => _diagnostics.activeFindings;
  List<RtcTimelinePoint> get timelinePoints => _timeline.trailing(60000);
  List<RtcTimelinePoint> get historyPoints => _timeline.points;
  List<RtcSessionEvent> get events => List.unmodifiable(_events);

  // ---- Session lifecycle -------------------------------------------------

  Future<void> start() async {
    if (_disposed || !_visible || isLive || _stopping != null) return;
    final pending = _start(++_generation);
    _starting = pending;
    try {
      await pending;
    } finally {
      if (identical(_starting, pending)) _starting = null;
    }
  }

  bool _valid(int generation) => !_disposed && generation == _generation;

  Future<void> _start(int generation) async {
    _phase = RtcSessionPhase.starting;
    _resetSessionState();
    _log(
      RtcSessionEventKind.sessionStarted,
      'Session starting (${RtcSession.signalingMode})',
    );
    notifyListeners();

    await _networkInfo.setProbeActive(true);
    if (!_valid(generation)) return;
    _networkPath = await _networkInfo.current();
    if (!_valid(generation)) return;
    _log(
      RtcSessionEventKind.networkPathChanged,
      'Network path: ${_networkPath.interfaceType}'
      '${_networkPath.isExpensive ? " (expensive)" : ""}'
      '${_networkPath.isConstrained ? " (constrained)" : ""}',
    );

    // Contextual permission request with graceful degradation.
    final access = captureRequested
        ? await const MediaAccess().acquire()
        : const MediaAccessResult(
            stream: null,
            grant: RtcMediaGrant.none,
            deniedKinds: [],
          );
    if (!_valid(generation)) {
      await releaseMedia(access.stream);
      return;
    }
    if (access.deniedKinds.isNotEmpty) {
      _totalFindingsRaised++;
      _log(
        RtcSessionEventKind.mediaDenied,
        'Capture unavailable: ${access.deniedKinds.join(", ")} — using ${access.grant.name}',
      );
      _diagnostics.raiseManual(
        RtcFinding(
          code: RtcFindingCode.mediaUnavailable,
          severity: RtcSeverity.info,
          title: 'Media unavailable',
          evidence:
              'Capture failed or permission denied for ${access.deniedKinds.join(", ")}.',
          impact: 'Media metrics will report "Not available"; transport diagnostics remain valid.',
          firstDetectedMs: 0,
        ),
      );
    }

    try {
      final session = await LoopbackRtcSession.start(media: access.stream);
      if (!_valid(generation)) {
        await session.close();
        return;
      }
      _session = session;
    } catch (_) {
      if (!_valid(generation)) return;
      await _networkInfo.setProbeActive(false);
      _phase = RtcSessionPhase.failed;
      _log(
        RtcSessionEventKind.error,
        'WebRTC initialization failed. Try a fresh session.',
      );
      notifyListeners();
      return;
    }

    _sessionModel = RtcSession(
      id: 'probe-${DateTime.now().millisecondsSinceEpoch}',
      startedAt: _session!.startedAt!,
      mediaGrant: access.grant,
    );

    _clock.start();
    _onConnectionState(_session!.connectionState);
    _onIceState(_session!.iceState);
    _collector = RtcStatsCollector(_session!);
    _connSub = _session!.connectionStates.listen(_onConnectionState);
    _iceSub = _session!.iceStates.listen(_onIceState);
    _appRttSub = _session!.appRttMs.listen((rtt) {
      _appRttMs = rtt;
      // No notifyListeners: surfaced with the next sample tick.
    });

    _phase = RtcSessionPhase.live;
    _videoTrackEnabled = true;
    _log(
      RtcSessionEventKind.sessionStarted,
      'Session live — media grant: ${access.grant.name}',
    );
    notifyListeners();

    _sampler = RtcSampler(interval: samplingInterval)..start(_tick);
  }

  Future<void> stop() async {
    if (_stopping != null) {
      await _stopping;
      return;
    }
    final pending = _stop();
    _stopping = pending;
    try {
      await pending;
    } finally {
      _stopping = null;
    }
  }

  Future<void> _stop() async {
    if (_phase != RtcSessionPhase.live && _phase != RtcSessionPhase.starting) {
      return;
    }
    ++_generation;
    _phase = RtcSessionPhase.ended;
    _clock.stop();
    _sampler?.stop();
    _sampler = null;
    await _starting;
    await _networkInfo.setProbeActive(false);
    await _cancelSubscriptions();
    final session = _session;
    _session = null;
    _collector = null;

    if (_sessionModel != null) {
      _sessionModel!.endedAt = DateTime.now();
    }
    await session?.close();

    _summary = _aggregates.finish(
      startedAt: _sessionModel?.startedAt ?? DateTime.now(),
      durationMs: _clock.elapsedMilliseconds,
      findingsCount: _totalFindingsRaised,
    );
    _phase = RtcSessionPhase.ended;
    _log(
      RtcSessionEventKind.sessionEnded,
      'Session ended after ${_formatDuration(_summary!.durationMs)}',
    );
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
    _clock.reset();
    _sessionModel = null;
    _timeline.clear();
    _aggregates = RtcSummaryAccumulator();
    _diagnostics.reset();
    _events.clear();
    _totalFindingsRaised = 0;
    _previousSnapshot = null;
    _snapshot = null;
    _metrics = const RtcDerivedMetrics();
    _quality = const RtcQualityReport(
      level: RtcQualityLevel.unknown,
      assessments: [],
    );
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
    if (session == null ||
        collector == null ||
        _phase != RtcSessionPhase.live) {
      return;
    }

    _appRttMs = null;
    session.ping();

    final collected = await collector.collect();
    if (!identical(session, _session) || _phase != RtcSessionPhase.live) return;
    if (!collected.available) {
      _snapshot = null;
      _previousSnapshot = null;
      _metrics = const RtcDerivedMetrics();
      _quality = const RtcQualityReport(
        level: RtcQualityLevel.unknown,
        assessments: [],
      );
      if (!_statsUnavailableLogged) {
        _statsUnavailableLogged = true;
        _log(
          RtcSessionEventKind.error,
          'Stats unavailable: ${collected.error}',
        );
      }
      notifyListeners();
      return;
    }
    _statsUnavailableLogged = false;

    final elapsed = _clock.elapsedMilliseconds;

    final snapshot = _normalizer.normalize(
      reports: collected.reports!,
      elapsedMs: elapsed < 0 ? 0 : elapsed,
      connectionState: _connectionState,
      iceState: _iceState,
    );
    _snapshot = snapshot;

    final metrics = _connectionState == RtcConnectionState.connected
        ? _calculator.compute(current: snapshot, previous: _previousSnapshot)
        : const RtcDerivedMetrics();
    _metrics = metrics;
    _previousSnapshot = snapshot;

    final quality =
        _connectionState == RtcConnectionState.disconnected ||
            _connectionState == RtcConnectionState.failed
        ? RtcQualityReport(
            level: RtcQualityLevel.critical,
            assessments: [
              RtcMetricAssessment(
                metricId: 'connection',
                level: RtcQualityLevel.critical,
                evidence: 'Native connection state: ${_connectionState.name}',
              ),
            ],
          )
        : _classifier.classify(metrics);
    _quality = quality;
    if (quality.level != _lastNotifiedLevel &&
        quality.level != RtcQualityLevel.unknown) {
      _lastNotifiedLevel = quality.level;
      _log(
        RtcSessionEventKind.qualityChanged,
        'Network quality: ${quality.level.name.toUpperCase()}',
      );
    }

    final diagnostics = _diagnostics.evaluate(
      snapshot: snapshot,
      metrics: metrics,
      videoSending: hasVideoGrant && _videoTrackEnabled,
      elapsedMs: snapshot.elapsedMs,
    );
    for (final raised in diagnostics.raised) {
      _totalFindingsRaised++;
      _log(
        RtcSessionEventKind.findingRaised,
        'Finding: ${raised.title} — ${raised.evidence}',
      );
    }
    for (final cleared in diagnostics.cleared) {
      _log(RtcSessionEventKind.findingCleared, 'Resolved: ${cleared.title}');
    }

    final point = RtcTimelinePoint(
      elapsedMs: snapshot.elapsedMs,
      rttMs: metrics.rttMs,
      jitterMs: metrics.jitterMs,
      packetLossPercent: metrics.packetLossPercent,
      sendBitrateKbps: metrics.sendBitrateKbps,
      recvBitrateKbps: metrics.recvBitrateKbps,
      videoFps: metrics.videoFps,
      level: quality.level,
    );
    _timeline.push(point);
    _aggregates.add(point);

    notifyListeners();
  }

  // ---- Event sources -------------------------------------------------------

  void _onConnectionState(RtcConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    _log(
      RtcSessionEventKind.connectionState,
      'Connection state: ${state.name}',
    );
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
    _events.add(
      RtcSessionEvent(
        wallClock: now,
        elapsedMs: started == null ? 0 : _clock.elapsedMilliseconds,
        kind: kind,
        message: message,
      ),
    );
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
    _log(
      RtcSessionEventKind.degradationApplied,
      enabled
          ? 'Video track resumed'
          : 'Video track paused (platform may send black frames)',
    );
    notifyListeners();
  }

  Future<bool> applyBitrateCapKbps(int? kbps) async {
    final session = _session;
    if (session == null) return false;
    final ok = await session.applyMaxVideoBitrate(
      kbps == null ? null : kbps * 1000,
    );
    if (_disposed || !identical(session, _session) || !isLive) return false;
    if (ok) _appliedBitrateCapKbps = kbps;
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
    _log(
      RtcSessionEventKind.degradationApplied,
      'Mirror peer dropped — probe should observe ICE failure',
    );
    await session.dropMirrorPeer();
    notifyListeners();
  }

  Future<void> restart() async {
    await stop();
    await start();
  }

  /// Background ends the session, releasing native capture and connections.
  void handleAppLifecycle(bool visible) {
    _visible = visible;
    if (!visible) unawaited(stop());
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
