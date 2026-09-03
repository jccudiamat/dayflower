import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../home/presentation/widgets/clocks_card.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../../us/domain/couple_dates.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/feature_screen_header.dart';

// ═══════════════════════════════════════════════════
//   EVENT MODEL
// ═══════════════════════════════════════════════════
//
// One list, one model. A reunion is an event whose kind is `reunion` —
// it is not a separate object with its own editor. The soonest upcoming
// entry is what the hero countdown renders.

enum _EventKind { reunion, anniversary, birthday, monthsary, custom }

class _KindStyle {
  const _KindStyle({
    required this.label,
    required this.icon,
    required this.emoji,
    required this.color,
  });
  final String label;
  final IconData icon;
  final String emoji;
  final Color color;
}

const Map<_EventKind, _KindStyle> _kindStyles = {
  _EventKind.reunion: _KindStyle(
      label: 'Reunion',
      icon: CupertinoIcons.airplane,
      emoji: '✈️',
      color: AppColors.secondary),
  _EventKind.anniversary: _KindStyle(
      label: 'Anniversary',
      icon: CupertinoIcons.heart_fill,
      emoji: '💞',
      color: AppColors.brand),
  _EventKind.birthday: _KindStyle(
      label: 'Birthday',
      icon: CupertinoIcons.gift_fill,
      emoji: '🎂',
      color: AppColors.amber),
  _EventKind.monthsary: _KindStyle(
      label: 'Monthsary',
      icon: CupertinoIcons.calendar,
      emoji: '🌷',
      color: AppColors.sage),
  _EventKind.custom: _KindStyle(
      label: 'Custom',
      icon: CupertinoIcons.star_fill,
      emoji: '⭐',
      color: AppColors.muted),
};

class _Event {
  _Event({
    required this.id,
    required this.kind,
    required this.emoji,
    required this.title,
    required this.date,
    this.location = '',
    this.note = '',
  });

  final int id;
  _EventKind kind;
  String emoji, title, date, location, note;

  DateTime? get when => DateTime.tryParse(date);
  _KindStyle get style => _kindStyles[kind]!;
  Color get color => style.color;

  _Event copyWith({
    _EventKind? kind,
    String? emoji,
    String? title,
    String? date,
    String? location,
    String? note,
  }) =>
      _Event(
        id: id,
        kind: kind ?? this.kind,
        emoji: emoji ?? this.emoji,
        title: title ?? this.title,
        date: date ?? this.date,
        location: location ?? this.location,
        note: note ?? this.note,
      );
}

// ═══════════════════════════════════════════════════
//   DATE HELPERS
// ═══════════════════════════════════════════════════

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Whole calendar days from today to [target] — negative once it has passed.
int _daysUntil(DateTime target) =>
    _startOfDay(target).difference(_startOfDay(DateTime.now())).inDays;

String _daysLabel(DateTime target) {
  final d = _daysUntil(target);
  if (d < 0) return 'Passed';
  if (d == 0) return 'Today!';
  if (d == 1) return 'Tomorrow';
  return '$d days';
}

String _formatDate(DateTime d) => DateFormat('MMMM d, yyyy').format(d);

class _Countdown {
  const _Countdown({
    required this.days,
    required this.hrs,
    required this.mins,
    required this.secs,
  });
  final int days, hrs, mins, secs;
}

_Countdown _countdownTo(DateTime target, DateTime now) {
  final diff = target.difference(now);
  if (diff.isNegative) {
    return const _Countdown(days: 0, hrs: 0, mins: 0, secs: 0);
  }
  return _Countdown(
    days: diff.inDays,
    hrs: diff.inHours % 24,
    mins: diff.inMinutes % 60,
    secs: diff.inSeconds % 60,
  );
}

// ═══════════════════════════════════════════════════
//   CYCLE (mock)
// ═══════════════════════════════════════════════════
//
// No backend exists for this yet. Everything below derives from one
// anchor date, so the calendar, the stats and the tips can never
// disagree with each other the way hardcoded values did.

enum _Phase { period, fertile, ovulation, pms }

class _PhaseInfo {
  const _PhaseInfo({
    required this.color,
    required this.label,
    required this.icon,
    required this.tip,
  });
  final Color color;
  final String label;
  final IconData icon;
  final String tip;
}

