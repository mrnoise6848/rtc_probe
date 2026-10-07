# Reproducible demo

1. Start a probe; allow microphone/camera if desired. Wait for actual Connected and ICE states.
2. Open detailed metrics and events; RTT may precede media metrics. First-sample deltas are unavailable.
3. On a video session, cap the probe encoder to 64 kbps. Observe actual send bitrate; a sustained value below 100 kbps can raise a finding. A static camera scene may already send little data. Platform rejection is shown.
4. Remove the cap; wait for measured recovery and three healthy samples to clear a finding.
5. Disconnect the mirror. ICE/connection failure may take seconds to detect. Restart opens a new session; End session retains the summary.
6. Pause/resume video as a media-control experiment. Disabled tracks may send black frames; this is not guaranteed to create zero FPS or packet loss.

The local path may survive airplane mode. Loopback cannot prove Internet quality, WAN packet loss or Wi-Fi congestion. To exercise those, a future remote peer or OS network shaper that demonstrably affects the selected ICE interface is required. Never substitute manufactured metrics. For device resource pressure, run another camera/CPU-heavy workload and observe whether real statistics change; no degradation is guaranteed.

Manual validation: exercise denial/restoration in system settings, background the app, reopen and start a fresh session, repeat end/start and verify camera indicator clears. Real Android/iOS validation remains a separate release check; see verification.md.
