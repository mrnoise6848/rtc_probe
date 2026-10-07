import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:rtc_probe/rtc/models.dart';

/// Outcome of a contextual media permission attempt.
class MediaAccessResult {
  const MediaAccessResult({
    required this.stream,
    required this.grant,
    required this.deniedKinds,
  });

  final MediaStream? stream; // null when nothing was granted
  final RtcMediaGrant grant;
  final List<String> deniedKinds; // subset of {'camera', 'microphone'}
}

/// Requests microphone/camera exactly when the user starts a session
/// (never at app launch) and degrades gracefully on denial:
///
///   camera+mic → mic-only → data-channel-only session
///
/// The OS permission dialog itself is triggered by the WebRTC plugin's
/// `getUserMedia`; a denial surfaces as an exception we convert into a
/// fallback instead of failing the whole session.
class MediaAccess {
  const MediaAccess();

  Future<MediaAccessResult> acquire() async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia(const {
        'audio': true,
        'video': {
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
          'frameRate': {'ideal': 30},
        },
      });
      return MediaAccessResult(
        stream: stream,
        grant: RtcMediaGrant.audioVideo,
        deniedKinds: const [],
      );
    } catch (_) {
      // Camera or both denied — try microphone only.
    }

    try {
      final stream = await navigator.mediaDevices.getUserMedia(const {
        'audio': true,
      });
      return MediaAccessResult(
        stream: stream,
        grant: RtcMediaGrant.audioOnly,
        deniedKinds: const ['camera'],
      );
    } catch (_) {
      // Microphone denied as well.
    }

    return const MediaAccessResult(
      stream: null,
      grant: RtcMediaGrant.none,
      deniedKinds: ['camera', 'microphone'],
    );
  }
}