const Map<_Phase, _PhaseInfo> _phaseData = {
  _Phase.period: _PhaseInfo(
      color: AppColors.period,
      label: 'Period',
      icon: CupertinoIcons.heart_fill,
      tip: 'Warm hugs, snacks, a heating pad.'),
  _Phase.fertile: _PhaseInfo(
      color: AppColors.fertile,
      label: 'Fertile',
      icon: CupertinoIcons.sparkles,
      tip: 'High energy — great mood likely.'),
  _Phase.ovulation: _PhaseInfo(
      color: AppColors.ovulation,
      label: 'Ovulation',
      icon: CupertinoIcons.sun_max_fill,
      tip: 'She may feel her best today.'),
  _Phase.pms: _PhaseInfo(
      color: AppColors.pms,
      label: 'PMS',
      icon: CupertinoIcons.moon_fill,
      tip: 'Extra patience goes a long way.'),
};

const _cycleLength = 28;
const _periodLength = 5;

/// Mock anchor: the current period started 15 days ago.
final _cycleAnchor =
    _startOfDay(DateTime.now()).subtract(const Duration(days: 15));

/// 1-based day within the cycle.
int _cycleDay(DateTime d) {
  final delta = _startOfDay(d).difference(_cycleAnchor).inDays;
  return (delta % _cycleLength + _cycleLength) % _cycleLength + 1;
}

_Phase? _phaseOn(DateTime d) {
  final day = _cycleDay(d);
  if (day <= _periodLength) return _Phase.period;
  if (day == 14) return _Phase.ovulation;
  if (day >= 12 && day <= 16) return _Phase.fertile;
  if (day >= 23) return _Phase.pms;
  return null;
}

