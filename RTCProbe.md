# RTCProbe — Final Flutter + Swift Technical Showcase Specification & Agent Instructions

## 1. PROJECT GOAL

Build a **small, technically deep WebRTC quality diagnostics showcase** using:

* Flutter + Dart for the main UI and cross-platform application layer
* Native platform integration where required
* Swift for the iOS native layer
* Android native integration where required

This is NOT a video calling application.

The goal is to answer:

> **Why is a realtime audio/video connection performing badly?**

The project should collect real WebRTC statistics and turn them into understandable diagnostics.

The showcase should demonstrate:

* Flutter architecture
* platform integration
* WebRTC
* realtime networking
* RTC statistics
* QoS analysis
* metrics visualization
* connection lifecycle
* native iOS integration with Swift
* failure analysis
* reproducible diagnostics

---

# 2. CRITICAL EXECUTION RULES

This is an **EXISTING Flutter project**.

Work directly on the existing source.

Do NOT recreate or migrate the project.

### NON-NEGOTIABLE

1. **Do NOT recreate the project from scratch.**
2. **Work directly on the existing source code.**
3. This project is **Flutter + Dart**.
4. The iOS native layer must use **Swift** where native integration is required.
5. Android native integration may use Kotlin where required by the selected WebRTC integration.
6. **Do NOT migrate the application to a different framework.**
7. **Do NOT change the existing Flutter version.**
8. **Do NOT change the existing Dart version.**
9. **Do NOT change existing dependency versions unnecessarily.**
10. **Do NOT change Android Gradle configuration unnecessarily.**
11. **Do NOT change iOS deployment configuration unnecessarily.**
12. **Do NOT change package/application IDs unnecessarily.**
13. **Do NOT replace the existing architecture without a strong technical reason.**
14. **Do NOT change the existing state-management solution without a strong technical reason.**
15. **Do NOT perform broad refactors unrelated to RTCProbe.**
16. **Do NOT remove working functionality.**
17. Reuse existing dependencies, utilities, platform channels, plugins, and architecture whenever possible.
18. You are explicitly allowed to use mature **open-source WebRTC libraries, Flutter WebRTC packages, GitHub projects, official Flutter examples, and native iOS/Android implementations** when they reduce unnecessary work or improve correctness.
19. Before using external code, inspect:

* license
* compatibility
* maintenance quality
* security implications
* platform support

20. Do not blindly copy large amounts of external source code.
21. Prefer mature WebRTC implementations over implementing WebRTC internals from scratch.
22. Do NOT introduce unnecessary packages.
23. Do NOT introduce unnecessary native abstraction layers.
24. Do NOT use fake RTC metrics in production.
25. Do NOT fake packet loss, jitter, bitrate, FPS, RTT, ICE state, or connection state.
26. Real statistics must come from actual WebRTC sessions.
27. Do NOT add a cloud backend unless genuinely required for a minimal reproducible connection.
28. Keep the showcase small and technically focused.
29. **Do NOT run tests until ALL implementation phases are complete.**
30. **Commit after every completed phase.**

---

# 3. ABSOLUTE TESTING RULE

## DO NOT RUN ANY TESTS UNTIL ALL IMPLEMENTATION PHASES ARE COMPLETE

During implementation phases, do NOT execute:

* `flutter test`
* unit tests
* widget tests
* integration tests
* platform tests
* iOS tests
* Android instrumentation tests
* benchmark tests
* WebRTC test suites
* full build/test loops

You may:

* inspect existing tests
* create tests
* modify tests
* review tests statically

But:

> **DO NOT EXECUTE TESTS UNTIL EVERY IMPLEMENTATION PHASE IS COMPLETE.**

This is intentional to reduce token/compute consumption and avoid repeatedly testing an incomplete implementation.

Only after all implementation phases are complete may the final verification pass be executed.

---

# 4. EXECUTION MODE

## START IMPLEMENTATION IMMEDIATELY

After repository inspection:

