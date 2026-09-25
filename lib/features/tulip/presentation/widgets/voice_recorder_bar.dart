import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../data/flower_repository.dart';
import '../../data/voice_notes.dart';

/// What the composer becomes while a voice message is being recorded: a red
/// dot, how long you have been talking, a level that moves with your voice,
/// and the two ways out.
///
/// 🔴 **Tap to start, tap to send — not hold-to-talk.** Holding is what
/// WhatsApp trained, and it is the worse gesture here: a two-minute message
/// means two minutes of holding still, a hand that slips loses the whole
/// thing, and nothing about it works for somebody who cannot hold a steady
/// press. The bar is also the only design where "cancel" is a visible
/// target rather than a swipe you have to know about.
class VoiceRecorderBar extends StatefulWidget {
  const VoiceRecorderBar({
    super.key,
    required this.onCancel,
    required this.onSend,
  });

  final VoidCallback onCancel;

  /// Given what was recorded. Null when nothing usable was captured.
  final void Function(({String path, Duration length})? recording) onSend;

  @override
  State<VoiceRecorderBar> createState() => _VoiceRecorderBarState();
}

class _VoiceRecorderBarState extends State<VoiceRecorderBar> {
  Duration _elapsed = Duration.zero;
  double _level = 0;
  Timer? _ticker;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 120), (_) async {
      final level = await VoiceNotes.amplitude();
      if (!mounted) return;
      final next = _elapsed + const Duration(milliseconds: 120);
      setState(() {
        _elapsed = next;
        // Eased toward the new reading rather than snapped to it, so the
        // bar breathes with a voice instead of flickering on every sample.
        _level = _level * .6 + level * .4;
      });
      // The recorder stops itself at the ceiling too; this is what sends
      // what it captured rather than leaving it hanging.
      if (next >= VoiceNotes.maxDuration) _finish();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _ticker?.cancel();
    final recording = await VoiceNotes.stopRecording();
    if (!mounted) return;
    // Too short to be anything but a mis-tap: thrown away rather than sent
    // as a quarter-second of room noise.
    if (recording == null || recording.length < VoiceNotes.minDuration) {
      widget.onSend(null);
      return;
    }
    widget.onSend(recording);
  }

  Future<void> _cancel() async {
    if (_finishing) return;
    _finishing = true;
    _ticker?.cancel();
    await VoiceNotes.cancelRecording();
    if (mounted) widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final left = VoiceNotes.maxDuration - _elapsed;
    final nearlyDone = left <= const Duration(seconds: 15);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Cancel voice message',
            excludeSemantics: true,
            child: IconButton(
              onPressed: _cancel,
              iconSize: 20,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              constraints: const BoxConstraints(),
              icon: const AppIcon(CupertinoIcons.trash, color: AppColors.danger),
            ),
          ),
          // Pulses, because a still red dot could be a decoration and this
          // has to read as "you are being recorded right now".
          _Pulse(level: _level),
          const SizedBox(width: 8),
          Text(
            voiceLength(_elapsed),
            style: AppText.body(AppColors.ink).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _Level(level: _level)),
          const SizedBox(width: 10),
          // Only near the end: a countdown running for the whole two minutes
          // would make an ordinary message feel timed.
          if (nearlyDone)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text('${left.inSeconds}s',
                  style: AppText.caption(AppColors.danger)),
            ),
          Semantics(
            button: true,
            label: 'Send voice message',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: _finish,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.cta,
                ),
                child: const AppIcon(CupertinoIcons.paperplane_fill,
                    size: 17, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pulse extends StatelessWidget {
  const _Pulse({required this.level});
  final double level;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 9 + level * 4,
        height: 9 + level * 4,
        decoration: const BoxDecoration(
          color: AppColors.danger,
          shape: BoxShape.circle,
        ),
      );
}

/// Your voice, as it is being captured. Not decoration: it is the only
/// evidence the microphone is actually hearing you, and a flat line while
/// someone talks is how you find out a recording is silent *before* sending
/// two minutes of nothing.
class _Level extends StatelessWidget {
  const _Level({required this.level});
  final double level;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          height: 6,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: AppColors.muted.withValues(alpha: .3)),
              ),
              FractionallySizedBox(
                widthFactor: level.clamp(0.04, 1.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  decoration: const BoxDecoration(gradient: AppGradients.cta),
                ),
              ),
            ],
          ),
        ),
      );
}