// ═══════════════════════════════════════════════════
//   EVENTS SCREEN — one page, no tabs
// ═══════════════════════════════════════════════════

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  // Cycle section
  bool _cycleOpen = false;
  String _cycleRole = 'me';
  DateTime? _selDay;
  bool _shared = true;

  // Names still drive the cycle section's copy. The clocks that used to live
  // here moved to the top of Home — that pair was a mock duplicate of the
  // real ClocksCard, which reads actual profile timezones.
  static const String _myName = 'Bunny';
  static const String _partnerName = 'Sunshine';

  // Mock seed data, anchored relative to today so the countdown is always
  // live rather than expiring against hardcoded 2026 dates.
  //
  // 🔴 Still mock, and still not persisted anywhere — see the note in
  // PROGRESS.md. `_derived` below is the only part of this screen backed by
  // real data.
  late List<_Event> _manual;

  /// Everything the list shows: the couple's real milestones first, then
  /// whatever has been added by hand.
  ///
  /// The monthsary and the anniversary are **derived, not stored**. They
  /// come from one date on the pair row, so there is nothing to keep in
  /// step and nothing to get out of step: change the start date and both
  /// move. That is also why they cannot be edited or deleted here — there
  /// is no row behind them to change. Editing the start date on Us is the
  /// way to change them, which is where it belongs.
  List<_Event> get _events => [..._derived, ..._manual];

  /// Negative ids, so [_openEventSheet] can tell a derived milestone from
  /// a real entry without carrying a second flag through the whole screen.
  static const int _monthsaryId = -1;
  static const int _anniversaryId = -2;

  List<_Event> get _derived {
    final start =
        ref.watch(currentPairProvider).valueOrNull?.togetherSince;
    // Nothing is invented before the couple has said when they started.
    if (start == null) return const [];

    final now = DateTime.now();
    final monthsary = nextMonthsary(start, now);
    final anniversary = nextAnniversary(start, now);

    return [
      _Event(
        id: _monthsaryId,
        kind: _EventKind.monthsary,
        emoji: _kindStyles[_EventKind.monthsary]!.emoji,
        title: '${monthsBetween(start, monthsary)} Month Monthsary',
        date: _iso(monthsary),
      ),
      _Event(
        id: _anniversaryId,
        kind: _EventKind.anniversary,
        emoji: _kindStyles[_EventKind.anniversary]!.emoji,
        title:
            '${anniversaryNumber(start, anniversary)} Year Anniversary',
        date: _iso(anniversary),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    final today = _startOfDay(DateTime.now());
    // The mock anniversary and monthsary that used to sit here are gone:
    // both are derived from the pair's start date now, and keeping the
    // fakes would have shown each of them twice, on two different days.
    _manual = [
      _Event(
        id: 1,
        kind: _EventKind.birthday,
        emoji: '🎂',
        title: "$_partnerName's Birthday",
        date: _iso(today.add(const Duration(days: 21))),
      ),
      _Event(
        id: 3,
        kind: _EventKind.reunion,
        emoji: '✈️',
        title: 'Tokyo Reunion',
        date: _iso(today.add(const Duration(days: 84))),
        location: 'Tokyo, Japan 🇯🇵',
        note: "Can't wait to hold you again.",
      ),
    ];
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Derived lists ──────────────────────────────────

  List<_Event> get _sorted {
    final list = _events.where((e) => e.when != null).toList()
      ..sort((a, b) => a.when!.compareTo(b.when!));
    return list;
  }

  List<_Event> get _upcoming =>
      _sorted.where((e) => _daysUntil(e.when!) >= 0).toList();

  List<_Event> get _passed =>
      _sorted.where((e) => _daysUntil(e.when!) < 0).toList().reversed.toList();

  _Event? get _next => _upcoming.isEmpty ? null : _upcoming.first;

  // ── Sheets ─────────────────────────────────────────

  Future<void> _openEventSheet(_Event? event) async {
    // A derived milestone has no row behind it, so there is nothing here to
    // edit or delete. Saying where it *does* change beats a disabled tap
    // that leaves you guessing.
    if (event != null && event.id < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This comes from your start date — change it on Us.'),
        ),
      );
      return;
    }

    final isNew = event == null;
    final draft = event ??
        _Event(
          id: DateTime.now().millisecondsSinceEpoch,
          kind: _EventKind.custom,
          emoji: _kindStyles[_EventKind.custom]!.emoji,
          title: '',
          date: '',
        );
    final result = await showModalBottomSheet<(bool, _Event)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditEventSheet(event: draft, isNew: isNew),
    );
    if (result == null) return;
    final (deleted, saved) = result;
    setState(() {
      if (deleted) {
        _manual = _manual.where((e) => e.id != saved.id).toList();
      } else if (isNew) {
        _manual = [..._manual, saved];
      } else {
        _manual = _manual.map((e) => e.id == saved.id ? saved : e).toList();
      }
    });
  }

  // ── Build ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final next = _next;
    final alsoComing = _upcoming.skip(1).toList();
    final passed = _passed;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.sm, AppSpace.sm, AppSpace.sm, 0),
              child: FeatureScreenHeader(
                title: 'Events',
                subtitle: 'Countdowns, milestones and cycle',
                trailing: _AddButton(onTap: () => _openEventSheet(null)),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.sm, 0, AppSpace.sm, AppSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 0. What time is it where they are ──
                    // Moved off Home 2026-09-01: the greeting there now
                    // carries the partner's city and local time, so the
                    // clocks were saying the same thing twice. Dates is
                    // where "when" already lives.
                    const ClocksCard(),
                    const SizedBox(height: AppSpace.sm),

                    // ── 1. The next thing you're waiting for ──
                    _NextUpCard(
                      event: next,
                      now: _now,
                      onEdit: () {
                        if (next != null) _openEventSheet(next);
                      },
                      onAdd: () => _openEventSheet(null),
                    ),
                    const SizedBox(height: AppSpace.sm),

                    // ── 2. Cycle ──
                    _CycleCard(
                      open: _cycleOpen,
                      onToggle: () =>
                          setState(() => _cycleOpen = !_cycleOpen),
                      now: _now,
                      role: _cycleRole,
                      onRoleChanged: (r) => setState(() => _cycleRole = r),
                      selDay: _selDay,
                      onDaySelected: (d) => setState(() =>
                          _selDay = _selDay != null && _startOfDay(_selDay!) == d
                              ? null
                              : d),
                      shared: _shared,
                      onSharedChanged: (v) => setState(() => _shared = v),
                      myName: _myName,
                      partnerName: _partnerName,
                    ),
                    const SizedBox(height: AppSpace.md),

                    // ── 3. Everything else on the calendar ──
                    if (alsoComing.isNotEmpty) ...[
                      const _SectionLabel(label: 'Also coming up'),
                      const SizedBox(height: AppSpace.xs),
                      ..._monthGroupedRows(alsoComing, dimmed: false),
                      const SizedBox(height: AppSpace.sm),
                    ],

                    if (passed.isNotEmpty) ...[
                      const _SectionLabel(label: 'Passed'),
                      const SizedBox(height: AppSpace.xs),
                      ..._monthGroupedRows(passed, dimmed: true),
                      const SizedBox(height: AppSpace.sm),
                    ],

                    _AddEventRow(onTap: () => _openEventSheet(null)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  /// Rows with a month heading inserted whenever the month changes.
  List<Widget> _monthGroupedRows(List<_Event> list, {required bool dimmed}) {
    final out = <Widget>[];
    String? currentMonth;
    for (final e in list) {
      final month = DateFormat('MMMM yyyy').format(e.when!);
      if (month != currentMonth) {
        if (currentMonth != null) out.add(const SizedBox(height: AppSpace.xs));
        currentMonth = month;
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.xxs, left: 2),
          child: Text(month.toUpperCase(), style: AppText.label()),
        ));
      }
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.xs),
        child: _EventRow(
          event: e,
          dimmed: dimmed,
          onTap: () => _openEventSheet(e),
        ),
      ));
    }
    return out;
  }
}

