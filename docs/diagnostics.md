# Evidence-based findings

Rules use real counters/state, not guessed root causes. RTT >300 ms, jitter >40 ms, loss >4%, or send bitrate <100 kbps while video is enabled and connected need three consecutive samples. Native zero FPS while video is enabled needs five samples. Disconnected/failed state needs three sampled observations. Three healthy observations clear a finding. Missing evidence must not count as recovery.

Every finding names what was detected, gives measured evidence and describes possible impact. Low bitrate can reflect a static scene, encoder settings or resource pressure, not necessarily network congestion. A paused track may produce black frames rather than stop frames. Capture unavailability is raised as an informational fact and does not fabricate media metrics.

Event log records raised/cleared findings and transitions. Summary counts raised occurrences (including repeated incidents), not only the number currently active. Maximum active findings is bounded by the fixed set of rule codes.
