import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../chapters/data/chapter_repository.dart';

/// A tactile book cover. The reflection remains real, selectable-size UI text
/// below the decorative cover rather than being baked into an image.
class JournalBookPreview extends StatelessWidget {
  const JournalBookPreview({
    super.key,
    required this.latest,
    required this.hasUnwrittenMonth,
    required this.onTap,
  });

  final MonthlyChapter? latest;
  final bool hasUnwrittenMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          button: true,
          label: 'Open your shared journal',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 270),
                  child: AspectRatio(
                    aspectRatio: .78,
                    child: ExcludeSemantics(
                      child: Transform.rotate(
                        angle: -.035,
                        child: CustomPaint(
                          painter: const _VintageBookPainter(),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(47, 45, 37, 45),
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('THE STORY OF US',
                                      style: AppText.label(_gold)
                                          .copyWith(letterSpacing: 2)),
                                  const SizedBox(height: 24),
                                  const Icon(Icons.local_florist_outlined,
                                      color: _gold, size: 42),
                                  const SizedBox(height: 20),
                                  Text('Our Journal',
                                      style: AppText.hero(_gold).copyWith(
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 14),
                                  Text('Little moments, kept forever',
                                      style: AppText.caption(_gold).copyWith(
                                          fontStyle: FontStyle.italic)),
                                  const SizedBox(height: 28),
                                  Text('DAYFLOWER',
                                      style: AppText.label(_gold).copyWith(
                                          fontSize: 9, letterSpacing: 3)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          latest == null
              ? 'Your story, month by month'
              : DateFormat('MMMM yyyy').format(latest!.key.firstDay),
          textAlign: TextAlign.center,
          style: AppText.subtitle(),
        ),
        const SizedBox(height: 8),
        if (latest?.title?.trim().isNotEmpty ?? false) ...[
          Text(latest!.title!,
              textAlign: TextAlign.center, style: AppText.subtitle()),
          const SizedBox(height: 8),
        ],
        Text(
          latest?.review ??
              'A place for your moments, reflections and shared goals.',
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppText.body(),
        ),
        if (hasUnwrittenMonth) ...[
          const SizedBox(height: 10),
          Text('Last month is ready for your reflection',
              textAlign: TextAlign.center, style: AppText.caption()),
        ],
      ],
    );
  }
}

const _gold = Color(0xFFE6C98E);

class _VintageBookPainter extends CustomPainter {
  const _VintageBookPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cover = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, w - 8, h - 14),
      topLeft: const Radius.circular(6),
      bottomLeft: const Radius.circular(6),
      topRight: const Radius.circular(14),
      bottomRight: const Radius.circular(14),
    );
    final pages = RRect.fromRectAndRadius(
        Rect.fromLTWH(10, 12, w - 12, h - 18), const Radius.circular(10));
    canvas.drawShadow(
        Path()..addRRect(pages), const Color(0x66311C10), 12, true);
    canvas.drawRRect(pages, Paint()..color = const Color(0xFFD2BD95));
    final pageInk = Paint()
      ..color = const Color(0xFFF6E9CD)
      ..strokeWidth = 1;
    for (double y = h - 15; y < h - 6; y += 2) {
      canvas.drawLine(Offset(17, y), Offset(w - 12, y), pageInk);
    }
    for (double x = w - 8; x < w - 1; x += 2) {
      canvas.drawLine(Offset(x, 25), Offset(x, h - 17), pageInk);
    }
    final ribbon = Path()
      ..moveTo(w * .74, h - 24)
      ..lineTo(w * .81, h - 24)
      ..lineTo(w * .81, h + 6)
      ..lineTo(w * .775, h)
      ..lineTo(w * .74, h + 6)
      ..close();
    canvas.drawPath(ribbon, Paint()..color = const Color(0xFF9E4D49));
    canvas.drawRRect(
        cover,
        Paint()
          ..shader = const LinearGradient(colors: [
            Color(0xFF16342E),
            Color(0xFF35594A),
            Color(0xFF264639),
            Color(0xFF193C32),
          ], stops: [
            0,
            .14,
            .45,
            1
          ]).createShader(cover.outerRect));
    canvas.save();
    canvas.clipRRect(cover);
    // Fine woven cover grain, deterministic across repaints.
    final grain = Paint()
      ..color = const Color(0x0FE6C98E)
      ..strokeWidth = .45;
    for (double x = 0; x < w; x += 3) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grain);
    }
    for (double y = 0; y < h; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grain);
    }
    canvas.drawRect(
        Rect.fromLTWH(0, 0, 17, h), Paint()..color = const Color(0x44201C12));
    canvas.drawLine(
        const Offset(18, 0),
        Offset(18, h),
        Paint()
          ..color = const Color(0x44302A12)
          ..strokeWidth = 2);
    final foil = Paint()
      ..color = _gold.withValues(alpha: .68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9;
    for (final inset in [0.0, 5.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(
                  29 + inset, 18 + inset, w - 21 - inset, h - 33 - inset),
              const Radius.circular(7)),
          foil);
    }
    // Engraved corner leaves and simple spine bands.
    for (final y in [28.0, h - 45]) {
      canvas.drawLine(Offset(2, y), Offset(14, y), foil);
      for (final x in [40.0, w - 34]) {
        canvas.save();
        canvas.translate(x, y + (y < h / 2 ? 5 : -5));
        canvas.rotate(math.pi / 4);
        canvas.drawOval(const Rect.fromLTWH(-3, -7, 6, 14), foil);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VintageBookPainter oldDelegate) => false;
}