// ═══════════════════════════════════════════════════
//   1. NEXT UP — hero countdown
// ═══════════════════════════════════════════════════

class _NextUpCard extends StatelessWidget {
  const _NextUpCard({
    required this.event,
    required this.now,
    required this.onEdit,
    required this.onAdd,
  });

  final _Event? event;
  final DateTime now;
  final VoidCallback onEdit, onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: event == null ? _empty(context) : _content(context, event!),
    );
  }

  Widget _empty(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NEXT UP', style: AppText.label(AppColors.onDarkMuted)),
        const SizedBox(height: AppSpace.xs),
        Text('Nothing on the calendar yet',
            style: AppText.subtitle(AppColors.onDark)),
        const SizedBox(height: AppSpace.xxs),
        Text('Add a birthday, a monthsary, the next time you meet.',
            style: AppText.caption(AppColors.onDarkMuted)),
        const SizedBox(height: AppSpace.sm),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm, vertical: AppSpace.xs),
            decoration: BoxDecoration(
              gradient: AppGradients.cta,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.add, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Text('Add your first event',
                    style: AppText.caption(Colors.white)
                        .copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, _Event e) {
    final target = e.when!;
    final daysAway = _daysUntil(target);
    final isToday = daysAway == 0;
    final countdown = _countdownTo(target, now);
    final subtitle = [
      if (e.location.isNotEmpty) e.location,
      _formatDate(target),
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NEXT UP', style: AppText.label(AppColors.onDarkMuted)),
                  const SizedBox(height: AppSpace.xs),
                  _Tag(
                      label: '${e.emoji} ${e.style.label}',
                      color: AppColors.brandLight),
                  const SizedBox(height: AppSpace.xs),
                  Text(e.title, style: AppText.title(AppColors.onDark)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.caption(AppColors.onDarkMuted)),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            _GhostEditBtn(onTap: onEdit, dark: true),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        if (isToday)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
              child: Text("It's today. 🌷",
                  style: AppText.note(AppColors.brandLight)),
            ),
          )
        else
          Row(
            children: [
              _TimeTile(value: '${countdown.days}', label: 'DAYS'),
              const SizedBox(width: AppSpace.xs),
              _TimeTile(
                  value: countdown.hrs.toString().padLeft(2, '0'), label: 'HRS'),
              const SizedBox(width: AppSpace.xs),
              _TimeTile(
                  value: countdown.mins.toString().padLeft(2, '0'),
                  label: 'MIN'),
              const SizedBox(width: AppSpace.xs),
              _TimeTile(
                  value: countdown.secs.toString().padLeft(2, '0'),
                  label: 'SEC'),
            ],
          ),
        if (e.note.isNotEmpty) ...[
          const SizedBox(height: AppSpace.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm, vertical: AppSpace.xs),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border(
                left: BorderSide(
                    color: AppColors.brandLight.withValues(alpha: .4), width: 2),
              ),
            ),
            child: Text('“${e.note}”',
                style: AppText.note(AppColors.onDarkMuted)),
          ),
        ],
        const SizedBox(height: AppSpace.sm),
        Center(
          child: Text('You both see this same countdown · live',
              style: AppText.label(AppColors.onDarkMuted)),
        ),
      ],
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: AppText.stat(AppColors.onDark)
                      .copyWith(fontSize: 26, height: 1)),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppText.label(AppColors.onDarkMuted)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//   2. CYCLE — collapsible
