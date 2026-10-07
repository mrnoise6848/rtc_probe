# RTCProbe

**Why is a WebRTC connection actually performing badly?**

RTCProbe is a small Flutter diagnostics showcase that collects real WebRTC statistics, normalizes them, analyzes QoS and explains measured degradation. Swift and Kotlin provide minimal native network context.

## Problem

Connection state alone does not explain stuttering media. RTCProbe connects measurement to evidence: RTT, jitter, packet loss, bitrate and FPS where the native implementation reports them. Missing values say **Not available**.

## Architecture

```text
Local probe ↔ mirror (ICE / DTLS / SRTP)
  → getStats → normalization → counter deltas
  → quality → sustained findings → bounded timeline / summary
```

The existing Flutter project, SDK constraints, app IDs and dependency versions are preserved. ChangeNotifier owns the session; widgets receive domain types. [Architecture](docs/architecture.md).

## WebRTC Stats

Transport/candidate pairs, RTP streams, remote RTCP reports and data-channel counters. First-sample rates and unsupported fields remain unavailable. [Field mappings and formulas](docs/stats.md).

## QoS Analysis

Deterministic Excellent/Good/Fair/Poor/Critical thresholds for RTT, jitter and loss. These are project defaults, not universal standards. [Thresholds](docs/qos.md).

## Diagnostics

Sustained conditions raise findings with measured evidence and possible impact. No inferred root cause is presented as certain. [Rules](docs/diagnostics.md).

## Timeline

Last 60 seconds on the dashboard; inspect up to 600 retained samples. Session summaries aggregate the whole run in constant memory. Event history is bounded to 200 entries.

## Flutter / Native Integration

flutter_webrtc owns native WebRTC. Dart adapters hide plugin types. Kotlin reads Android network capabilities; native context is separate from the selected ICE path. [Boundary and differences](docs/platform-bridge.md).

## Swift iOS Layer

A minimal NWPathMonitor bridge in AppDelegate reports interface, metered and low-data context. No duplicate WebRTC implementation in Swift. [Lifecycle](docs/lifecycle.md).

## Demo

```sh
flutter pub get
flutter run
```

Start → allow capture (or use fallback) → observe live metrics → cap video bitrate → observe findings → remove cap → observe recovery → End → summary. Disconnecting the mirror demonstrates native transport failure; Restart opens a fresh run. [Step-by-step demo](docs/demo.md).

A real-device recording/GIF should be captured using that procedure once device validation is complete; no fabricated demo recording is included. Check [verification status](docs/verification.md) before treating device behavior as validated.

## Performance

1 Hz overlap-safe sampling, bounded history, no raw-report serialization, whole-run summary accumulators and no continuous chart animations. [Budget](docs/performance.md).

## Privacy

No backend, remote peer, STUN/TURN, analytics, media persistence or hardcoded secrets. Diagnostics stay in memory. End/background releases native capture. [Review](docs/privacy.md).

## Limitations

- Local loopback measures the device media/transport stack, **not Internet quality**.
- One audio/video stream per direction; no simulcast or multi-peer analysis.
- Native stats and bitrate-control support vary. Data-only sessions have no media measurements.
- Track pause can send black frames; mirror closure may take time to affect ICE.
- No automatic WAN shaping, production signaling or conferencing features.
- Physical-device permissions, native cleanup and recovery require explicit manual validation.

## Verification

After all implementation phases: `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`, `flutter build apk --debug`, and `flutter build ios --simulator --debug` where tooling is installed. [Results and manual checklist](docs/verification.md).

## Roadmap

A controlled remote peer, packet-weighted session loss, physical-device demo recording and measured release profiling are future extensions. They are not implied by loopback results.
