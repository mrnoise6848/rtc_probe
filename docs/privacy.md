# Privacy and security review

No signaling server, STUN/TURN, analytics, credentials or cloud endpoint is configured. Offers/answers/candidates are exchanged directly between two local peers. Captured media traverses the native ICE/DTLS/SRTP stack between peers on the same device; no media file is saved and no remote peer is configured. WebRTC certificate verification and transport security are not overridden.

RTCProbe stores only bounded diagnostic metadata in memory: normalized counters, levels, findings, timestamps and state events. No SDP, candidate addresses, raw reports, audio/video content, SSID or device identifier is logged by application code. Native failures use sanitized messages, avoiding accidental protocol data in logs. Plugin/OS diagnostic logging may differ by platform and should be reviewed during a release audit.

Camera/microphone are requested on Start, with audio-only/data-channel fallback. End/background releases capture and peers. Summary/history clear on the next Start or process exit. There is no export, persistence or third-party telemetry. Dependencies retain the established lockfile versions; no new packages were introduced during completion.

This is a source review, not a packet-capture audit. Confirm transport behavior with device inspection before making distribution-level privacy guarantees.
