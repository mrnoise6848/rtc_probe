import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:rtc_probe/rtc/models.dart';

/// Wraps one `RTCPeerConnection` and normalizes its state into domain enums.
///
/// Remote ICE candidates are buffered until the remote description is set —
/// the plugin does not queue them itself and adding too early throws.
class ProbePeer {
  ProbePeer._(this.name, this._pc);

  final String name;
  final RTCPeerConnection _pc;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  bool _remoteDescriptionSet = false;
  bool _closed = false;

  final StreamController<RtcConnectionState> _connectionStates =
      StreamController<RtcConnectionState>.broadcast();
  final StreamController<RtcIceState> _iceStates =
      StreamController<RtcIceState>.broadcast();

  /// Domain-normalized peer connection state changes.
  Stream<RtcConnectionState> get connectionStates => _connectionStates.stream;

  /// Domain-normalized ICE connection state changes.
  Stream<RtcIceState> get iceStates => _iceStates.stream;

  /// Raw plugin peer connection (used by the stats collector and signaling).
  RTCPeerConnection get pc => _pc;

  static Future<ProbePeer> create(String name) async {
    // Fully local topology: no STUN/TURN. The probe ↔ mirror session never
    // leaves the device, so host candidates are sufficient and no third-party
    // server is contacted (see docs/decisions/002-webrtc-library-choice.md).
    const config = <String, dynamic>{
      'iceServers': <String, dynamic>[],
      'sdpSemantics': 'unified-plan',
    };
    final pc = await createPeerConnection(config);
    final peer = ProbePeer._(name, pc);
    pc.onConnectionState = (s) {
      if (!peer._closed) peer._connectionStates.add(mapConnectionState(s));
    };
    pc.onIceConnectionState = (s) {
      if (!peer._closed) peer._iceStates.add(mapIceState(s));
    };
    return peer;
  }

  Future<void> setRemoteDescriptionSafely(RTCSessionDescription description) async {
    await _pc.setRemoteDescription(description);
    _remoteDescriptionSet = true;
    for (final candidate in _pendingRemoteCandidates) {
      await _pc.addCandidate(candidate);
    }
    _pendingRemoteCandidates.clear();
  }

  Future<void> addRemoteCandidate(RTCIceCandidate candidate) async {
    if (_remoteDescriptionSet) {
      await _pc.addCandidate(candidate);
    } else {
      _pendingRemoteCandidates.add(candidate);
    }
  }

  /// Closes and disposes the peer connection. Safe to call more than once.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _pc.close();
    } catch (_) {
      // The peer may already be gone after a transport failure — cleanup must
      // never mask the original session error.
    }
    try {
      await _pc.dispose();
    } catch (_) {}
    await _connectionStates.close();
    await _iceStates.close();
  }
}

RtcConnectionState mapConnectionState(RTCPeerConnectionState state) {
  switch (state) {
    case RTCPeerConnectionState.RTCPeerConnectionStateNew:
      return RtcConnectionState.idle;
    case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
      return RtcConnectionState.connecting;
    case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
      return RtcConnectionState.connected;
    case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
      return RtcConnectionState.disconnected;
    case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
      return RtcConnectionState.failed;
    case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
      return RtcConnectionState.closed;
  }
}

RtcIceState mapIceState(RTCIceConnectionState state) {
  switch (state) {
    case RTCIceConnectionState.RTCIceConnectionStateNew:
      return RtcIceState.idle;
    case RTCIceConnectionState.RTCIceConnectionStateChecking:
      return RtcIceState.checking;
    case RTCIceConnectionState.RTCIceConnectionStateConnected:
      return RtcIceState.connected;
    case RTCIceConnectionState.RTCIceConnectionStateCompleted:
      return RtcIceState.completed;
    case RTCIceConnectionState.RTCIceConnectionStateFailed:
      return RtcIceState.failed;
    case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
      return RtcIceState.disconnected;
    case RTCIceConnectionState.RTCIceConnectionStateClosed:
      return RtcIceState.closed;
    case RTCIceConnectionState.RTCIceConnectionStateCount:
      return RtcIceState.idle; // sentinel value, never surfaced on events
  }
}
