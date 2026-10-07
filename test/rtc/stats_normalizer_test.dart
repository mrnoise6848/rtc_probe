import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtc_probe/rtc/models.dart';
import 'package:rtc_probe/webrtc/stats_normalizer.dart';

StatsReport _report(String id, String type, Map<String, dynamic> values) {
  return StatsReport(id, type, 0, values);
}

void main() {
  const normalizer = RtcStatsNormalizer();

  test('maps a realistic stats report set into a normalized snapshot', () {
    final reports = [
      _report('T1', 'transport', {
        'dtlsState': 'connected',
        'selectedCandidatePairId': 'P1',
      }),
      _report('P1', 'candidate-pair', {
        'state': 'succeeded',
        'nominated': true,
        'localCandidateId': 'L1',
        'remoteCandidateId': 'R1',
        'currentRoundTripTime': 0.048, // seconds
        'availableOutgoingBitrate': 2500000,
      }),
      _report('L1', 'local-candidate', {'candidateType': 'host'}),
      _report('R1', 'remote-candidate', {'candidateType': 'host'}),
      _report('OA1', 'outbound-rtp', {
        'kind': 'audio',
        'ssrc': 1111,
        'bytesSent': 123456,
        'packetsSent': 1200,
      }),
      _report('OV1', 'outbound-rtp', {
        'kind': 'video',
        'ssrc': 2222,
        'bytesSent': 9876543,
        'packetsSent': 900,
        'framesEncoded': 850,
        'framesPerSecond': 28.5,
        'frameWidth': 1280,
        'frameHeight': 720,
        'targetBitrate': 1800000,
      }),
      _report('RIOV1', 'remote-inbound-rtp', {
        'kind': 'video',
        'ssrc': 2222,
        'roundTripTime': 0.052,
        'fractionLost': 0.004,
      }),
      _report('IA1', 'inbound-rtp', {
        'kind': 'audio',
        'ssrc': 1111,
        'bytesReceived': 123000,
        'packetsReceived': 1195,
        'packetsLost': 5,
        'jitter': 0.0073, // seconds
      }),
      _report('IV1', 'inbound-rtp', {
        'kind': 'video',
        'ssrc': 2222,
        'bytesReceived': 9870000,
        'packetsReceived': 880,
        'packetsLost': 20,
        'framesDecoded': 840,
        'framesDropped': 3,
      }),
      _report('DC1', 'data-channel', {
        'label': 'probe-ctl',
        'bytesSent': 400,
        'bytesReceived': 400,
        'messagesSent': 10,
        'messagesReceived': 10,
      }),
    ];

    final snapshot = normalizer.normalize(
      reports: reports,
      elapsedMs: 5000,
      connectionState: RtcConnectionState.connected,
      iceState: RtcIceState.connected,
    );

    expect(snapshot.connectionState, RtcConnectionState.connected);
    expect(snapshot.transport?.dtlsState, 'connected');
    expect(snapshot.candidatePair?.localCandidateType, 'host');
    expect(snapshot.candidatePair?.currentRttMs, closeTo(48, 0.001));
    expect(snapshot.candidatePair?.availableOutgoingBitbps, 2500000);

    expect(snapshot.outboundAudio?.packets, 1200);
    expect(snapshot.outboundVideo?.framesPerSecond, 28.5);
    expect(snapshot.outboundVideo?.roundTripTimeMs, closeTo(52, 0.001));
    expect(snapshot.outboundVideo?.fractionLost, closeTo(0.004, 0.000001));

    expect(snapshot.inboundAudio?.packetsLost, 5);
    expect(snapshot.inboundAudio?.jitterMs, closeTo(7.3, 0.001));
    expect(snapshot.inboundVideo?.framesDropped, 3);

    expect(snapshot.dataChannel?.messagesSent, 10);
  });

  test('missing reports stay null — nothing is fabricated', () {
    final snapshot = normalizer.normalize(
      reports: [],
      elapsedMs: 1000,
      connectionState: RtcConnectionState.connected,
      iceState: RtcIceState.checking,
    );

    expect(snapshot.candidatePair, isNull);
    expect(snapshot.transport, isNull);
    expect(snapshot.outboundAudio, isNull);
    expect(snapshot.outboundVideo, isNull);
    expect(snapshot.inboundAudio, isNull);
    expect(snapshot.inboundVideo, isNull);
    expect(snapshot.dataChannel, isNull);
  });

  test('numeric strings are accepted for cross-platform codec differences', () {
    final reports = [
      _report('OA1', 'outbound-rtp', {
        'kind': 'audio',
        'ssrc': '1111',
        'bytesSent': '123456',
        'packetsSent': '1200',
      }),
    ];
    final snapshot = normalizer.normalize(
      reports: reports,
      elapsedMs: 500,
      connectionState: RtcConnectionState.connected,
      iceState: RtcIceState.connected,
    );
    expect(snapshot.outboundAudio?.ssrc, 1111);
    expect(snapshot.outboundAudio?.bytes, 123456);
    expect(snapshot.outboundAudio?.packets, 1200);
  });
}
