import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../data/flower_repository.dart';
import '../../data/voice_notes.dart';
import 'voice_wave.dart';

/// What the composer becomes while a voice message is being recorded: how
/// long you have been talking, your voice as it is captured, a way to stop
/// for a moment, and the two ways out.
///
/// 🔴 **Tap to start, tap to stop — not hold-to-talk.** Holding is what
/// WhatsApp trained, and it is the worse gesture here: a two-minute message
/// means two minutes of holding still, a hand that slips loses the whole
/// thing, and nothing about it works for somebody who cannot hold a steady
/// press. It is also what makes pausing possible at all, and the bar is the
/// only design where "cancel" is a visible target rather than a swipe you
/// have to know about.
///
/// ⚠️ Stopping does not send. It hands the recording back to the composer,
/// where it waits as an attachment to be listened to and captioned — see
/// VoicePreview.
class VoiceRecorderBar extends StatefulWidget {
  const VoiceRecorderBar({
    super.key,
    required this.onCancel,
    required this.onSend,
  });

  final VoidCallback onCancel;

  /// Given what was recorded, for the composer to hold and preview. Null
  /// when nothing usable was captured.
  final void Function(({String path, Duration length})? recording) onSend;

  @override
  State<VoiceRecorderBar> createState() => _VoiceRecorderBarState();
}

class _VoiceRecorderBarState extends State<VoiceRecorderBar> {
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  bool _finishing = false;
  bool _paused = false;

  /// One bar per [_perBar] ticks, newest last.
  final _bars = <double>[];
  double _peak = 0;
  int _ticks = 0;

  /// How often loudness is sampled.
  static const _tick = Duration(milliseconds: 100);

  /// Ticks to a bar. Three is about a third of a second: fast enough that
  /// the row grows while you speak, slow enough that an ordinary message
  /// does not run off the end in seconds.
  static const _perBar = 3;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(_tick, (_) => _sample());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _sample() async {
    if (_paused || !mounted) return;
    final level = await VoiceNotes.amplitude();
    if (!mounted || _paused) return;
    final next = _elapsed + _tick;
    // A bar is the loudest moment in its slice, not the average: averaging
    // flattens speech into a straight line.
    _peak = level > _peak ? level : _peak;
    _ticks++;
    setState(() {
      _elapsed = next;
      if (_ticks >= _perBar) {
        _bars.add(_peak);
        _peak = 0;
        _ticks = 0;
      }
    });
    // The recorder stops itself at the ceiling too; this is what hands over
    // what it captured rather than leaving it hanging.
    if (next >= VoiceNotes.maxDuration) _finish();
  }

  Future<void> _togglePause() async {
    if (_finishing) return;
    if (_paused) {
      final at = await VoiceNotes.resumeRecording();
      if (!mounted) return;
      setState(() {
        _paused = false;
        _elapsed = at;
      });
      return;
    }
    final at = await VoiceNotes.pauseRecording();
    if (!mounted) return;
    setState(() {
      _paused = true;
      // ⚠️ From the recorder, not from this timer. A paused recorder writes
      // nothing, so only it knows how much audio there actually is, and a
      // timer that kept counting would promise seconds the file lacks.
      _elapsed = at;
    });
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _ticker?.cancel();
    final recording = await VoiceNotes.stopRecording();
    if (!mounted) return;
    // Too short to be anything but a mis-tap: thrown away rather than
    // handed over as a quarter-second of room noise.
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
      padding: const EdgeInsets.symmetric(horizontal: 4),
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
              iconSize: 19,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              constraints: const BoxConstraints(),
              icon:
                  const AppIcon(CupertinoIcons.trash, color: AppColors.danger),
            ),
          ),
          Text(
            voiceLength(_elapsed),
            style: AppText.caption(AppColors.ink).copyWith(
              fontSize: 13.5,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RepaintBoundary(
              child: LayoutBuilder(
                builder: (context, box) {
                  final slots = barsAcross(box.maxWidth);
                  // Scrolls once it reaches the end, so a long message keeps
                  // showing the part being said now.
                  final shown = _bars.length <= slots
                      ? _bars
                      : _bars.sublist(_bars.length - slots);
                  return CustomPaint(
                    size: Size(box.maxWidth, 26),
                    painter: VoiceBarsPainter(
                      samples: shown,
                      slots: slots,
                      // Greyed while paused: the row has stopped moving, and
                      // it should look stopped rather than merely still.
                      barColor: _paused ? AppColors.muted : AppColors.brand,
                      dotColor: AppColors.muted.withValues(alpha: .45),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Only near the end: a countdown running for the whole two minutes
          // would make an ordinary message feel timed.
          if (nearlyDone)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text('${left.inSeconds}s',
                  style: AppText.caption(AppColors.danger)),
            ),
          Semantics(
            button: true,
            label: _paused ? 'Carry on recording' : 'Pause recording',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: _togglePause,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                ),
                child: AppIcon(
                  _paused
                      ? CupertinoIcons.mic_fill
                      : CupertinoIcons.pause_fill,
                  size: 15,
                  color: _paused ? AppColors.danger : AppColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: 'Send voice message',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: _finish,
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.cta,
                ),
                child: const AppIcon(CupertinoIcons.checkmark_alt,
                    size: 18, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}
