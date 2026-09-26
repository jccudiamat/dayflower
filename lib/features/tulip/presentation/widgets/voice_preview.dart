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

/// A recorded voice note waiting on the composer: listen to it, scrub it,
/// throw it away, and type a caption to go with it.
///
/// 🔴 **A recording used to send the moment you stopped talking.** That is
/// the one message in the app you cannot skim before it goes, and it was
/// also the only one you could not say anything alongside. It waits here
/// now, exactly as a picked photo does, and the same Send button posts it.
class VoicePreview extends ConsumerStatefulWidget {
  const VoicePreview({
    super.key,
    required this.path,
    required this.length,
    required this.onRemove,
  });

  /// The file on this phone, not yet uploaded anywhere.
  final String path;
  final Duration length;
  final VoidCallback onRemove;

  @override
  ConsumerState<VoicePreview> createState() => _VoicePreviewState();
}

class _VoicePreviewState extends ConsumerState<VoicePreview> {
  /// What this holds in [playingVoiceProvider] while it plays.
  ///
  /// 🔴 There is one player on the phone. The preview used to play through
  /// it without saying so, so a voice note in the thread that was playing
  /// kept showing its pause button and counting while the preview had
  /// taken the speaker. Claiming the same slot the bubbles use means
  /// whichever starts last is the one that says it is playing.
  static const _slot = 'preview';

  bool _playing = false;
  Duration _at = Duration.zero;
  Timer? _ticker;
  StreamSubscription<void>? _ended;
  late final List<double> _wave = waveFor(widget.path, count: 40);

  /// The player slot, held from the start. ⚠️ Not looked up through `ref`
  /// when letting go: that happens in dispose too, where `ref` throws.
  late final StateController<String?> _player;

  @override
  void initState() {
    super.initState();
    _player = ref.read(playingVoiceProvider.notifier);
    _ended = VoiceNotes.playbackFinished.listen((_) {
      if (!mounted || !_playing) return;
      _stopTicking();
      setState(() {
        _playing = false;
        _at = Duration.zero;
      });
      _release();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ended?.cancel();
    // ⚠️ Stopped on the way out, or a preview left playing carries on after
    // the message has been sent and the bar has gone.
    if (_playing) {
      unawaited(VoiceNotes.stopPlaying());
      _release();
    }
    super.dispose();
  }

  /// Let go of the slot, if it is still ours. Deferred: this also runs from
  /// dispose, where providers must not be written synchronously.
  void _release() {
    final player = _player;
    Future.microtask(() {
      if (player.state == _slot) player.state = null;
    });
  }

  void _stopTicking() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _toggle() async {
    if (_playing) {
      await VoiceNotes.pause();
      _stopTicking();
      setState(() => _playing = false);
      _release();
      return;
    }
    try {
      // From the beginning again once it has run to the end, or once
      // something else has used the player in between.
      final ours = ref.read(playingVoiceProvider) == _slot;
      if (_at == Duration.zero || !ours) {
        await VoiceNotes.play(widget.path);
        _at = Duration.zero;
      } else {
        await VoiceNotes.resume();
      }
      if (!mounted) return;
      ref.read(playingVoiceProvider.notifier).state = _slot;
      setState(() => _playing = true);
      _ticker = Timer.periodic(const Duration(milliseconds: 120), (_) async {
        final where = await VoiceNotes.position();
        if (mounted) setState(() => _at = where.at);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
              const SnackBar(content: Text("Couldn't play that back.")));
      }
    }
  }

  Future<void> _scrub(double dx, double width) async {
    if (!_playing) return;
    final to = widget.length * (dx / width).clamp(0.0, 1.0);
    await VoiceNotes.seek(to);
    if (mounted) setState(() => _at = to);
  }

  @override
  Widget build(BuildContext context) {
    // A voice note in the thread took the player: this one has stopped, so
    // it should look stopped, and start again from the top next time.
    ref.listen<String?>(playingVoiceProvider, (previous, next) {
      if (previous == _slot && next != _slot && _playing) {
        _stopTicking();
        setState(() {
          _playing = false;
          _at = Duration.zero;
        });
      }
    });
    final total = widget.length.inMilliseconds;
    final progress =
        total <= 0 ? 0.0 : (_at.inMilliseconds / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 2),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: _playing ? 'Pause' : 'Play it back',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: _toggle,
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.cta,
                ),
                child: AppIcon(
                  _playing
                      ? CupertinoIcons.pause_fill
                      : CupertinoIcons.play_fill,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _scrub(d.localPosition.dx, box.maxWidth),
                onHorizontalDragUpdate: (d) =>
                    _scrub(d.localPosition.dx, box.maxWidth),
                child: SizedBox(
                  height: 28,
                  child: CustomPaint(
                    painter: VoiceBarsPainter(
                      samples: _wave,
                      barColor: AppColors.muted.withValues(alpha: .5),
                      // The bars already played, in brand pink.
                      playedColor: AppColors.brand,
                      played: progress,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            voiceLength(_at > Duration.zero ? widget.length - _at : widget.length),
            style: AppText.caption(AppColors.ink).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          Semantics(
            button: true,
            label: 'Delete this recording',
            excludeSemantics: true,
            child: IconButton(
              onPressed: widget.onRemove,
              iconSize: 18,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              constraints: const BoxConstraints(),
              icon: AppIcon(CupertinoIcons.trash, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
