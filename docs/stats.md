# Real stats and normalization

The adapter calls the probe's getStats at 1 Hz. Selected transport candidate pair provides RTT (seconds converted to milliseconds), nomination and candidate types. Outbound RTP maps bytes/packets sent, frames encoded, FPS and resolution. Matching remote-inbound SSRC reports supply RTCP RTT/fraction loss. Inbound RTP maps bytes/packets received, packets lost, jitter, decoded/dropped frames. Data-channel counters stay separate.

Absent reports/fields remain null → Not available. Numeric codec strings are accepted; non-finite values are rejected. ICE/connection state comes from native callbacks, never from a UI assumption that negotiation has completed. The tool supports one audio/video stream per direction; it is not a multi-track/simulcast aggregator.

Bitrate kbps = delta bytes × 8 / delta milliseconds. Intervals across identity/counter reset or invalid elapsed time are unavailable. Packet loss % = delta lost / (delta received + delta lost) × 100 across measurable inbound streams. No received/lost traffic makes the interval unavailable. FPS prefers native framesPerSecond and falls back to delta encoded frames / elapsed seconds where possible.

Snapshot timestamps describe sampling; durations use a monotonic stopwatch. Missing stats clear displayed current metrics and reset the delta baseline. The summary is a mean of available sampled metric values, including mean interval loss (not a packet-weighted total), and retains all samples in constant-memory aggregates. Charts retain the latest 600 points and display 60 seconds by default.
