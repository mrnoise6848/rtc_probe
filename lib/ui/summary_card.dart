import 'package:flutter/material.dart';
import 'package:rtc_probe/rtc/models.dart';
import 'package:rtc_probe/ui/format.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.summary});
  final RtcSessionSummary summary;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Session summary', style: Theme.of(context).textTheme.titleLarge),
      for (final row in <(String, String)>[
        ('Duration', durationLabel(summary.durationMs)),
        ('Collected samples', '${summary.sampleCount}'),
        ('Average RTT', msLabel(summary.avgRttMs)),
        ('Peak RTT', msLabel(summary.peakRttMs)),
        ('Peak jitter', msLabel(summary.peakJitterMs)),
        ('Mean interval packet loss', percentLabel(summary.avgLossPercent)),
        ('Peak interval packet loss', percentLabel(summary.peakLossPercent)),
        ('Average send bitrate', kbpsLabel(summary.avgSendKbps)),
        ('Average receive bitrate', kbpsLabel(summary.avgRecvKbps)),
        ('Worst measured quality', summary.worstLevel.name),
        ('Findings raised', '${summary.findingsCount}'),
      ]) ListTile(contentPadding: EdgeInsets.zero, title: Text(row.$1), subtitle: Text(row.$2 == '—' ? 'Not available' : row.$2)),
    ],
  )));
}
