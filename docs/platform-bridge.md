# Flutter / native boundary

WebRTC runs through flutter_webrtc 1.6.2+hotfix.4 and its native binaries. Dart adapters own peers, local SDP/ICE exchange, capture, raw reports and normalization. UI/analysis only receive RTCProbe domain models; no plugin classes cross into widgets.

The only custom MethodChannel is `rtc_probe/network_info` → `getCurrentPath`. It returns interfaceType, isExpensive, isConstrained and source; no IP address, SSID, SDP or credentials. Swift uses Network.NWPathMonitor in AppDelegate; Kotlin reads ConnectivityManager in MainActivity. This is device network context, not evidence of the selected ICE interface. The monitor is process-scoped and started once; there is no per-sample bridge call.

| Behavior | iOS | Android |
|---|---|---|
| Network context | NWPathMonitor snapshot; initial result may be unavailable until first update | Active network capabilities |
| Metered context | NWPath.isExpensive | Absence of NOT_METERED |
| Low-data mode | NWPath.isConstrained | Not exposed by this bridge; false means unsupported |
| Permissions | Info.plist purpose strings; OS capture prompt | Manifest declarations; plugin runtime prompt |
| Camera/mic unavailable | Try microphone, then real data channel only | Same fallback; native error reasons vary |
| RTP fields / encoder cap | Native libwebrtc may omit/reject fields | Native libwebrtc may omit/reject fields |
| Background | Session explicitly ends, no background capture | Session explicitly ends |

Permissions/capture errors may reflect denial, hardware absence or capture contention; the app cannot reliably distinguish every native error. Camera/video-only fallback is intentionally not implemented. Native controls and actual ICE recovery must be checked on physical devices. SDK and application IDs are preserved.
