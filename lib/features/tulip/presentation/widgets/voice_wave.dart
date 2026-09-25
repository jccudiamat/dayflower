import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A voice, drawn the way a voice memo is drawn: thin rounded bars, one per
/// slice of time, with a dotted line running on where nothing has been
/// recorded yet.
///
/// ⚠️ **Bars, not a filled curve.** A curve reads as a level meter — a
/// machine watching you — and it hides how long the recording is. Bars are
/// a count of moments as well as a picture of loudness, and the dotted tail
/// says plainly that there is more room left.
class VoiceBarsPainter extends CustomPainter {
  VoiceBarsPainter({
    required this.samples,
    required this.barColor,
    this.playedColor,
    this.played = 0,
    this.dotColor,
    this.slots,
  });

  /// Loudness per bar, 0 to 1, oldest first.
  final List<double> samples;

  /// The bars themselves.
  final Color barColor;

  /// The part already played, when this is a finished recording. Null draws
  /// every bar in [barColor].
  final Color? playedColor;

  /// How far through, 0 to 1.
  final double played;

  /// The dotted line for the room that is left. Null draws no tail, which
  /// is right for a finished note: there is nothing still to come.
  final Color? dotColor;

  /// How many bars the width holds. Defaults to as many as there are
  /// samples, so a finished note fills its box.
  final int? slots;

  /// Bar plus the gap after it. Thin and tightly spaced, as a voice memo is.
  static const _pitch = 4.5;
  static const _width = 2.2;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final total = slots ?? math.max(1, samples.length);
    final middle = size.height / 2;
    // Centred: with a fixed pitch the bars rarely fill the width exactly,
    // and a row hard against the left edge with a gap at the right looks
    // like a mistake.
    final used = total * _pitch;
    final left = math.max(0.0, (size.width - used) / 2);

    final bar = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _width;

    final playedBars = (samples.length * played).round();

    for (var i = 0; i < samples.length && i < total; i++) {
      // Never quite zero: a silent moment is a dot on the line, not a gap.
      final height = math.max(0.06, samples[i].clamp(0.0, 1.0)) * middle;
      final x = left + i * _pitch + _pitch / 2;
      bar.color = playedColor != null && i < playedBars
          ? playedColor!
          : barColor;
      canvas.drawLine(
          Offset(x, middle - height), Offset(x, middle + height), bar);
    }

    final dots = dotColor;
    if (dots == null || samples.length >= total) return;

    // The room that is left, as a dotted rule along the middle.
    final dot = Paint()
      ..color = dots
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    // Every other slot, so the dots sit in the rhythm the bars would have.
    for (var i = samples.length; i < total; i += 2) {
      final x = left + i * _pitch + _pitch / 2;
      canvas.drawLine(Offset(x, middle), Offset(x + .6, middle), dot);
    }
  }

  @override
  bool shouldRepaint(VoiceBarsPainter old) =>
      old.samples != samples ||
      old.played != played ||
      old.barColor != barColor ||
      old.playedColor != playedColor ||
      old.dotColor != dotColor ||
      old.slots != slots;
}

/// How many bars fit across [width].
int barsAcross(double width) =>
    math.max(1, (width / VoiceBarsPainter._pitch).floor());

/// The shape a finished voice note keeps, derived from its id.
///
/// ⚠️ Not the real sound. Drawing that would mean downloading and decoding
/// every note in the thread just to render one, which is a lot of bytes and
/// battery for decoration. This is stable per message, so a note looks the
/// same on both phones and after a restart, and the honest information —
/// the length and the progress through it — is real.
List<double> waveFor(String seed, {int count = 42}) {
  final random = math.Random(seed.hashCode);
  final out = <double>[];
  var last = .45;
  for (var i = 0; i < count; i++) {
    // A walk rather than independent draws: speech rises and falls in
    // syllables, and independent noise looks like static.
    last = (last + (random.nextDouble() - .5) * .6).clamp(.12, 1.0);
    // Tapered at both ends, the way a recording starts and stops.
    final edge = math.min(i, count - 1 - i) / (count * .12);
    out.add(last * math.min(1.0, math.max(0.3, edge)));
  }
  return out;
}
