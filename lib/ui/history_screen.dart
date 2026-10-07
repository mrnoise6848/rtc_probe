import 'package:flutter/material.dart';
import 'package:rtc_probe/ui/format.dart';
import 'package:rtc_probe/ui/session_controller.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.controller});
  final SessionController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Metric history • last 10 minutes')),
    body: ListenableBuilder(listenable: controller, builder: (context, _) {
      final points = controller.historyPoints.reversed.toList(growable: false);
      if (points.isEmpty) return const Center(child: Text('No samples collected yet.'));
      String show(String value) => value == '—' ? 'Not available' : value;
      return ListView.builder(itemCount: points.length, itemBuilder: (context, index) {
        final p = points[index];
        return ExpansionTile(title: Text('+${durationLabel(p.elapsedMs)} • ${p.level.name}'), children: [
          for (final row in <(String, String)>[
            ('RTT', msLabel(p.rttMs)), ('Jitter', msLabel(p.jitterMs)),
            ('Packet loss', percentLabel(p.packetLossPercent)),
            ('Send bitrate', kbpsLabel(p.sendBitrateKbps)),
            ('Receive bitrate', kbpsLabel(p.recvBitrateKbps)), ('Video FPS', fpsLabel(p.videoFps)),
          ]) ListTile(title: Text(row.$1), subtitle: Text(show(row.$2))),
        ]);
      });
    }),
  );
}
