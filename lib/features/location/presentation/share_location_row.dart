import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/data/user_repository.dart';
import '../../settings/presentation/screens/settings_sections.dart';
import '../data/live_location.dart';

/// Settings → "Share my exact location". See LocationSharing for what it
/// does and does not do; the subtitle says the same in a line.
class ShareLocationRow extends ConsumerStatefulWidget {
  const ShareLocationRow({super.key});

  @override
  ConsumerState<ShareLocationRow> createState() => _ShareLocationRowState();
}

class _ShareLocationRowState extends ConsumerState<ShareLocationRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final on = ref.watch(locationSharingProvider);
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final them = partner?.petName ?? partner?.displayName ?? 'your partner';
    return SettingsSwitchRow(
      title: 'Share my exact location',
      subtitle: 'Only $them sees it, only while Dayflower is open. '
          'No history is kept.',
      value: on,
      onChanged: _busy ? null : (v) => _change(v, them),
    );
  }

  Future<void> _change(bool on, String them) async {
    final messenger = ScaffoldMessenger.of(context);
    final sharing = ref.read(locationSharingProvider.notifier);
    setState(() => _busy = true);
    try {
      if (!on) {
        await sharing.turnOff();
        messenger.showSnackBar(const SnackBar(
            content: Text('Stopped. Your spot is off their map.')));
        return;
      }
      final result = await sharing.turnOn();
      switch (result) {
        case ShareStart.on:
          messenger.showSnackBar(SnackBar(
              content: Text(
                  '$them can see where you are while Dayflower is open.')));
        case ShareStart.noPermission:
          messenger.showSnackBar(const SnackBar(
            content: Text('Dayflower needs your location for this.'),
            action: SnackBarAction(
                label: 'Settings', onPressed: DeviceLocation.openSettings),
          ));
        case ShareStart.locationOff:
          messenger.showSnackBar(const SnackBar(
              content: Text('Turn on location on your phone, then try again.')));
        case ShareStart.unavailable:
          messenger.showSnackBar(const SnackBar(
              content: Text(
                  'Couldn’t find where you are just now. Try again in a moment.')));
        case ShareStart.failed:
          messenger.showSnackBar(const SnackBar(
              content: Text(
                  'Couldn’t share your location. Check your connection.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
