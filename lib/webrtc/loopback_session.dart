import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:rtc_probe/rtc/models.dart';
import 'package:rtc_probe/webrtc/probe_peer.dart';

/// Deterministic in-process signaling for the showcase session.
///
/// SDP offers/answers and trickled ICE candidates are exchanged through direct
/// Dart calls between two peer connections living in the same process
/// (`probe` sends real media to `mirror`, `mirror` echoes it back). The full
/// ICE/DTLS/SRTP stack still executes on the device network stack, so all
/// collected statistics are real — there is simply no external signaling
/// server to operate or fail (see docs/decisions/002-webrtc-library-choice.md).
class LoopbackSignaling {
  const LoopbackSignaling();

  /// Pipes candidates bidirectionally and performs the offer/answer exchange.
  Future<void> connect(ProbePeer a, ProbePeer b) async {
    a.pc.onIceCandidate = (candidate) => b.addRemoteCandidate(candidate);
    b.pc.onIceCandidate = (candidate) => a.addRemoteCandidate(candidate);

    final offer = await a.pc.createOffer(null);
    await a.pc.setLocalDescription(offer);
    await b.setRemoteDescriptionSafely(offer);

    final answer = await b.pc.createAnswer(null);
    await b.pc.setLocalDescription(answer);
    await a.setRemoteDescriptionSafely(answer);
  }
}

/// The showcase WebRTC session: a local probe peer connected to a local mirror
/// peer, optionally sending real captured audio/video, plus a data channel
/// used for application-level RTT measurement (ping/echo).
class LoopbackRtcSession {
  LoopbackRtcSession._(this._probe, this._mirror, this._media) {
    _startedAt = DateTime.now();
  }

  final ProbePeer _probe;
  final ProbePeer _mirror;
  final MediaStream? _media;
  final LoopbackSignaling _signaling = const LoopbackSignaling();
  final _appRttController = StreamController<double?>.broadcast();

  RTCDataChannel? _channel;
  DateTime? _startedAt;
  bool _closed = false;
  bool _mirrorGone = false;
  int _pingSeq = 0;

  /// Application-level RTT measured over the data channel (echo), in ms.
  Stream<double?> get appRttMs => _appRttController.stream;

  Stream<RtcConnectionState> get connectionStates => _probe.connectionStates;
  Stream<RtcIceState> get iceStates => _probe.iceStates;

  RtcConnectionState get connectionState => _probe.connectionState;
  RtcIceState get iceState => _probe.iceState;
  MediaStream? get media => _media;
  RTCDataChannel? get channel => _channel;
  DateTime? get startedAt => _startedAt;
  bool get isClosed => _closed;

  /// Creates both peers, negotiates over [LoopbackSignaling] and returns the
  /// live session. [media] may be null (permission denied → data-channel-only
  /// session; ICE/DTLS remain real).
  static Future<LoopbackRtcSession> start({MediaStream? media}) async {
    ProbePeer? probe;
    ProbePeer? mirror;
    LoopbackRtcSession? session;
    try {
      probe = await ProbePeer.create('probe');
      mirror = await ProbePeer.create('mirror');
      session = LoopbackRtcSession._(probe, mirror, media);
      await session._setup().timeout(const Duration(seconds: 20));
      return session;
    } catch (_) {
      if (session != null) {
        await session.close();
      } else {
        await mirror?.close();
        await probe?.close();
        for (final track in media?.getTracks() ?? <MediaStreamTrack>[]) { await track.stop(); }
        await media?.dispose();
      }
      rethrow;
    }
  }

  Future<void> _setup() async {
    if (_media != null) {
      for (final track in _media!.getTracks()) {
        // Same captured tracks on both peers → real bidirectional RTP with
        // outbound and inbound statistics on the probe side.
        await _probe.pc.addTrack(track, _media!);
        await _mirror.pc.addTrack(track, _media!);
      }
    }

    _channel = await _probe.pc.createDataChannel('probe-ctl', RTCDataChannelInit());
    _channel!.onMessage = (message) {
      if (!message.isBinary && message.text.startsWith('ping ')) {
        final parts = message.text.split(' ');
        if (parts.length == 3) {
          final sentAt = int.tryParse(parts[2]);
          if (sentAt != null) {
            final rtt = DateTime.now().millisecondsSinceEpoch - sentAt;
            if (!_closed) _appRttController.add(rtt.toDouble());
          }
        }
      }
    };

    // The mirror echoes every control message verbatim; the probe interprets
    // echoed pings above to derive an application-level round-trip time.
    _mirror.pc.onDataChannel = (channel) {
      channel.onMessage = (message) {
        if (!message.isBinary) channel.send(RTCDataChannelMessage(message.text));
      };
    };

    await _signaling.connect(_probe, _mirror);
  }

  /// Sends one ping if the data channel is open. The echoed reply surfaces on
  /// [appRttMs]. Cheap enough to call once per sampling tick.
  void ping() {
    final channel = _channel;
    if (channel == null || channel.readyState != RTCDataChannelState.RTCDataChannelStateOpen) {
      return;
    }
    if (_closed) return;
    _pingSeq++;
    final now = DateTime.now().millisecondsSinceEpoch;
    channel.send(RTCDataChannelMessage('ping $_pingSeq $now'));
  }

  /// Pulls the raw statistics report list from the probe peer.
  Future<List<StatsReport>> collectStats() => _probe.pc.getStats();

  /// Enables/disables all local video tracks (track.enabled=false stops
  /// sending frames — a real media pause, not a fake metric).
  void setVideoEnabled(bool enabled) {
    _media?.getTracks().where((t) => t.kind == 'video').forEach((t) => t.enabled = enabled);
  }

  /// Caps the outbound video encoder bitrate via RTP sender parameters.
  /// Returns false when the platform rejected the parameters.
  Future<bool> applyMaxVideoBitrate(int? bitsPerSecond) async {
    var applied = false;
    for (final sender in await _probe.pc.getSenders()) {
      if (sender.track?.kind != 'video') continue;
      try {
        final params = sender.parameters;
        final encodings = params.encodings;
        if (encodings == null || encodings.isEmpty) continue;
        for (final encoding in encodings) {
          encoding.maxBitrate = bitsPerSecond;
        }
        applied = await sender.setParameters(params) || applied;
      } catch (_) {
        // Sender parameters may be rejected on some platforms; keep going.
      }
    }
    return applied;
  }

  /// Closes only the mirror peer. The probe observes a real ICE
  /// disconnect/failure — used for controlled failure demonstration.
  Future<void> dropMirrorPeer() async {
    if (_mirrorGone) return;
    _mirrorGone = true;
    await _mirror.close();
  }

  /// Full teardown: data channel, media tracks, stream, both peers.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _channel?.close();
    } catch (_) {}
    try {
      for (final track in _media?.getTracks() ?? <MediaStreamTrack>[]) { await track.stop(); }
      await _media?.dispose();
    } catch (_) {}
    if (!_mirrorGone) await _mirror.close();
    await _probe.close();
    await _appRttController.close();
  }
}
