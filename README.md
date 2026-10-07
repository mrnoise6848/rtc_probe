# RTCProbe

**Turn WebRTC stats into a diagnosis you can follow.**

“Connected” tells you that a peer connection exists. It does not explain stalled video, rising jitter or changing bitrate. Even the raw statistics need interpretation: counters accumulate, streams reset and different native implementations expose different fields.

RTCProbe is a Flutter lab that connects native WebRTC measurements to timelines, quality assessments and sustained findings. Its probe and mirror run on the same device, providing a repeatable local transport experiment without a signaling server. It measures that local stack, not internet quality.

## Watch a real interruption become a finding

<p align="center">
  <img src="docs/media/probe-demo.gif" width="360" alt="Android probe connects, detects a mirror interruption, reports a finding, restarts and displays a summary">
</p>

*Five actual Android transport-only integration captures. The animation shows connection, interruption, diagnosis, fresh restart and summary; frame duration is illustrative, not measured recovery time.*

```sh
flutter pub get
flutter run
```

Choose Transport-only and Start. Inspect the details, disconnect the mirror and wait for native state changes to produce a finding. Restart opens a new session; End keeps the summary in memory. [Demo walkthrough](docs/demo.md)

## A counter is not yet a rate

```text
Native getStats → normalized snapshot → comparable counter deltas
    → current quality → sustained findings → timeline and summary
```

The [metrics calculator](lib/rtc/metrics_calculator.dart) derives bitrate from byte deltas over elapsed time. First samples, invalid intervals and reset stream identities cannot supply a meaningful rate, so the UI keeps those values unavailable instead of drawing a spike.

Inbound loss uses lost/received deltas across measurable streams. FPS uses a native rate or encoded-frame delta fallback. RTT comes from the selected candidate pair, with remote RTCP fallback where available. Data-channel counters remain separate from media statistics. [Field mappings and formulas](docs/stats.md)

These choices also shape summaries: session loss is the mean of available interval percentages, not a packet-weighted total. Missing media fields in a transport-only run remain **Not available**.

## Separate a bad sample from a persistent condition

Current quality uses the worst available RTT, jitter or loss grade. Findings normally require three consecutive samples, then three healthy samples to clear; stalled video frames require five. The finding includes the observed evidence and possible impact.

Native disconnection/failure overrides live quality to Critical. Project thresholds make decisions reproducible, while context remains essential: a low bitrate can reflect a static scene, and good local RTT says nothing about an internet route. [Diagnostic rules](docs/diagnostics.md) · [Quality thresholds](docs/qos.md)

## Native transport, bounded Flutter state

`flutter_webrtc` owns the native peer connections. Dart adapters normalize plugin data; ChangeNotifier coordinates the session and widgets consume domain models. Kotlin and Swift provide platform network context separately from the selected ICE path.

Sampling runs at 1 Hz without overlapping requests. Charts retain 600 samples and initially display 60 seconds; events retain 200 entries. Whole-session aggregates continue outside that rolling window. End/background releases the session through lifecycle handling. [Architecture](docs/architecture.md) · [Native bridge](docs/platform-bridge.md) · [Lifecycle](docs/lifecycle.md)

## Verified transport; capture experiments next

The [verification record](docs/verification.md) reports **28 passing unit/widget tests**, Android/iOS-simulator debug builds, and native transport/dashboard integration on Android A063 and an iPhone simulator. Coverage includes counter resets, unavailable fields, sustained findings, bounded history, interruption and restart.

```sh
flutter test
flutter analyze
flutter test integration_test/local_session_test.dart -d DEVICE_ID
flutter drive --driver=test_driver/integration_driver.dart --target=integration_test/dashboard_session_test.dart -d DEVICE_ID
```

Run device targets sequentially. Capture mode and encoder controls are implemented, but real camera/microphone metrics, permission flows, physical iOS and OS backgrounding during capture still need device validation. Caps may be rejected by the platform, and a paused video track may send black frames rather than produce zero FPS.

The current scope is one audio/video stream per direction. A controlled remote peer, packet-weighted session loss and release resource profiling are future extensions. No STUN/TURN service, remote peer, analytics or media persistence is configured; diagnostics remain in memory. [Privacy](docs/privacy.md)