1. Understand the current codebase.
2. Identify reusable infrastructure.
3. Create a concise implementation plan.
4. Start implementation immediately.
5. Continue automatically through all phases.
6. Do NOT stop after planning.
7. Do NOT ask for confirmation between phases.
8. Do NOT run tests during implementation.
9. Keep explanations concise to save token usage.
10. Continue until the final implementation phase is complete.

Workflow:

```text
Inspect
 ↓
Plan
 ↓
Implement Phase
 ↓
Static Review
 ↓
Commit
 ↓
Next Phase
 ↓
...
 ↓
Final Phase
 ↓
Final Static Review
 ↓
Final Verification
```

---

# 5. GIT COMMIT RULE

## COMMIT AFTER EVERY COMPLETED PHASE

After each completed phase:

1. Review the implementation.
2. Remove temporary/debug code.
3. Review `git diff`.
4. Update documentation where needed.
5. Create one meaningful Git commit.

Do not create empty commits.

Do not combine unrelated phases.

Preferred style:

```text
feat(rtc): add session model
feat(rtc): add WebRTC connection
feat(rtc): collect RTC stats
feat(rtc): add QoS analysis
feat(rtc): add metrics timeline
feat(rtc): add failure diagnostics
```

Use the actual phase content for the commit message.

---

# 6. TOKEN / COMPUTE EFFICIENCY

Optimize for low token and compute usage without sacrificing engineering quality.

### Rules

* Do not reread the entire repository repeatedly.
* Read only files relevant to the current phase.
* Reuse existing code and dependencies.
* Avoid unnecessary explanations.
* Avoid broad refactors.
* Avoid duplicate abstractions.
* Do not run tests during implementation.
* Do not run unnecessary builds repeatedly.
* Do not implement WebRTC from scratch.
* Prefer platform/plugin capabilities already present.
* Do not implement features that are not necessary for the showcase.

Token efficiency must never reduce:

* correctness
* reliability
* maintainability
* security
* observability

---

# 7. PRODUCT

## App Name

**RTCProbe**

## Platform

Flutter

## Main Language

Dart

## Native iOS Language

Swift

## Product Type

Technical showcase / developer diagnostics tool.

---

# 8. PRODUCT DEFINITION

RTCProbe is a tool that establishes or observes a controlled WebRTC session and displays meaningful realtime connection statistics.

Its purpose is not communication.

Its purpose is:

> **Measurement → Analysis → Diagnosis**

Core pipeline:

```text
WebRTC Session
      ↓
RTC Statistics
      ↓
Normalization
      ↓
Metrics
      ↓
QoS Analysis
      ↓
Diagnosis
      ↓
Timeline
```

---

# 9. PRODUCT POSITIONING

RTCProbe is NOT:

* Zoom
* Google Meet
* FaceTime
* a social calling application
* a complete conferencing platform
* a video streaming service

It is a **WebRTC observability / diagnostics tool**.

---

# 10. CORE DEMO

A minimal reproducible flow should exist:

```text
Start Session
      ↓
Establish WebRTC Connection
      ↓
Collect Stats
      ↓
Display Metrics
      ↓
Detect QoS Conditions
      ↓
Show Diagnosis
      ↓
End Session
```

The connection may use:

* loopback
* a local test peer
* a minimal signaling mechanism
* a controlled test endpoint

Choose the simplest reliable architecture.

Do NOT build a production signaling server.

---

# 11. PHASE 1 — EXISTING PROJECT INSPECTION

Inspect:

* `pubspec.yaml`
* Flutter version
* Dart version
* dependencies
* architecture
* state management
* routing
* Android platform files
* iOS platform files
* existing Swift code
* existing Kotlin code
* WebRTC dependencies
* platform channels
* tests
* reusable widgets/utilities

Identify:

* current WebRTC capability
* existing plugin
* native integration points
* current state-management approach

Create/update:

```text
docs/architecture.md
```

Document:

* current architecture
* Flutter/native boundary
* WebRTC architecture
* stats collection strategy
* QoS analysis strategy

Do NOT modify foundational versions.

### Commit after completion.

---

# 12. PHASE 2 — RTC DOMAIN MODEL

