import 'package:dayflower/core/widgets/app_icon.dart';
// `firstOrNull` resolves through livekit_client's own exports without this,
// which would make these widgets break on an unrelated SDK bump.
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/call_transport.dart';
import '../../data/livekit_call_transport.dart';
import '../../data/peer_call_transport.dart';
import '../../domain/call.dart';

/// The two pieces of a video call that are actual video.
///
/// **The only file above the data layer that imports a transport's types.** A
/// video frame is a texture, not a fact, so it cannot travel as a
/// [CallEvent] the way connection state does — this is the crack in the
/// abstraction, and keeping it to one file is what stops those types leaking
/// into the call screen, the notifier and the thread.
///
/// It now has to know about two: [PeerCallTransport], which is what ships,
/// and [LiveKitCallTransport], which `CALL_TRANSPORT=livekit` puts back.
///
/// Both widgets render a placeholder rather than nothing when there is no
/// track: the layout must be the real one whether or not a camera is on, or
/// turning video off would resize the whole screen.

/// Their camera, full-bleed behind everything else.
///
/// ⚠️ **Takes [session] purely so it cannot be `const`.** A const widget is
/// canonicalised, so Flutter sees an identical instance on every parent
/// rebuild and skips this subtree — which meant both video widgets read the
/// transport's state once, at first build, while it was still empty (the
/// media is created inside `join()`), and never looked again. The self-view
/// stayed a placeholder for the whole call. The session changes every second
/// from the timer, so taking it here is what makes these rebuild at all.
class RemoteVideo extends ConsumerWidget {
  const RemoteVideo({super.key, required this.session});

  final CallSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transport = ref.watch(callTransportProvider);

    if (transport is PeerCallTransport) {
      return ValueListenableBuilder<int>(
        valueListenable: transport.tracks,
        builder: (context, _, __) {
          final stream = transport.remoteStream;
          // No stream is the normal state for most of a call's life: before
          // they answer, and any time they turn the camera off. The stage
          // stays, so the controls never move.
          if (stream == null || stream.getVideoTracks().isEmpty) {
            return const _Stage();
          }
          return _PeerVideo(stream: stream, placeholder: const _Stage());
        },
      );
    }

    final room = _roomOf(transport);
    if (room == null) return const _Stage();

    return ListenableBuilder(
      listenable: room,
      builder: (context, _) {
        final track = room.remoteParticipants.values
            .expand((p) => p.videoTrackPublications)
            .where((pub) => pub.subscribed && !pub.muted)
            .map((pub) => pub.track)
            .whereType<lk.VideoTrack>()
            .firstOrNull;

        if (track == null) return const _Stage();
        return lk.VideoTrackRenderer(
          track,
          fit: lk.VideoViewFit.cover,
        );
      },
    );
  }
}

/// Your own camera, in the corner.
///
/// See [RemoteVideo] on why this takes a session it barely reads.
class LocalVideo extends ConsumerWidget {
  const LocalVideo({
    super.key,
    required this.session,
    this.width = 74,
    this.height = 104,
  });

  final CallSession session;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transport = ref.watch(callTransportProvider);

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.darkRaised,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: AppColors.onDark.withValues(alpha: .16),
              width: 1.5,
            ),
          ),
          child: _self(transport),
        ),
      ),
    );
  }

  Widget _self(CallTransport transport) {
    // Your own view is mirrored, the way a mirror is and the way every other
    // video app shows it. The outgoing track is not — see § Selfies stopped
    // coming out mirrored in PROGRESS.md for the same distinction on the
    // camera.
    //
    // ⚠️ **Front camera only.** A mirror is what you expect of your own
    // face; pointing the back camera at a room and seeing it reversed is
    // just wrong, and every camera app on the phone agrees.
    if (transport is PeerCallTransport) {
      return ValueListenableBuilder<int>(
        valueListenable: transport.tracks,
        builder: (context, _, __) {
          final stream = transport.localStream;
          final live = stream != null &&
              stream.getVideoTracks().any((t) => t.enabled);
          if (!live) return const _SelfPlaceholder();
          return _PeerVideo(
            stream: stream,
            mirror: session.cameraFront,
            placeholder: const _SelfPlaceholder(),
          );
        },
      );
    }

    final room = _roomOf(transport);
    if (room == null) return const _SelfPlaceholder();
    return ListenableBuilder(
      listenable: room,
      builder: (context, _) {
        final track = room.localParticipant?.videoTrackPublications
            .where((pub) => !pub.muted)
            .map((pub) => pub.track)
            .whereType<lk.VideoTrack>()
            .firstOrNull;
        if (track == null) return const _SelfPlaceholder();
        return lk.VideoTrackRenderer(
          track,
          fit: lk.VideoViewFit.cover,
          mirrorMode: session.cameraFront
              ? lk.VideoViewMirrorMode.mirror
              : lk.VideoViewMirrorMode.off,
        );
      },
    );
  }
}

/// One WebRTC stream on screen.
///
/// ⚠️ Stateful because a renderer is a native texture: it has to be created,
/// initialised and given back. A widget that built one in `build` would leak
/// one per frame.
class _PeerVideo extends StatefulWidget {
  const _PeerVideo({
    required this.stream,
    required this.placeholder,
    this.mirror = false,
  });

  final rtc.MediaStream stream;
  final Widget placeholder;
  final bool mirror;

  @override
  State<_PeerVideo> createState() => _PeerVideoState();
}

class _PeerVideoState extends State<_PeerVideo> {
  final _renderer = rtc.RTCVideoRenderer();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await _renderer.initialize();
      if (!mounted) return;
      _renderer.srcObject = widget.stream;
      setState(() => _ready = true);
    } catch (e) {
      debugPrint('video renderer failed: $e');
    }
  }

  @override
  void didUpdateWidget(covariant _PeerVideo old) {
    super.didUpdateWidget(old);
    // The same renderer, pointed at the new stream: rebuilding it would
    // flash black every time the camera was toggled.
    if (_ready && widget.stream.id != old.stream.id) {
      _renderer.srcObject = widget.stream;
    }
  }

  @override
  void dispose() {
    _renderer.srcObject = null;
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return widget.placeholder;
    return rtc.RTCVideoView(
      _renderer,
      mirror: widget.mirror,
      objectFit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      placeholderBuilder: (_) => widget.placeholder,
    );
  }
}

/// The transport's room, or null when this build is not on the media server.
lk.Room? _roomOf(CallTransport transport) =>
    transport is LiveKitCallTransport ? transport.room : null;

/// What sits behind a call with no incoming picture: the plum hero gradient,
/// not black. A black rectangle reads as a broken video; this reads as the
/// app, waiting.
class _Stage extends StatelessWidget {
  const _Stage();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: AppGradients.hero),
      child: SizedBox.expand(),
    );
  }
}

class _SelfPlaceholder extends StatelessWidget {
  const _SelfPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppIcon(
        Icons.videocam_off_rounded,
        size: 22,
        color: AppColors.onDark.withValues(alpha: .35),
      ),
    );
  }
}
