import 'package:flutter/material.dart';
import 'package:rtc_probe/ui/format.dart';
import 'package:rtc_probe/ui/session_controller.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key, required this.controller});
  final SessionController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Session events')),
    body: ListenableBuilder(listenable: controller, builder: (context, _) {
      final events = controller.events.reversed.toList(growable: false);
      if (events.isEmpty) return const Center(child: Text('Start a session to collect events.'));
      return ListView.builder(itemCount: events.length, itemBuilder: (context, index) {
        final event = events[index];
        return ListTile(leading: const Icon(Icons.history), title: Text(event.message), subtitle: Text('${clockLabel(event.wallClock)} • +${durationLabel(event.elapsedMs)}'));
      });
    }),
  );
}
