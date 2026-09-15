import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/reminder_repository.dart';
import '../../domain/sticky_note.dart';

/// A reminder, as a note somebody pressed onto the fridge.
///
/// ## What makes it a note and not a card
///
/// Paper colour, a slight tilt, a folded corner, and ink instead of UI
/// text. The tilt is the one doing most of the work: a square card in a
/// coloured rectangle still reads as a list row, and two degrees off square
/// is the difference between "rendered" and "put there".
///
/// ⚠️ **Square-ish, deliberately.** A note is roughly as tall as it is wide;
/// a full-width tilted rectangle is a card with a rotation, not a sticky
/// note. That is why the wall on Reminders is two columns.
class StickyNoteCard extends StatelessWidget {
  const StickyNoteCard({
    super.key,
    required this.reminder,
    required this.isMine,
    required this.partnerName,
    required this.onToggle,
    required this.onTap,
    this.onMore,
  });

  final Reminder reminder;
  final bool isMine;
  final String partnerName;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  /// Long-press: sticking it on the home screen, nudging, and anything else
  /// a note has no room to show. Null on a note with nothing to offer.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final paper = stickyNotePaperFor(reminder.id);
    final tilt = stickyNoteTiltFor(reminder.id);
    final done = reminder.isDone;
    final overdue = reminder.isOverdue;

    return Transform.rotate(
      angle: tilt * math.pi / 180,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          // Long-press rather than buttons: a note has no room for them, and
          // both actions behind it — pinning to a home screen, reaching into
          // somebody's pocket — should be hard to trigger by accident.
          onLongPress: onMore,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            constraints: const BoxConstraints(minHeight: 132),
            decoration: BoxDecoration(
              color: paper.fill,
              // Barely rounded. Paper is cut, not moulded — the app's 18pt
              // card radius is what makes something look like a surface
              // rather than a sheet.
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: done ? .05 : .13),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            // A done note fades rather than disappearing: the wall is a
            // record of the week, and a note taken down leaves a gap that
            // reads as something lost.
            child: Opacity(
              opacity: done ? .55 : 1,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reminder.emoji,
                                style: const TextStyle(fontSize: 19)),
                            const Spacer(),
                            _Tick(
                              done: done,
                              ink: paper.ink,
                              onTap: onToggle,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          reminder.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.note(paper.ink).copyWith(
                            fontSize: 15.5,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                            decorationColor: paper.ink.withValues(alpha: .6),
                          ),
                        ),
                        if (reminder.note?.trim().isNotEmpty ?? false) ...[
                          const SizedBox(height: 3),
                          Text(
                            reminder.note!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption(
                              paper.ink.withValues(alpha: .72),
                            ).copyWith(fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 8),
                        _Footer(
                          reminder: reminder,
                          paper: paper,
                          isMine: isMine,
                          partnerName: partnerName,
                          overdue: overdue && !done,
                        ),
                      ],
                    ),
                  ),
                  // The folded corner. Two triangles: the paper turned over,
                  // and the shadow it casts on itself.
                  Positioned(
                    top: 0,
                    right: 0,
                    child: CustomPaint(
                      size: const Size(16, 16),
                      painter: _FoldPainter(paper: paper),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// When it is due, and whose it is — the two things you read off a note
/// without picking it up.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.reminder,
    required this.paper,
    required this.isMine,
    required this.partnerName,
    required this.overdue,
  });

  final Reminder reminder;
  final StickyNotePaper paper;
  final bool isMine;
  final String partnerName;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    // Overdue is the one state that breaks the paper's own palette. It has
    // to be readable as wrong at a glance across a wall of notes, and a
    // darker shade of the same ink is not.
    final tone = overdue ? AppColors.danger : paper.ink.withValues(alpha: .78);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              overdue ? CupertinoIcons.exclamationmark_circle : CupertinoIcons.clock,
              size: 11.5,
              color: tone,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                stickyNoteWhen(reminder.remindAt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption(tone).copyWith(
                  fontSize: 11.5,
                  fontWeight: overdue ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            if (reminder.repeats)
              Icon(CupertinoIcons.repeat,
                  size: 11, color: paper.ink.withValues(alpha: .55)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          isMine ? 'for you' : 'for $partnerName',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption(paper.ink.withValues(alpha: .5))
              .copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

/// The turned-up corner, which is what stops a coloured rectangle reading as
/// a swatch.
class _FoldPainter extends CustomPainter {
  const _FoldPainter({required this.paper});

  final StickyNotePaper paper;

  @override
  void paint(Canvas canvas, Size size) {
    // The underside of the paper, lit differently from the face.
    canvas.drawPath(
      Path()
        ..moveTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, 0)
        ..close(),
      Paint()..color = paper.edge,
    );
    // The crease, so the fold has a direction.
    canvas.drawLine(
      const Offset(0, 0),
      Offset(size.width, size.height),
      Paint()
        ..color = paper.ink.withValues(alpha: .10)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _FoldPainter old) => old.paper != paper;
}

/// The tick, drawn in the note's own ink rather than the app's accent — a
/// pen mark on paper, not a control sitting on top of it.
class _Tick extends StatelessWidget {
  const _Tick({required this.done, required this.ink, required this.onTap});

  final bool done;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: done,
      label: done ? 'Mark not done' : 'Mark done',
      child: GestureDetector(
        // Opaque so the whole 28pt square takes the tap, not just the ring.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.micro,
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? ink : Colors.transparent,
                border: Border.all(
                  color: ink.withValues(alpha: done ? 1 : .45),
                  width: 1.5,
                ),
              ),
              child: done
                  ? const Icon(CupertinoIcons.check_mark,
                      size: 13, color: Colors.white)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// "8:00 PM" / "Tomorrow 9am" / "Fri 12 Sep" — short enough for a note.
///
/// ⚠️ Deliberately shorter than the list's own `_friendlyWhen`. A note is
/// half the width of a row and is read at a glance across a wall; "Tomorrow,
/// 9:00 AM" wraps and stops being glanceable.
String stickyNoteWhen(DateTime at) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final days = day.difference(today).inDays;

  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final meridiem = at.hour < 12 ? 'am' : 'pm';
  final time = at.minute == 0
      ? '$hour$meridiem'
      : '$hour:${at.minute.toString().padLeft(2, '0')}$meridiem';

  if (days == 0) return time;
  if (days == 1) return 'Tomorrow $time';
  if (days == -1) return 'Yesterday $time';
  if (days > 1 && days < 7) return '${_weekday(day)} $time';
  if (days < 0) return '${_weekday(day)} ${day.day} ${_month(day)}';
  return '${day.day} ${_month(day)} $time';
}

String _weekday(DateTime d) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];

String _month(DateTime d) => const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ][d.month - 1];
