# RTCProbe — Architecture

## 1. Inspected Baseline (Phase 1)

| Item | Value |
|---|---|
| Flutter | 3.47.4 stable (framework revision 9584c6713b) |
| Dart SDK | ^3.13.3 |
| Template | Fresh `flutter create` counter app (`lib/main.dart` only) |
| State management | None beyond `setState` — kept, extended with `ChangeNotifier` |
| Routing | None (single screen) — stays single-entry, nested detail screens |
| Android | Gradle KTS, namespace `com.example.rtc_probe`, `minSdk = flutter.minSdkVersion` |
| iOS | Swift `AppDelegate` (FlutterImplicitEngineDelegate), no Podfile yet (first `pub get` generates it) |
| Existing WebRTC capability | **None** — no RTC dependency, no platform channels |
| Tests | Default `widget_test.dart` (counter pump test) |

No reusable RTC infrastructure exists; everything RTC is new code. No foundational
version changes are required by RTCProbe.

## 2. Layered Architecture

```text
┌─────────────────────────────────────────────┐
│ UI (Flutter widgets)                        │
│  dashboard / detail / events / summary      │
├─────────────────────────────────────────────┤
│ SessionController (ChangeNotifier)          │
│  owns session, timeline, event log, state   │
├─────────────────────────────────────────────┤
│ rtc/ domain (pure Dart)                     │
│  models · sampler · analyzer · diagnostics  │
├─────────────────────────────────────────────┤
│ webrtc/ engine adapter                      │
│  flutter_webrtc (pub package)               │
├─────────────────────────────────────────────┤
│ Native: Swift (iOS) · Kotlin (Android)      │
│  network path info only (MethodChannel)     │
└─────────────────────────────────────────────┘
```

The UI never sees plugin classes; no local media preview is required. `flutter_webrtc` types are confined to the
engine adapter; the adapter emits normalized domain snapshots
(`RtcStatsSnapshot`) consumed by the sampler/analyzer.

## 3. WebRTC Architecture

- **Library**: `flutter_webrtc` — mature pub package wrapping Google's native
  libwebrtc builds for iOS/Android (BSD-3 license, actively maintained). No
  WebRTC internals are reimplemented.
- **Session topology**: *local test peer* — two `RTCPeerConnection`s
  (`probe` ↔ `mirror`) inside the app process. SDP offers/answers and ICE
  candidates are exchanged through direct in-process calls
  (`LoopbackSignaling`). No server; negotiation is reproducible, timing and measured quality are device-dependent.
- **Media**: real captured audio/video tracks (`getUserMedia`) sent from
  `probe` to `mirror`, so inbound+outbound RTP streams, ICE, DTLS and SRTP all
  execute for real on the device network stack. If camera/mic permission is
  denied the session degrades to a data-channel-only connection (still real
  ICE + DTLS) and the UI marks media metrics unavailable.
- **Cleanup**: every peer connection, media stream and the sampling timer are
  disposed on session end / app lifecycle termination.

## 4. Stats Collection Strategy

- `RTCPeerConnection.getStats()` polled by a single periodic sampler
  (default 1 s, configurable constant) — no parallel timers.
- Report walk: candidate-pair / outbound-rtp / inbound-rtp / remote-inbound-rtp
  / track / transport dictionaries mapped to `RtcStatsSnapshot`.
- Deltas (bitrate, loss %) are computed from cumulative counters between
  samples — never from fabricated values.
- Missing fields surface as `null` and the UI renders "Not available".

## 5. QoS Analysis Strategy

- Pure-Dart analyzers compute derived metrics (RTT, jitter, packet-loss ratio,
  send/receive bitrate, FPS) from consecutive snapshots.
- A deterministic classifier maps metric values onto
  `excellent/good/fair/poor/critical` using documented thresholds.
- A rule-based diagnostic engine converts sustained threshold violations into
  `RtcFinding`s (finding + evidence + likely impact), using hedged language
  (suggests/likely/possible).
- A bounded timeline (600-point list, 10 min @ 1 Hz) feeds charts; constant-memory
  accumulators retain the entire session summary independently of chart eviction.

## 6. Native Bridge Strategy

Native code exists only where Flutter/plugins expose nothing:

| Capability | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| Network path (wifi/cellular/ethernet/none, expensive, constrained) | `NWPathMonitor` | `ConnectivityManager` snapshot |

WebRTC itself stays inside `flutter_webrtc`'s native binaries — it is *not*
reimplemented in Swift/Kotlin.

## Completed application flow

Dashboard → SessionController → local peer adapters → normalization → metrics → classification → sustained findings → timeline/whole-session aggregates. Nested details, events and history routes share the controller. End/background releases native resources and retains an in-memory summary. No additional production or state-management dependencies were added; SDK integration_test tooling verifies native behavior.

See [webrtc.md](webrtc.md), [stats.md](stats.md), [qos.md](qos.md), [diagnostics.md](diagnostics.md), [platform-bridge.md](platform-bridge.md), [performance.md](performance.md), [privacy.md](privacy.md) and the [decisions](decisions/) directory. Physical-device behavior is distinguished from automated/source verification in verification.md.
