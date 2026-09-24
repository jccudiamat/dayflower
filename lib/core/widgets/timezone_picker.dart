import 'package:dayflower/core/widgets/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';
import '../time/zones.dart';

// Moved to core/time/zones.dart so a plain model can ask what day it is
// without importing a widget file. Re-exported so every existing
// `import '.../timezone_picker.dart'` keeps working unchanged.
export '../time/zones.dart' show safeLocation, zoneCity, isSameDayIn;

/// Frequently-picked zones surface at the top of the picker.
const kCommonZones = [
  'Asia/Manila',
  'Europe/London',
  'America/New_York',
  'America/Los_Angeles',
  'Asia/Tokyo',
  'Asia/Singapore',
  'Australia/Sydney',
  'Asia/Dubai',
];

/// Opens the timezone picker. Resolves to the chosen IANA name, or null.
Future<String?> showTimezonePicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const TimezonePickerSheet(),
  );
}

class TimezonePickerSheet extends StatefulWidget {
  const TimezonePickerSheet({super.key});

  @override
  State<TimezonePickerSheet> createState() => _TimezonePickerSheetState();
}

class _TimezonePickerSheetState extends State<TimezonePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = tz.timeZoneDatabase.locations.keys.toList()..sort();
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? kCommonZones
        : all.where((z) => z.toLowerCase().contains(q)).take(40).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: AppSpace.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpace.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Your timezone', style: AppText.title())),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: AppIcon(CupertinoIcons.xmark, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(hintText: 'Search, e.g. Manila'),
          ),
          const SizedBox(height: AppSpace.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: results.length,
              itemBuilder: (context, i) {
                final zone = results[i];
                final now = tz.TZDateTime.now(safeLocation(zone));
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    zone.replaceAll('_', ' '),
                    style: AppText.body(AppColors.ink),
                  ),
                  trailing: Text(
                    DateFormat('h:mm a').format(now),
                    style: AppText.caption(),
                  ),
                  onTap: () => Navigator.of(context).pop(zone),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
