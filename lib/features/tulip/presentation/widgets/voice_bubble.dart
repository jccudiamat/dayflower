import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../data/flower_repository.dart';
import '../../data/voice_notes.dart';
import 'voice_wave.dart';

/// A voice message in the thread: play, a bar you can scrub, and its length.
///
/// ⚠️ **The curve is not the sound.** Drawing a real waveform would mean
/// downloading and decoding every voice note in the thread just to render
/// it, which is a lot of bytes and battery for decoration. It is a fixed
/// shape derived from the message id, so each note looks like itself and
/// nothing has to be fetched to draw one. The honest information is the
/// length and the progress, and both are real. See waveFor.
class VoiceBubble extends ConsumerStatefulWidget {
  const VoiceBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.meta,
  });

  final FlowerMessage message;
  final bool isMine;

  /// The time and ticks row, built by the bubble that owns this.
  final Widget meta;

  @override
  ConsumerState<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends ConsumerState<VoiceBubble> {
  Duration _at = Duration.zero;
  bool _loading = false;
  late final List<double> _wave = waveFor(_id, count: 26);
  Timer? _ticker;
  StreamSubscription<void>? _ended;

  String get _id => widget.message.id;
  Duration get _length => widget.message.audioLength;

  @override
  void initState() {
    super.initState();
    _ended = VoiceNotes.playbackFinished.listen((_) {
      // Only ours: one player, and whichever bubble owns it is the one that
      // should reset.
      if (!mounted || ref.read(playingVoiceProvider) != _id) return;
      _stopTicking();
      setState(() => _at = Duration.zero);
      ref.read(playingVoiceProvider.notifier).state = null;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ended?.cancel();
    super.dispose();
  }

  void _stopTicking() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _startTicking() {
    _stopTicking();
    _ticker = Timer.periodic(const Duration(milliseconds: 120), (_) async {
      final where = await VoiceNotes.position();
      if (!mounted) return;
      setState(() => _at = where.at);
    });
  }

  Future<void> _toggle() async {
    final playing = ref.read(playingVoiceProvider) == _id;
    if (playing) {
      await VoiceNotes.pause();
      _stopTicking();
      ref.read(playingVoiceProvider.notifier).state = null;
      return;
    }

    // One voice at a time, everywhere.
    if (ref.read(playingVoiceProvider) != null) await VoiceNotes.stopPlaying();

    setState(() => _loading = true);
    try {
      final path = widget.message.audioPath;
      if (path == null) return;
      final repo = ref.read(flowerRepositoryProvider);
      final local =
          await VoiceNoteFiles.local(path, () => repo.downloadVoiceNote(path));
      if (!mounted || local == null) {
        if (mounted) _say("Couldn't play that. Try again?");
        return;
      }
      await VoiceNotes.play(local);
      if (!mounted) return;
      ref.read(playingVoiceProvider.notifier).state = _id;
      _startTicking();
    } catch (e) {
      if (mounted) _say("Couldn't play that. Try again?");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    // Someone else took the player — another note, or the preview of a
    // recording. Stop counting, or this bubble keeps moving its bar along
    // with a voice that is no longer its own.
    ref.listen<String?>(playingVoiceProvider, (previous, next) {
      if (previous == _id && next != _id) {
        _stopTicking();
        if (mounted) setState(() => _at = Duration.zero);
      }
    });
    final playing = ref.watch(playingVoiceProvider) == _id;
    final total = _length.inMilliseconds;
    final progress =
        total <= 0 ? 0.0 : (_at.inMilliseconds / total).clamp(0.0, 1.0);
    final ink = AppColors.ink;
    final tint = widget.isMine ? AppColors.brand : AppColors.secondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: true,
                label: playing ? 'Pause voice message' : 'Play voice message',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: _loading ? null : _toggle,
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : AppIcon(
                            playing
                                ? CupertinoIcons.pause_fill
                                : CupertinoIcons.play_fill,
                            size: 16,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Scrubbing: the bar is the position, so dragging it moves
              // playback. Only meaningful once it is playing, and harmless
              // before.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _scrub(d.localPosition.dx),
                onHorizontalDragUpdate: (d) => _scrub(d.localPosition.dx),
                child: SizedBox(
                  width: _barsWidth,
                  height: 26,
                  child: CustomPaint(
                    painter: VoiceBarsPainter(
                      samples: _wave,
                      barColor: AppColors.muted.withValues(alpha: .5),
                      playedColor: tint,
                      played: progress,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                // Counts down while playing, the way a player does, and
                // shows the whole length at rest.
                voiceLength(playing || _at > Duration.zero
                    ? (_length - _at)
                    : _length),
                style: AppText.caption(ink).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          // What they wrote alongside it, if anything.
          if ((widget.message.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text((widget.message.note ?? '').trim(),
                style: AppText.body(AppColors.ink)),
          ],
          const SizedBox(height: 2),
          widget.meta,
        ],
      ),
    );
  }

  static const _barsWidth = 118.0;

  Future<void> _scrub(double dx) async {
    if (ref.read(playingVoiceProvider) != _id) return;
    final fraction = (dx / _barsWidth).clamp(0.0, 1.0);
    final to = _length * fraction;
    await VoiceNotes.seek(to);
    if (mounted) setState(() => _at = to);
  }
}
