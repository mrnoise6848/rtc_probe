# Verification status

Implementation phase 26 must complete before any tests/build loops run (RTCProbe.md). Automated verification results will be recorded here after that commit.

Physical Android/iOS validation and a recorded media demo are pending. No live RTC metrics, native permission behavior, battery figures or recovery timing are claimed as validated by source/unit tests.

## Manual device checklist

- Start → native Connected and ICE transitions; grant both, microphone-only, neither.
- Observe real RTT/jitter/counters/bitrate/FPS or explicit unavailable values.
- Inspect history and event transitions; End shows whole-session aggregates.
- Cap/remove encoder bitrate, disconnect mirror and restart; verify findings only on measured evidence.
- Repeat rapid start/end and background during OS permission/setup; verify camera/mic indicators release.
- Restore permission in Settings and Start again; navigate details/events/history during a session.
- Android native context and iOS Swift context; large fonts, TalkBack/VoiceOver, portrait/landscape.
- Inspect traffic and logs: no remote signaling/media upload, no protocol addresses or media persisted.

Remote signaling failure is not applicable: no remote endpoint exists. WAN shaping is not claimed for local loopback.
