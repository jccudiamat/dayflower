import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../data/reunion_repository.dart';

class ReunionCard extends ConsumerWidget {
  const ReunionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reunion = ref.watch(reunionProvider).valueOrNull;

    return GestureDetector(
      onTap: () => _openEditSheet(context, ref, reunion),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          gradient: AppGradients.hero,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: reunion == null
            ? const _EmptyState()
            : _CountdownContent(reunion: reunion),
      ),
    );
  }

  void _openEditSheet(BuildContext context, WidgetRef ref, Reunion? existing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditReunionSheet(existing: existing, ref: ref),
    );
  }
}

/* ── Empty state ─────────────────────────────────── */
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NEXT REUNION', style: AppText.label(AppColors.onDarkMuted)),
        const SizedBox(height: AppSpace.xs),
        Text(
          'When do you see each other again?',
          style: AppText.subtitle(AppColors.onDark),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          'Set the date →',
          style: AppText.caption(AppColors.brandLight)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/* ── Live countdown ──────────────────────────────── */
class _CountdownContent extends StatefulWidget {
  const _CountdownContent({required this.reunion});
  final Reunion reunion;

  @override
  State<_CountdownContent> createState() => _CountdownContentState();
}

class _CountdownContentState extends State<_CountdownContent> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reunion;
    final remaining = r.happensAt.difference(DateTime.now());
    final arrived = remaining.isNegative;

    final days = remaining.inDays;
    final hrs = remaining.inHours % 24;
    final min = remaining.inMinutes % 60;
    final sec = remaining.inSeconds % 60;

    final subtitle = [
      if (r.destination != null) r.destination!,
      DateFormat('MMM d, yyyy').format(r.happensAt),
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'NEXT REUNION',
                style: AppText.label(AppColors.onDarkMuted),
              ),
            ),
            const Icon(
              CupertinoIcons.pencil,
              size: 16,
              color: AppColors.onDarkMuted,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.xs),
        Text(r.title, style: AppText.title(AppColors.onDark)),
        const SizedBox(height: 2),
        Text(subtitle, style: AppText.caption(AppColors.onDarkMuted)),
        const SizedBox(height: AppSpace.sm),
        if (arrived)
          Text('It’s time. Hold each other tight. 🌷',
              style: AppText.note(AppColors.onDark))
        else
          Row(
            children: [
              _TimeCell(value: '$days', unit: 'DAYS'),
              _TimeCell(value: _pad(hrs), unit: 'HRS'),
              _TimeCell(value: _pad(min), unit: 'MIN'),
              _TimeCell(value: _pad(sec), unit: 'SEC'),
            ],
          ),
        if (r.note != null) ...[
          const SizedBox(height: AppSpace.sm),
          Text('“${r.note}”', style: AppText.note(AppColors.onDarkMuted)),
        ],
      ],
    );
  }

  String _pad(int v) => v.toString().padLeft(2, '0');
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({required this.value, required this.unit});
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppText.stat(AppColors.onDark)),
          const SizedBox(height: 2),
          Text(unit, style: AppText.label(AppColors.onDarkMuted)),
        ],
      ),
    );
  }
}

/* ── Edit sheet ──────────────────────────────────── */
class _EditReunionSheet extends StatefulWidget {
  const _EditReunionSheet({required this.existing, required this.ref});
  final Reunion? existing;
  final WidgetRef ref;

  @override
  State<_EditReunionSheet> createState() => _EditReunionSheetState();
}

class _EditReunionSheetState extends State<_EditReunionSheet> {
  late final TextEditingController _title;
  late final TextEditingController _destination;
  late final TextEditingController _note;
  DateTime? _date;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _destination =
        TextEditingController(text: widget.existing?.destination ?? '');
    _note = TextEditingController(text: widget.existing?.note ?? '');
    _date = widget.existing?.happensAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _destination.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      // Count down to noon local on the chosen day.
      setState(() =>
          _date = DateTime(picked.year, picked.month, picked.day, 12));
    }
  }

  Future<void> _save() async {
    final date = _date;
    if (date == null) {
      setState(() => _error = 'Pick a date first.');
      return;
    }
    final pair = widget.ref.read(currentPairProvider).valueOrNull;
    if (pair == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.ref.read(reunionRepositoryProvider).save(
            pairId: pair.id,
            title: _title.text,
            destination: _destination.text,
            happensAt: date,
            note: _note.text,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Couldn't save. Please try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: AppSpace.xs,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpace.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Next reunion', style: AppText.title()),
          const SizedBox(height: AppSpace.sm),
          TextField(
            controller: _title,
            decoration: const InputDecoration(hintText: 'Title — e.g. Manila!'),
          ),
          const SizedBox(height: AppSpace.xs),
          TextField(
            controller: _destination,
            decoration:
                const InputDecoration(hintText: 'Destination (optional)'),
          ),
          const SizedBox(height: AppSpace.xs),
          OutlinedButton(
            onPressed: _pickDate,
            child: Text(
              _date == null
                  ? 'Pick the date'
                  : DateFormat('MMMM d, yyyy').format(_date!),
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          TextField(
            controller: _note,
            maxLength: 140,
            style: AppText.note(AppColors.ink),
            decoration: const InputDecoration(
              hintText: 'A note for the wait… (optional)',
              counterText: '',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(_error!, style: AppText.caption(AppColors.danger)),
          ],
          const SizedBox(height: AppSpace.sm),
          GradientButton(
            label: 'Save',
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
