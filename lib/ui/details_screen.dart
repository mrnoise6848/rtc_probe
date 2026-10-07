import 'package:flutter/material.dart';
import 'package:rtc_probe/ui/format.dart';
import 'package:rtc_probe/ui/session_controller.dart';

class DetailsScreen extends StatelessWidget {
  const DetailsScreen({super.key, required this.controller});
  final SessionController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detailed metrics')),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = controller.snapshot;
        final m = controller.metrics;
        final rows = <(String, String)>[
          ('Connection', controller.connectionState.name),
          ('ICE', controller.iceState.name),
          (
            'Media capture',
            controller.sessionModel?.mediaGrant.name ?? 'Not available',
          ),
          ('RTT', msLabel(m.rttMs)),
          ('Data channel echo RTT (application)', msLabel(controller.appRttMs)),
          ('Jitter', msLabel(m.jitterMs)),
          ('Packet loss (interval)', percentLabel(m.packetLossPercent)),
          ('Send bitrate', kbpsLabel(m.sendBitrateKbps)),
          ('Receive bitrate', kbpsLabel(m.recvBitrateKbps)),
          ('Video FPS', fpsLabel(m.videoFps)),
          ('Send resolution', m.sendResolution ?? 'Not available'),
          ('DTLS', s?.transport?.dtlsState ?? 'Not available'),
          ('Candidate pair', s?.candidatePair?.state ?? 'Not available'),
          (
            'Local candidate type',
            s?.candidatePair?.localCandidateType ?? 'Not available',
          ),
          (
            'Remote candidate type',
            s?.candidatePair?.remoteCandidateType ?? 'Not available',
          ),
          (
            'Device network (not necessarily ICE path)',
            controller.networkPath.interfaceType,
          ),
          for (final stream in [
            s?.outboundAudio,
            s?.outboundVideo,
            s?.inboundAudio,
            s?.inboundVideo,
          ])
            if (stream != null) ...[
              (
                '${stream.direction} ${stream.kind} bytes',
                bytesLabel(stream.bytes),
              ),
              (
                '${stream.direction} ${stream.kind} packets',
                countLabel(stream.packets),
              ),
              (
                '${stream.direction} ${stream.kind} packets lost',
                countLabel(stream.packetsLost),
              ),
              (
                '${stream.direction} ${stream.kind} frames',
                countLabel(stream.frames),
              ),
              (
                '${stream.direction} ${stream.kind} frames dropped',
                countLabel(stream.framesDropped),
              ),
            ],
        ];
        return ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Live WebRTC reports. Unreported values stay unavailable. Local loopback does not measure Internet quality.',
              ),
            ),
            for (final row in rows)
              ListTile(
                title: Text(row.$1),
                subtitle: Text(row.$2 == '—' ? 'Not available' : row.$2),
              ),
          ],
        );
      },
    ),
  );
}