Create platform-independent domain models.

Possible models:

```text
RtcSession
RtcPeerState
RtcConnectionState
RtcIceState
RtcStatsSnapshot
RtcMetric
RtcQualityReport
RtcFinding
RtcTimelinePoint
```

Example metrics:

```text
roundTripTime
jitter
packetLoss
bitrate
frameRate
framesDropped
framesReceived
framesSent
iceState
connectionState
candidatePair
```

Do not expose plugin-specific classes directly to the UI.

### Commit after completion.

---

# 13. PHASE 3 — WEBRTC SESSION FOUNDATION

Implement the smallest real WebRTC session required for the showcase.

Support:

* create peer connection
* establish connection
* connection state
* ICE state
* close session
* proper cleanup

Use a mature Flutter WebRTC implementation.

Do NOT implement SDP/ICE/WebRTC internals from scratch.

Handle:

* initialization failure
* permission denial where relevant
* connection failure
* disconnection
* cleanup

### Commit after completion.

---

# 14. PHASE 4 — SIGNALING / TEST CONNECTION

Create the simplest possible reproducible signaling mechanism.

The goal is not to create a backend product.

Possible approaches:

* local in-process peer
* deterministic loopback
* minimal signaling endpoint
* controlled local test harness

Choose the smallest reliable approach.

Document the choice.

Avoid introducing a complex server architecture.

### Commit after completion.

---

# 15. PHASE 5 — PERMISSIONS

If audio/video capture is part of the session:

Handle:

* microphone permission
* camera permission

Request them contextually.

Do not request unrelated permissions.

Handle denial gracefully.

The tool should still provide diagnostics appropriate to the available media configuration.

### Commit after completion.

---

# 16. PHASE 6 — NATIVE PLATFORM BRIDGE

Create a clean platform boundary.

Conceptually:

```text
Flutter
   ↓
RTC Abstraction
   ↓
Platform Implementation
   ├── Android
   └── iOS / Swift
```

Use native code only when the Flutter layer/plugin does not expose the information or behavior required.

For iOS:

* use Swift
* keep native code minimal
* expose only required functionality to Flutter

Do not move the entire WebRTC implementation into Swift.

### Commit after completion.

---

# 17. PHASE 7 — RTC STATS COLLECTION

Collect real WebRTC statistics.

Prefer standardized WebRTC statistics available through the selected implementation.

Potential data:

### Connection

* ICE state
* signaling state
* connection state
* candidate type

### Network

* round-trip time
* jitter
* packets sent
* packets received
* packets lost
* bytes sent
* bytes received
* bitrate

### Video

* FPS
* frames sent
* frames received
* frames dropped
* resolution

### Audio

* packets lost
* jitter
* bitrate where available

Only collect metrics actually supported by the platform/plugin.

If unavailable:

```text
Not available
```

Do not fabricate.

### Commit after completion.

---

# 18. PHASE 8 — STATS NORMALIZATION

Different platforms may expose slightly different statistics.

Normalize them into a common Dart domain model.

Example:

```text
Native / WebRTC Stats
        ↓
Platform Adapter
        ↓
Normalized RtcStatsSnapshot
```

The UI should not know about Android/iOS plugin-specific field names.

### Commit after completion.

---

# 19. PHASE 9 — SAMPLING ENGINE

Implement periodic stats sampling.

Example:

```text
0s
1s
2s
3s
...
```

Avoid excessively frequent sampling.

The sampling interval should be configurable internally.

Handle:

* session ended
* connection lost
* stats unavailable
* sampling cancellation

Do not create uncontrolled timers.

### Commit after completion.

---

# 20. PHASE 10 — QOS METRIC CALCULATION

Calculate meaningful metrics.

At minimum:

```text
RTT
Jitter
Packet Loss
Bitrate
FPS
```

Where valid.

Use clear terminology.

Do not call HTTP request failure "packet loss."

Use packet-level metrics only when derived from actual WebRTC packet statistics.

### Commit after completion.

---

# 21. PHASE 11 — QUALITY CLASSIFICATION

