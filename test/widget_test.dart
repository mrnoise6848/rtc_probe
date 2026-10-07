import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rtc_probe/main.dart';

void main() {
  testWidgets('dashboard and inspection routes work before native capture', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('RTCProbe'), findsOneWidget);
    expect(find.text('Start probe session'), findsOneWidget);
    await tester.tap(find.byTooltip('Detailed metrics'));
    await tester.pumpAndSettle();
    expect(find.text('Detailed metrics'), findsOneWidget);
    expect(find.text('Not available'), findsWidgets);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Session events'));
    await tester.pumpAndSettle();
    expect(find.text('Start a session to collect events.'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Inspect metric history'));
    await tester.pumpAndSettle();
    expect(find.text('No samples collected yet.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('large text and narrow screen remain usable', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: const MyApp(),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
