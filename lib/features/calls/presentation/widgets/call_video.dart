// `firstOrNull` resolves through livekit_client's own exports without this,
// which would make these widgets break on an unrelated SDK bump.
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/call_transport.dart';
import '../../data/livekit_call_transport.dart';
import '../../domain/call.dart';

/// The two pieces of a video call that are actual video.
///
/// **The only file above the data layer that imports LiveKit.** A video
/// frame is a texture, not a fact, so it cannot travel as a [CallEvent] the
/// way connection state does — this is the crack in the abstraction, and
/// keeping it to one file is what stops provider types leaking into the call
/// screen, the notifier and the thread.
///
/// Both widgets render a placeholder rather than nothing when there is no
/// track: the layout must be the real one whether or not a camera is on, or
/// turning video off would resize the whole screen.

/// Their camera, full-bleed behind everything else.
///
/// ⚠️ **Takes [session] purely so it cannot be `const`.** A const widget is
/// canonicalised, so Flutter sees an identical instance on every parent
/// rebuild and skips this subtree — which meant both video widgets read
/// `transport.room` once, at first build, while it was still null (the room
/// is created inside `join()`), and never looked again. The self-view stayed
/// a placeholder for the whole call. The session changes every second from
/// the timer, so taking it here is what makes these rebuild at all.
class RemoteVideo extends ConsumerWidget {
  const RemoteVideo({super.key, required this.session});

  final CallSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = _roomOf(ref);
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

        // No track is the normal state for most of a call's life: before
        // they join, and any time they turn the camera off. The stage stays,
        // so the controls never move.
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
    final room = _roomOf(ref);

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
          child: room == null
              ? const _SelfPlaceholder()
              : ListenableBuilder(
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
                      // Your own view is mirrored, the way a mirror is and
                      // the way every other video app shows it. The outgoing
                      // track is not — see § Selfies stopped coming out
                      // mirrored in PROGRESS.md for the same distinction on
                      // the camera.
                      mirrorMode: lk.VideoViewMirrorMode.mirror,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// The transport's room, or null when this build has no media provider —
/// which is what every screen falls back to gracefully.
lk.Room? _roomOf(WidgetRef ref) {
  final transport = ref.watch(callTransportProvider);
  return transport is LiveKitCallTransport ? transport.room : null;
}

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
      child: Icon(
        Icons.videocam_off_rounded,
        size: 22,
        color: AppColors.onDark.withValues(alpha: .35),
      ),
    );
  }
}
