import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/timezone_picker.dart';
import '../../../onboarding/data/user_repository.dart';

class ClocksCard extends ConsumerStatefulWidget {
  const ClocksCard({super.key});

  @override
  ConsumerState<ClocksCard> createState() => _ClocksCardState();
}

class _ClocksCardState extends ConsumerState<ClocksCard> {
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

  Future<void> _pickMyTimezone() async {
    final chosen = await showTimezonePicker(context);
    if (chosen == null || !mounted) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await ref.read(userRepositoryProvider).updateTimezone(userId, chosen);
    ref.invalidate(userProfileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(userProfileProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;

    final myLoc = safeLocation(me?.timezone ?? 'UTC');
    final partnerLoc = safeLocation(partner?.timezone ?? 'UTC');
    final myNow = tz.TZDateTime.now(myLoc);
    final partnerNow = tz.TZDateTime.now(partnerLoc);

    final diffMinutes =
        (partnerNow.timeZoneOffset - myNow.timeZoneOffset).inMinutes;
    final diffLabel = diffMinutes == 0
        ? 'Same time'
        : '${diffMinutes > 0 ? '+' : '−'}'
            '${(diffMinutes.abs() / 60).toStringAsFixed(diffMinutes.abs() % 60 == 0 ? 0 : 1)}h';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('OUR CLOCKS', style: AppText.label())),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.xs,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(diffLabel, style: AppText.caption()),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(
                child: _Clock(
                  label: 'You',
                  now: myNow,
                  zone: myLoc.name,
                  onTap: _pickMyTimezone,
                  editable: true,
                ),
              ),
              Container(width: 1, height: 56, color: AppColors.border),
              Expanded(
                child: _Clock(
                  label: partner?.petName ?? partner?.displayName ?? 'Partner',
                  now: partnerNow,
                  zone: partnerLoc.name,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Clock extends StatelessWidget {
  const _Clock({
    required this.label,
    required this.now,
    required this.zone,
    this.onTap,
    this.editable = false,
  });

  final String label;
  final tz.TZDateTime now;
  final String zone;
  final VoidCallback? onTap;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final city = zone.split('/').last.replaceAll('_', ' ');
    // 6am–6pm is daylight. The point of this card is telling at a glance
    // whether they're awake, and a sun/moon carries that faster than
    // reading two clock faces and doing the subtraction.
    final isDaytime = now.hour >= 6 && now.hour < 18;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(label, style: AppText.caption()),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isDaytime ? '☀️' : '🌙',
                style: const TextStyle(fontSize: 17),
                semanticsLabel: isDaytime ? 'daytime' : 'night',
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat('h:mm').format(now),
                style: AppText.stat().copyWith(fontSize: 28),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${DateFormat('a · EEE').format(now)} · $city',
                style: AppText.caption(),
              ),
              if (editable) ...[
                const SizedBox(width: 4),
                const Icon(
                  CupertinoIcons.pencil,
                  size: 12,
                  color: AppColors.muted,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