// ═══════════════════════════════════════════════════

class _CycleCard extends StatelessWidget {
  const _CycleCard({
    required this.open,
    required this.onToggle,
    required this.now,
    required this.role,
    required this.onRoleChanged,
    required this.selDay,
    required this.onDaySelected,
    required this.shared,
    required this.onSharedChanged,
    required this.myName,
    required this.partnerName,
  });

  final bool open;
  final VoidCallback onToggle;
  final DateTime now;
  final String role, myName, partnerName;
  final ValueChanged<String> onRoleChanged;
  final DateTime? selDay;
  final ValueChanged<DateTime> onDaySelected;
  final bool shared;
  final ValueChanged<bool> onSharedChanged;

  @override
  Widget build(BuildContext context) {
    final today = _startOfDay(now);
    final phase = _phaseOn(today);
    final day = _cycleDay(today);
    final toNextPeriod = _cycleLength - day + 1;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header (always visible) ──
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Row(
              children: [
                const _SectionLabel(label: 'Cycle'),
                const Spacer(),
                if (phase != null)
                  _Tag(
                      label: _phaseData[phase]!.label,
                      color: _phaseData[phase]!.color),
                const SizedBox(width: AppSpace.xs),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: AppMotion.micro,
                  child: const Icon(CupertinoIcons.chevron_down,
                      size: 16, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),

          // ── Summary (always visible) ──
          if (phase != null) ...[
            _PhaseBanner(phase: phase, role: role, partnerName: partnerName),
            const SizedBox(height: AppSpace.sm),
          ],
          Row(
            children: [
              Expanded(
                  child: _StatCard(
                      value: '$toNextPeriod days',
                      label: 'Next period',
                      color: AppColors.period)),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                  child: _StatCard(
                      value: 'Day $day',
                      label: 'Cycle day',
                      color: AppColors.brand)),
              const SizedBox(width: AppSpace.xs),
              const Expanded(
                  child: _StatCard(
                      value: '$_cycleLength days',
                      label: 'Avg cycle',
                      color: AppColors.pms)),
            ],
          ),

          // ── Detail (expanded only) ──
          AnimatedCrossFade(
            duration: AppMotion.standard,
            sizeCurve: AppMotion.easeOut,
            crossFadeState:
                open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpace.sm),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _RoleChip(
                          label: '$partnerName (Her)',
                          selected: role == 'her',
                          onTap: () => onRoleChanged('her')),
                      _RoleChip(
                          label: '$myName (Him)',
                          selected: role == 'me',
                          onTap: () => onRoleChanged('me')),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                _CycleCalendar(
                  now: now,
                  selDay: selDay,
                  onDaySelected: onDaySelected,
                ),
                const SizedBox(height: AppSpace.sm),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: AppSpace.xs,
                  mainAxisSpacing: AppSpace.xs,
                  childAspectRatio: 4.6,
                  children: _phaseData.entries
                      .map((e) => Row(
                            children: [
                              Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      color: e.value.color,
                                      borderRadius: BorderRadius.circular(3))),
                              const SizedBox(width: AppSpace.xs),
                              Text(e.value.label,
                                  style: AppText.caption(AppColors.body)),
                            ],
                          ))
                      .toList(),
                ),
                if (role == 'me' && phase != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  _SupportCard(phase: phase, partnerName: partnerName),
                ],
                const SizedBox(height: AppSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Shared with $myName',
                              style: AppText.body(AppColors.ink)
                                  .copyWith(fontWeight: FontWeight.w600)),
                          Text('He can see your cycle',
                              style: AppText.caption()),
                        ],
                      ),
                    ),
                    Switch(
                      value: shared,
                      onChanged: onSharedChanged,
                      activeTrackColor: AppColors.brand,
                      activeThumbColor: Colors.white,
                      inactiveTrackColor: AppColors.border,
                      inactiveThumbColor: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleCalendar extends StatelessWidget {
  const _CycleCalendar({
    required this.now,
    required this.selDay,
    required this.onDaySelected,
  });

  final DateTime now;
  final DateTime? selDay;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final today = _startOfDay(now);
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    // Sunday-first grid: Mon=1..Sun=7, so Sunday maps to 0.
    final leading = firstOfMonth.weekday % 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(DateFormat('MMMM yyyy').format(now), style: AppText.subtitle()),
        const SizedBox(height: AppSpace.xs),
        Row(
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map((l) => Expanded(
                    child: Center(child: Text(l, style: AppText.label())),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (ctx, box) {
          final cellW = box.maxWidth / 7;
          return Wrap(
            children: [
              ...List.generate(leading, (_) => SizedBox(width: cellW)),
              ...List.generate(daysInMonth, (i) {
                final date = DateTime(now.year, now.month, i + 1);
                return SizedBox(
                  width: cellW,
                  child: Padding(
                    padding: const EdgeInsets.all(1.5),
                    child: _CalDay(
                      day: i + 1,
                      isToday: date == today,
                      isSelected: selDay != null && _startOfDay(selDay!) == date,
                      phase: _phaseOn(date),
                      onTap: () => onDaySelected(date),
                    ),
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }
}

class _CalDay extends StatelessWidget {
  const _CalDay({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.phase,
    required this.onTap,
  });
  final int day;
  final bool isToday, isSelected;
  final _Phase? phase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color fg = AppColors.body;
    Color border = Colors.transparent;

    if (phase != null) {
      final c = _phaseData[phase]!.color;
      bg = c.withValues(alpha: .12);
      fg = c;
      border = c.withValues(alpha: .2);
    }

    if (isToday) {
      bg = AppColors.brand;
      fg = Colors.white;
      border = AppColors.brand;
    } else if (isSelected) {
      border = AppColors.brand;
      fg = AppColors.brand;
    }

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.sm - 2),
            border: Border.all(color: border, width: isSelected ? 1.5 : 1),
          ),
          alignment: Alignment.center,
          child: Text('$day',
              style: AppText.caption(fg).copyWith(
                fontSize: 11,
                fontWeight:
                    isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
              )),
        ),
      ),
    );
  }
}

class _PhaseBanner extends StatelessWidget {
  const _PhaseBanner({
    required this.phase,
    required this.role,
    required this.partnerName,
  });
  final _Phase phase;
  final String role, partnerName;

  @override
  Widget build(BuildContext context) {
    final info = _phaseData[phase]!;
    final tip =
        role == 'me' ? info.tip : "You're in your ${info.label} phase today.";
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: info.color.withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: info.color.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Icon(info.icon, color: info.color, size: 20),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Tag(label: 'Today · ${info.label}', color: info.color),
                const SizedBox(height: AppSpace.xxs),
                Text(tip, style: AppText.caption(AppColors.body)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.micro,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.blush : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: AppText.caption(
                      selected ? AppColors.brand : AppColors.muted)
                  .copyWith(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpace.xs, horizontal: AppSpace.xs),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: AppText.body(color)
                    .copyWith(fontWeight: FontWeight.w700, height: 1.2)),
          ),
          const SizedBox(height: 3),
          Text(label, textAlign: TextAlign.center, style: AppText.label()),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.phase, required this.partnerName});
  final _Phase phase;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    final tips = phase == _Phase.pms || phase == _Phase.period
        ? [
            '🧘 She may be more emotional — listen',
            '❌ Skip debates or heavy topics',
            '🍵 Virtual tea date?',
            '💗 A random "I love you" helps',
          ]
        : [
            '🌷 Send an extra heartbeat',
            "💬 Ask how she's feeling",
            "😊 She's likely in good spirits",
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.sage.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💡 SUPPORT ${partnerName.toUpperCase()} TODAY',
              style: AppText.label(AppColors.sage)),
          const SizedBox(height: AppSpace.xs),
          ...tips.map((tip) => Container(
                margin: const EdgeInsets.only(bottom: AppSpace.xxs),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.xs, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Text(tip, style: AppText.caption(AppColors.body)),
              )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//   3. EVENT ROWS
// ═══════════════════════════════════════════════════

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.onTap,
    this.dimmed = false,
  });
  final _Event event;
  final VoidCallback onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final date = event.when!;
    final color = dimmed ? AppColors.muted : event.color;

    return Opacity(
      opacity: dimmed ? .6 : 1,
      child: _Card(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpace.xs + 4),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
              alignment: Alignment.center,
              child: Text(event.emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(AppColors.ink)
                          .copyWith(fontWeight: FontWeight.w700)),
                  Text(_formatDate(date), style: AppText.caption()),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(AppRadius.pill)),
              child: Text(_daysLabel(date),
                  style: AppText.caption(color)
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEventRow extends StatelessWidget {
  const _AddEventRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.blushMid, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.add_circled,
                color: AppColors.muted, size: 18),
            const SizedBox(width: AppSpace.xs),
            Text('Add event',
                style: AppText.body(AppColors.muted)
                    .copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppGradients.cta,
          shape: BoxShape.circle,
          boxShadow: AppElevation.glow,
        ),
        child: const Icon(CupertinoIcons.add, color: Colors.white, size: 20),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//   EDIT EVENT SHEET — the only event editor
// ═══════════════════════════════════════════════════

class _EditEventSheet extends StatefulWidget {
  const _EditEventSheet({required this.event, required this.isNew});
  final _Event event;
  final bool isNew;

  @override
  State<_EditEventSheet> createState() => _EditEventSheetState();
}

class _EditEventSheetState extends State<_EditEventSheet> {
  late _Event _draft;
  late TextEditingController _titleCtrl, _emojiCtrl, _locationCtrl, _noteCtrl;

  @override
  void initState() {
    super.initState();
    _draft = widget.event.copyWith();
    _titleCtrl = TextEditingController(text: _draft.title);
    _emojiCtrl = TextEditingController(text: _draft.emoji);
    _locationCtrl = TextEditingController(text: _draft.location);
    _noteCtrl = TextEditingController(text: _draft.note);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _emojiCtrl.dispose();
    _locationCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// Switching kind also swaps the emoji, but only while it is still the
  /// previous kind's default — a hand-picked emoji is never overwritten.
  void _pickKind(_EventKind kind) {
    setState(() {
      final wasDefault = _emojiCtrl.text.trim() == _draft.style.emoji;
      _draft = _draft.copyWith(kind: kind);
      if (wasDefault) _emojiCtrl.text = _kindStyles[kind]!.emoji;
    });
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _draft.date.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give it a name and a date first.')),
      );
      return;
    }
    Navigator.pop(context, (
      false,
      _draft.copyWith(
        title: title,
        emoji: _emojiCtrl.text.trim().isEmpty
            ? _draft.style.emoji
            : _emojiCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        note: _noteCtrl.text.trim(),
      )
    ));
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheet(
      title: widget.isNew ? 'Add event' : 'Edit event',
      subtitle: 'Birthdays, monthsaries, the next time you meet',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel(label: 'Type'),
          SizedBox(
            height: 78,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _kindStyles.entries.map((entry) {
                final sel = _draft.kind == entry.key;
                return GestureDetector(
                  onTap: () => _pickKind(entry.key),
                  child: AnimatedContainer(
                    duration: AppMotion.micro,
                    width: 84,
                    margin: const EdgeInsets.only(right: AppSpace.xs),
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                          color: sel ? AppColors.brand : AppColors.border,
                          width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(entry.value.icon,
                            color: sel ? AppColors.brand : AppColors.muted,
                            size: 20),
                        const SizedBox(height: AppSpace.xxs),
                        Text(entry.value.label,
                            style: AppText.label(
                                sel ? AppColors.brand : AppColors.muted)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 68,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel(label: 'Icon'),
                    TextField(
                      controller: _emojiCtrl,
                      maxLength: 2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 11),
                        border: _sheetBorder(AppColors.border),
                        enabledBorder: _sheetBorder(AppColors.border),
                        focusedBorder: _sheetBorder(AppColors.brand),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel(label: 'Name'),
                    _SheetInput(
                        controller: _titleCtrl,
                        placeholder: 'e.g. Tokyo Reunion'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          const _FieldLabel(label: 'Date'),
          _DateInput(
              value: _draft.date,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(date: v))),
          const SizedBox(height: AppSpace.sm),
          const _FieldLabel(label: 'Place (optional)'),
          _SheetInput(
              controller: _locationCtrl, placeholder: 'e.g. Tokyo, Japan 🇯🇵'),
          const SizedBox(height: AppSpace.sm),
          const _FieldLabel(label: 'Note (optional)'),
          _SheetTextarea(
              controller: _noteCtrl,
              placeholder: "Can't wait to hold you again..."),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              if (!widget.isNew) ...[
                Expanded(
                    child: _SheetBtn(
                        label: 'Delete',
                        variant: 'danger',
                        onTap: () => Navigator.pop(context, (true, _draft)))),
                const SizedBox(width: AppSpace.xs),
              ],
              Expanded(
                  child: _SheetBtn(
                      label: 'Cancel',
                      variant: 'ghost',
                      onTap: () => Navigator.pop(context))),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                  flex: 2,
                  child: _SheetBtn(
                      label: 'Save',
                      icon: CupertinoIcons.checkmark_alt,
                      onTap: _save)),
            ],
          ),
        ],
      ),
    );
  }
}

OutlineInputBorder _sheetBorder(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: color, width: 1.5),
    );

// ═══════════════════════════════════════════════════
//   SHARED ATOMS
// ═══════════════════════════════════════════════════

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.sm),
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

class _BottomSheet extends StatelessWidget {
  const _BottomSheet({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            AppSpace.md, 0, AppSpace.md, AppSpace.lg + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2))),
              ),
            ),
            Text(title, style: AppText.hero()),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: AppText.caption()),
            ],
            const SizedBox(height: AppSpace.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Text(label, style: AppText.label(color)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label.toUpperCase(), style: AppText.label());
}