Create deterministic QoS classifications.

Example:

```text
Excellent
Good
Fair
Poor
Critical
```

The thresholds must be documented.

Do not present them as universal industry standards.

For example:

```text
RTT
< threshold
→ healthy

Jitter
above threshold
→ degraded
```

The classifier must remain deterministic.

### Commit after completion.

---

# 22. PHASE 12 — DIAGNOSTIC ENGINE

Build a deterministic diagnostic engine.

Example:

```text
Finding:
High jitter

Evidence:
Jitter increased from 8 ms to 92 ms

Possible impact:
Audio/video may become unstable
```

Another:

```text
Finding:
High packet loss

Evidence:
Packet loss = 6.2%

Possible impact:
Video quality may degrade
```

Another:

```text
Finding:
Low bitrate

Evidence:
Bitrate dropped significantly
while connection remained established
```

Do not claim a root cause unless the data actually supports it.

Use:

* detected
* suggests
* likely
* possible

instead of unjustified certainty.

### Commit after completion.

---

# 23. PHASE 13 — TIMELINE ENGINE

Store recent metric samples.

Example:

```text
0s ───────────────── 60s

RTT
Jitter
Packet Loss
Bitrate
FPS
```

Allow the user to inspect historical behavior.

Avoid storing unlimited session data.

Use bounded history.

### Commit after completion.

---

# 24. PHASE 14 — MAIN DASHBOARD

Create a clean dashboard.

Example:

```text
RTCProbe

Connection
● Connected

Quality
GOOD

RTT
48 ms

Jitter
7.3 ms

Packet Loss
0.8%

Bitrate
1.8 Mbps

FPS
30
```

Show only the most important metrics first.

Advanced metrics may be placed behind a detail screen.

### Commit after completion.

---

# 25. PHASE 15 — DETAILED METRICS SCREEN

Show:

```text
Connection

ICE
Connected

RTT
48 ms

Jitter
7.3 ms

Packets Lost
124

Packets Received
18,423

Bitrate
1.8 Mbps
```

Use real session data.

No demo placeholders.

### Commit after completion.

---

# 26. PHASE 16 — EVENT / STATE LOG

Display important RTC events.

Example:

```text
12:31:04
ICE checking

12:31:05
ICE connected

12:31:09
Network quality degraded

12:31:16
Packet loss increased
```

Do not log sensitive media content.

The log should store only diagnostics metadata.

### Commit after completion.

---

# 27. PHASE 17 — CONTROLLED FAILURE SIMULATION

Create safe ways to demonstrate degraded conditions where technically practical.

Examples:

* temporary network interruption
* bandwidth limitation
* connection restart
* peer disconnection

The goal is to demonstrate that RTCProbe detects:

```text
Healthy
    ↓
Degraded
    ↓
Recovered
```

Do not fake metrics.

Prefer real network/system behavior.

If a platform cannot reliably reproduce a specific failure programmatically, provide a documented manual reproduction procedure instead.

### Commit after completion.

---

# 28. PHASE 18 — SESSION SUMMARY

When a session ends, produce a summary.

Example:

```text
Session Summary

Duration
04:32

Average RTT
51 ms

Peak Jitter
82 ms

Average Bitrate
1.7 Mbps

Packet Loss
1.2%

Quality
GOOD

Findings
2
```

Values must come from actual collected statistics.

### Commit after completion.

---

# 29. PHASE 19 — PERFORMANCE / RESOURCE USAGE

The diagnostics layer must not become the source of the problem.

Avoid:

* excessive polling
* excessive UI updates
* unbounded sample history
* unnecessary JSON conversion
* excessive native/Flutter bridge traffic
* unnecessary chart redraws

The tool should sample metrics efficiently.

### Commit after completion.

---

# 30. PHASE 20 — BACKGROUND / LIFECYCLE HANDLING

Handle:

* app backgrounding
* app foregrounding
* session termination
* WebRTC disconnect
* native resource cleanup
* permission changes
* route changes where applicable

Do not leave native WebRTC resources active after the session ends.

