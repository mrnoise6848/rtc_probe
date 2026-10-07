# WebRTC session

Probe and mirror are native RTCPeerConnections inside one process. No ICE servers are configured; host candidates are sufficient. Tracks from a real getUserMedia capture are added to both peers, generating bidirectional RTP reports on the probe. This is a controlled local peer, not a conferencing app or an Internet probe.

Signaling wires trickled candidates and exchanges offer/answer through Dart calls. Candidates arriving before remote description are buffered. A real data channel carries timestamped ping/echo messages; its application RTT is displayed separately from standardized transport/RTCP RTT. No fabricated heartbeat latency enters quality classification.

Failure controls set native video sender bitrate parameters (when accepted), disable/re-enable video capture tracks, or close the mirror. Closing a peer does not imply instantaneous ICE failure; the app waits for native state events. Restart starts a fresh run, preserving the ended summary until the next Start. See [demo.md](demo.md) and [lifecycle.md](lifecycle.md).

License review: flutter_webrtc's cached LICENSE is BSD-3-Clause. Native redistribution also carries upstream WebRTC/third-party notices. Reuse the pinned package; new native binaries are not vendored. Source capability inspection does not establish a security certification or physical-device compatibility result.