class _GhostEditBtn extends StatelessWidget {
  const _GhostEditBtn({required this.onTap, this.dark = false});
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? AppColors.onDarkMuted : AppColors.brand;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 7),
        decoration: BoxDecoration(
          color: dark ? Colors.white.withValues(alpha: .1) : AppColors.blush,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: .15)
                  : AppColors.blushMid),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.pencil, size: 13, color: fg),
            const SizedBox(width: 5),
            Text('Edit',
                style: AppText.label(fg).copyWith(letterSpacing: 0)),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xxs),
      child:
          Text(label.toUpperCase(), style: AppText.label(AppColors.brand)),
    );
  }
}

class _SheetInput extends StatelessWidget {
  const _SheetInput({required this.controller, required this.placeholder});
  final TextEditingController controller;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AppText.body(AppColors.ink),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: AppText.body(AppColors.muted),
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 11),
        border: _sheetBorder(AppColors.border),
        enabledBorder: _sheetBorder(AppColors.border),
        focusedBorder: _sheetBorder(AppColors.brand),
      ),
    );
  }
}

class _SheetTextarea extends StatelessWidget {
  const _SheetTextarea({required this.controller, required this.placeholder});
  final TextEditingController controller;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 3,
      style: AppText.note(AppColors.ink),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: AppText.note(AppColors.muted),
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 11),
        border: _sheetBorder(AppColors.border),
        enabledBorder: _sheetBorder(AppColors.border),
        focusedBorder: _sheetBorder(AppColors.brand),
      ),
    );
  }
}

