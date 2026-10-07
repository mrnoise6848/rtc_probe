import 'package:flutter/material.dart';
import 'package:rtc_probe/rtc/models.dart';
import 'package:rtc_probe/ui/format.dart';
import 'package:rtc_probe/ui/details_screen.dart';
import 'package:rtc_probe/ui/session_controller.dart';
import 'package:rtc_probe/ui/sparkline.dart';

/// Main RTCProbe dashboard: connection state, quality, headline metrics,
/// the bounded timeline, current findings and the local preview.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final SessionController _controller = SessionController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.handleAppLifecycle(
      state == AppLifecycleState.resumed || state == AppLifecycleState.inactive,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('RTCProbe'),
            actions: [
              IconButton(tooltip: 'Detailed metrics', icon: const Icon(Icons.analytics_outlined), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DetailsScreen(controller: _controller)))),
              _NetworkChip(controller: _controller),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: _controller.phase == RtcSessionPhase.idle || _controller.phase == RtcSessionPhase.ended
                ? _IdleView(controller: _controller)
                : _LiveView(controller: _controller),
          ),
          bottomNavigationBar: _BottomControls(controller: _controller),
        );
      },
    );
  }
}

class _NetworkChip extends StatelessWidget {
  const _NetworkChip({required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final path = controller.networkPath;
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (path.interfaceType) {
      'wifi' => Icons.wifi,
      'cellular' => Icons.cellular,
      'ethernet' => Icons.lan,
      'none' => Icons.signal_wifi_off,
      _ => Icons.help_outline,
    };
    return Semantics(
      label: 'Network path: ${path.interfaceType}',
      child: Chip(
        avatar: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        label: Text(path.interfaceType),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Why is a realtime connection performing badly?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'RTCProbe establishes a real WebRTC loopback session on this device '
          '(local probe ↔ mirror peer, no server), samples live statistics and '
          'explains degradation.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: controller.isLive ? null : controller.start,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start probe session'),
        ),
      ],
    );
  }
}

class _LiveView extends StatelessWidget {
  const _LiveView({required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _StatusHeader(controller: controller),
        const SizedBox(height: 12),
        _MetricGrid(controller: controller),
        const SizedBox(height: 12),
        _TimelineCard(controller: controller),
        const SizedBox(height: 12),
        _FindingsCard(controller: controller),
      ],
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final quality = controller.quality.level;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Connection', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 12, color: _stateColor(controller, scheme)),
                      const SizedBox(width: 6),
                      Text(
                        controller.phase == RtcSessionPhase.starting
                            ? 'Connecting…'
                            : controller.connectionState.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ICE: ${controller.iceState.name}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Quality', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    quality == RtcQualityLevel.unknown ? '—' : quality.name.toUpperCase(),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: qualityColor(quality, scheme), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _stateColor(SessionController controller, ColorScheme scheme) {
    switch (controller.connectionState) {
      case RtcConnectionState.connected:
        return const Color(0xFF43A047);
      case RtcConnectionState.connecting:
        return const Color(0xFFF9A825);
      case RtcConnectionState.failed:
        return const Color(0xFFC62828);
      case RtcConnectionState.disconnected:
        return const Color(0xFFEF6C00);
      default:
        return scheme.outlineVariant;
    }
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final m = controller.metrics;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _MetricCard(label: 'RTT', value: msLabel(m.rttMs))),
            const SizedBox(width: 8),
            Expanded(child: _MetricCard(label: 'Jitter', value: msLabel(m.jitterMs))),
            const SizedBox(width: 8),
            Expanded(child: _MetricCard(label: 'Packet Loss', value: percentLabel(m.packetLossPercent))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _MetricCard(label: 'Send Bitrate', value: kbpsLabel(m.sendBitrateKbps))),
            const SizedBox(width: 8),
            Expanded(child: _MetricCard(label: 'Recv Bitrate', value: kbpsLabel(m.recvBitrateKbps))),
            const SizedBox(width: 8),
            Expanded(child: _MetricCard(label: 'Video FPS', value: fpsLabel(m.videoFps))),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unavailable = value == '—';
    return Semantics(
      label: '$label: ${unavailable ? 'Not available' : value}',
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                unavailable ? 'N/A' : value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: unavailable ? scheme.outline : null,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineCard extends StatefulWidget {
  const _TimelineCard({required this.controller});

  final SessionController controller;

  @override
  State<_TimelineCard> createState() => _TimelineCardState();
}

enum _TimelineMetric { rtt, jitter, loss, sendBitrate }

class _TimelineCardState extends State<_TimelineCard> {
  _TimelineMetric _selected = _TimelineMetric.rtt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final points = widget.controller.timelinePoints;
    final label = switch (_selected) {
      _TimelineMetric.rtt => 'RTT (ms)',
      _TimelineMetric.jitter => 'Jitter (ms)',
      _TimelineMetric.loss => 'Packet loss (%)',
      _TimelineMetric.sendBitrate => 'Send bitrate (kbps)',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timeline — last 60 s', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            MetricSparkline(
              series: points,
              color: scheme.primary,
              value: switch (_selected) {
                _TimelineMetric.rtt => (p) => p.rttMs,
                _TimelineMetric.jitter => (p) => p.jitterMs,
                _TimelineMetric.loss => (p) => p.packetLossPercent,
                _TimelineMetric.sendBitrate => (p) => p.sendBitrateKbps,
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final metric in _TimelineMetric.values)
                  ChoiceChip(
                    label: Text(switch (metric) {
                      _TimelineMetric.rtt => 'RTT',
                      _TimelineMetric.jitter => 'Jitter',
                      _TimelineMetric.loss => 'Loss',
                      _TimelineMetric.sendBitrate => 'Bitrate',
                    }),
                    selected: _selected == metric,
                    onSelected: (_) => setState(() => _selected = metric),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FindingsCard extends StatelessWidget {
  const _FindingsCard({required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final findings = controller.findings;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Findings', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (findings.isEmpty)
              Text(
                'No findings — no degradation pattern detected.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              )
            else
              for (final finding in findings)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    finding.severity == RtcSeverity.critical ? Icons.error_outline : Icons.warning_amber,
                    color: severityColor(finding.severity, scheme),
                  ),
                  title: Text(finding.title),
                  subtitle: Text('${finding.evidence}\n${finding.impact}'),
                  isThreeLine: true,
                ),
          ],
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final live = controller.isLive;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: live ? controller.stop : null,
                icon: const Icon(Icons.stop),
                label: const Text('End session'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
