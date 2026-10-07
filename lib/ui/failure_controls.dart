import 'package:flutter/material.dart';
import 'package:rtc_probe/ui/session_controller.dart';

class FailureControls extends StatefulWidget {
  const FailureControls({super.key, required this.controller});
  final SessionController controller;
  @override
  State<FailureControls> createState() => _FailureControlsState();
}

class _FailureControlsState extends State<FailureControls> {
  bool _busy = false;
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try { await action(); } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Controlled failure', style: Theme.of(context).textTheme.titleMedium),
        const Text('These controls change real encoder or peer behavior. Results vary by device. Restart creates a new session.'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton(onPressed: _busy || !c.hasVideoGrant ? null : () => _run(() async {
            final ok = await c.applyBitrateCapKbps(c.appliedBitrateCapKbps == null ? 64 : null);
            if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Platform did not accept the bitrate cap.')));
          }), child: Text(c.appliedBitrateCapKbps == null ? 'Cap video at 64 kbps' : 'Remove bitrate cap')),
          OutlinedButton(onPressed: _busy || !c.hasVideoGrant ? null : () => _run(() => c.setVideoTrackEnabled(!c.videoTrackEnabled)), child: Text(c.videoTrackEnabled ? 'Pause video' : 'Resume video')),
          OutlinedButton(onPressed: _busy ? null : () => _run(c.dropMirrorPeer), child: const Text('Disconnect mirror peer')),
          OutlinedButton(onPressed: _busy ? null : () => _run(c.restart), child: const Text('Restart session')),
        ]),
      ],
    )));
  }
}