### Commit after completion.

---

# 31. PHASE 21 — PLATFORM DIFFERENCES

Document differences between:

* Android
* iOS

Examples may include:

* available stats
* camera behavior
* microphone behavior
* background limitations
* native APIs
* permission behavior

Do not force identical behavior when the platform cannot provide it.

The common Flutter layer should present normalized behavior where possible.

### Commit after completion.

---

# 32. PHASE 22 — ACCESSIBILITY / UX

Ensure:

* readable metric names
* meaningful semantics
* accessible controls
* sufficient contrast
* sensible tap targets
* understandable diagnostic language

Avoid a dashboard that looks like an engineering console for non-technical users.

Primary information should remain understandable.

### Commit after completion.

---

# 33. PHASE 23 — PRIVACY / SECURITY REVIEW

Review the entire project.

Ensure:

* no audio/video content is uploaded anywhere unnecessarily
* no credentials are collected
* no private session data is logged
* no raw media is persisted unnecessarily
* no insecure TLS is introduced
* no WebRTC certificate verification is disabled
* no secret keys are hardcoded
* no network diagnostics are sent to third parties without explicit need

If a remote signaling endpoint is used, document exactly what it receives.

### Commit after completion.

---

# 34. PHASE 24 — DOCUMENTATION

Create/update:

```text
docs/architecture.md
docs/webrtc.md
docs/stats.md
docs/qos.md
docs/diagnostics.md
docs/platform-bridge.md
docs/privacy.md
docs/performance.md
docs/decisions/
```

Suggested decisions:

```text
001-preserve-existing-project.md
002-webrtc-library-choice.md
003-flutter-native-boundary.md
004-ios-swift-bridge.md
005-stats-normalization.md
006-qos-thresholds.md
007-bounded-timeline-history.md
008-no-fake-metrics.md
009-no-media-upload.md
```

### Commit after completion.

---

# 35. PHASE 25 — README / PORTFOLIO PRESENTATION

README must immediately communicate the engineering value.

Recommended:

```text
# RTCProbe

Why is a WebRTC connection actually performing badly?

RTCProbe is a small realtime diagnostics toolkit
that collects real WebRTC statistics, normalizes them,
analyzes QoS, and explains connection degradation.
```

Then:

```text
## Problem

## Architecture

## WebRTC Stats

## QoS Analysis

## Diagnostics

## Timeline

## Flutter / Native Integration

## Swift iOS Layer

## Demo

## Performance

## Privacy

## Limitations

## Roadmap
```

Include a short GIF/video showing:

```text
Session
 ↓
Metrics
 ↓
Network degradation
 ↓
Diagnosis
 ↓
Recovery
```

Do not oversell it as a complete production conferencing platform.

### Commit after completion.

---

# 36. PHASE 26 — FINAL STATIC REVIEW

Review the complete implementation without running tests yet.

Check:

* Flutter/native boundary
* Swift bridge
* Android bridge
* lifecycle
* WebRTC cleanup
* stats accuracy
* sampling frequency
* bounded history
* UI rebuilds
* memory
* privacy
* security
* dependency count
* fake data
* fake metrics
* debug code
* documentation

Do NOT run tests yet.

### Commit after completion.

---

# 37. CONTINUOUS IMPLEMENTATION REQUIREMENT

After implementation starts:

> **Continue automatically through ALL implementation phases until Phase 26 is complete.**

Do not stop after planning.

Do not wait for approval between phases.

Do not ask for confirmation.

Do not stop merely because one phase was completed.

If a genuine blocker occurs:

1. inspect existing project capabilities
2. inspect current packages
3. inspect Flutter APIs
4. inspect native APIs
5. inspect mature WebRTC implementations
6. choose the least invasive compatible approach
7. document the limitation

Do not silently change foundational versions.

---

# 38. FINAL TESTING RULE

## ONLY AFTER ALL IMPLEMENTATION PHASES

Once Phase 26 is complete, and all phase commits exist, perform the final verification.

Run:

* Flutter tests
* integration tests
* platform tests where applicable
* WebRTC-specific tests
* widget tests
* static analysis
* formatting verification
* Android build
* iOS build where configured

Do not modify project versions merely to make tests pass.

---

# 39. FINAL MANUAL VALIDATION

Validate on real Android and iOS devices where practical.

Verify:

1. Start RTC session
2. Successful connection
3. ICE state transitions
4. Connection state transitions
5. Real RTT
6. Real jitter
7. Real packet statistics
8. Real bitrate
9. Real FPS where available
10. Metrics update
11. Timeline update
12. Quality classification
13. Diagnostic findings
14. Controlled degradation
15. Recovery
16. Session summary
17. Session cleanup
18. App backgrounding
19. App foregrounding
20. Permission denial
21. Permission restoration
22. Android native integration
23. iOS Swift integration
24. Remote signaling failure if used
25. Privacy/security behavior

Only claim scenarios that were actually validated.

---

# 40. DEFINITION OF DONE

RTCProbe is complete when:

* existing Flutter project preserved
* Flutter/Dart versions unchanged
* existing architecture preserved
* iOS native layer uses Swift where required
* Android native integration works where required
* mature WebRTC implementation is reused
* real RTC session works
* real statistics are collected
* stats are normalized
* sampling works
* QoS metrics work
* quality classification works
* deterministic diagnostic engine works
* timeline works
* event log works
* controlled degradation can be demonstrated where supported
* session summary works
* lifecycle handling works
* native resources are cleaned up
* performance is acceptable
* memory usage is bounded
* no fake metrics exist
* no fake connection state exists
* no unnecessary media data is uploaded
* no insecure TLS behavior exists
* documentation exists
* README exists
* every phase has a Git commit
* all implementation phases are complete
* final verification is complete

---

# 41. GIT COMMIT RULE

After every completed phase:

```text
Review
 ↓
Remove temporary/debug code
 ↓
Update docs
 ↓
Review git diff
 ↓
Commit
```

Use clear commit messages such as:

```text
feat(rtc): add session domain model
feat(rtc): add webRTC connection
feat(rtc): add stats collection
feat(rtc): normalize platform stats
feat(rtc): add QoS analysis
feat(rtc): add diagnostics timeline
feat(rtc): add Swift platform bridge
```

Do not create empty commits.

Do not combine unrelated phases.

---

# 42. TOKEN / COMPUTE EFFICIENCY

Optimize for token/compute usage.

* Inspect only relevant files.
* Do not reread the entire repository repeatedly.
* Reuse existing code.
* Reuse mature WebRTC implementations.
* Avoid unnecessary packages.
* Avoid unnecessary native code.
* Avoid repeated builds.
* Do not run tests before the end.
* Keep explanations concise.
* Keep the diagnostic model compact.
* Keep timeline history bounded.

Do not sacrifice:

* correctness
* reliability
* security
* maintainability
* measurement accuracy

for token savings.

---

# 43. FINAL INSTRUCTION

Build **RTCProbe as a small, professional WebRTC diagnostics showcase**.

Do NOT build a video-call clone.

The project should demonstrate:

```text
Flutter
+
WebRTC
+
Realtime Networking
+
RTC Statistics
+
QoS Analysis
+
Diagnostics
+
Timeline
+
Native Integration
+
Swift iOS
```

The central pipeline is:

> **Connect → Measure → Analyze → Explain → Recover**

The most important engineering principle is:

> **Never invent or fake network metrics. Every displayed metric must come from a real WebRTC session or be clearly marked unavailable.**

Use mature open-source WebRTC implementations instead of reinventing WebRTC internals.

Keep the scope small.

Keep the code clean.

Keep the native layer minimal.

Keep the diagnostics deterministic and explainable.

**Start implementation immediately.**

**Continue automatically through ALL implementation phases until Phase 26 is complete.**

**Commit after every completed phase.**

**DO NOT RUN ANY TESTS UNTIL ALL IMPLEMENTATION PHASES ARE COMPLETE.**

Optimize token/compute usage without sacrificing correctness, security, measurement accuracy, or code quality.