class _DateInput extends StatelessWidget {
  const _DateInput({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final initial = DateTime.tryParse(value) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                  primary: AppColors.brand, onPrimary: Colors.white),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(_iso(picked));
      },
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty
                    ? 'Select date'
                    : _formatDate(DateTime.parse(value)),
                style: AppText.body(
                    value.isEmpty ? AppColors.muted : AppColors.ink),
              ),
            ),
            const Icon(CupertinoIcons.calendar,
                size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _SheetBtn extends StatelessWidget {
  const _SheetBtn({
    required this.label,
    required this.onTap,
    this.variant = 'primary',
    this.icon,
  });
  final String label;
  final VoidCallback onTap;
  final String variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color? bg;
    final Gradient? gradient;
    final Border border;

    switch (variant) {
      case 'ghost':
        bg = Colors.transparent;
        gradient = null;
        fg = AppColors.muted;
        border = Border.all(color: AppColors.border, width: 1.5);
      case 'danger':
        bg = AppColors.dangerSubtle;
        gradient = null;
        fg = AppColors.danger;
        border = Border.all(color: AppColors.danger.withValues(alpha: .25));
      default:
        bg = null;
        gradient = AppGradients.cta;
        fg = Colors.white;
        border = Border.all(color: Colors.transparent);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: AppSpace.xs),
        decoration: BoxDecoration(
            color: bg,
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: border),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: fg, size: 15),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(fg)
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
