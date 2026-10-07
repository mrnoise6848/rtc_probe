import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rtc_probe/rtc/models.dart';
import 'package:rtc_probe/main.dart';
import 'package:rtc_probe/ui/session_controller.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'dashboard measures native transport, detects interruption and restarts',
    (tester) async {
      final controller = SessionController(captureRequested: false);
      addTearDown(controller.stop);
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MyApp(controller: controller),
        ),
      );
      Future<void> captureFrame(String name) async {
        await tester.pump();
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          binding.reportData ??= <String, dynamic>{};
          binding.reportData!['screenshots'] ??= <dynamic>[];
          (binding.reportData!['screenshots'] as List<dynamic>).add(
            <String, dynamic>{'screenshotName': name, 'bytes': bytes.toList()},
          );
        } finally {
          image.dispose();
        }
      }

      await tester.tap(find.text('Start probe session'));
      Future<void> waitUntil(bool Function() ready, {int seconds = 20}) async {
        for (var i = 0; i < seconds * 5 && !ready(); i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(ready(), isTrue);
      }

      await waitUntil(
        () =>
            controller.connectionState == RtcConnectionState.connected &&
            controller.historyPoints.length >= 3,
      );
      expect(controller.snapshot?.candidatePair?.state, 'succeeded');
      expect(controller.metrics.videoFps, isNull);
      expect(find.text('Not available'), findsWidgets);
      await captureFrame(
        '${Platform.isIOS ? 'ios' : 'android'}-01-live-transport',
      );
      await controller.dropMirrorPeer();
      await waitUntil(
        () => controller.findings.any(
          (f) => f.code == RtcFindingCode.connectionInterrupted,
        ),
        seconds: 60,
      );
      expect(controller.quality.level, RtcQualityLevel.critical);
      await captureFrame(
        '${Platform.isIOS ? 'ios' : 'android'}-02-native-interruption',
      );
      await tester.scrollUntilVisible(
        find.text('Findings'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await captureFrame(
        '${Platform.isIOS ? 'ios' : 'android'}-02b-diagnostic-finding',
      );
      await controller.restart();
      await waitUntil(
        () =>
            controller.connectionState == RtcConnectionState.connected &&
            controller.historyPoints.length >= 3,
      );
      expect(
        controller.findings.where(
          (f) => f.code == RtcFindingCode.connectionInterrupted,
        ),
        isEmpty,
      );
      await tester.scrollUntilVisible(
        find.text('Connection'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await captureFrame(
        '${Platform.isIOS ? 'ios' : 'android'}-03-restarted-transport',
      );
      await tester.tap(find.text('End session'));
      await waitUntil(() => controller.summary != null);
      expect(controller.summary!.sampleCount, greaterThanOrEqualTo(3));
      expect(find.text('Session summary'), findsOneWidget);
      await captureFrame(
        '${Platform.isIOS ? 'ios' : 'android'}-04-session-summary',
      );
      await controller.start();
      await waitUntil(
        () =>
            controller.connectionState == RtcConnectionState.connected &&
            controller.historyPoints.isNotEmpty,
      );
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await controller.stop();
      expect(controller.summary, isNotNull);
      expect(controller.phase, RtcSessionPhase.ended);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(
        controller.phase,
        RtcSessionPhase.ended,
        reason: 'Foreground must not automatically reacquire capture.',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
