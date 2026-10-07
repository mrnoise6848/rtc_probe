# Deterministic quality defaults

RTCProbe uses its own demonstration thresholds, not universal industry standards. Overall quality is the worst available RTT, jitter or interval packet loss assessment. Bitrate/FPS remain displayed and feed diagnostics; bitrate alone cannot determine quality because codecs/scenes differ. No available inputs gives Unknown.

| Metric | Excellent | Good | Fair | Poor | Critical |
|---|---:|---:|---:|---:|---:|
| RTT ms | ≤80 | ≤150 | ≤300 | ≤500 | >500 |
| Jitter ms | ≤10 | ≤20 | ≤40 | ≤60 | >60 |
| Loss % | ≤0.1 | ≤0.5 | ≤1.5 | ≤4 | >4 |

Upper bounds are inclusive. A single sample changes classification; findings separately require persistence. Excellent transport RTT does not imply healthy media when media fields are unavailable, or Internet health in a local session. Session summary reports the worst measured sample quality, not an overall subjective call score.

At the controller boundary, native Disconnected/Failed overrides live metric quality to Critical with explicit state evidence; connecting/idle has no live media assessment. Old counters after disconnection are not displayed as current healthy measurements.
