import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/services/city_search.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/city_picker.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../data/map_pin_repository.dart';

/// Drops a place on the map.
///
/// 🔴 The coordinates come from [showCityPicker] — the same search that sets
/// "Where you are" — and nowhere else. No location permission is asked for
/// and no photo is read for EXIF: a pin is a place one of them chose to
/// name. See the header of migration 0047.
Future<void> showAddPinSheet(BuildContext context, {bool visited = true}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddPinSheet(visited: visited),
  );
}

class _AddPinSheet extends ConsumerStatefulWidget {
  const _AddPinSheet({required this.visited});
  final bool visited;

  @override
  ConsumerState<_AddPinSheet> createState() => _AddPinSheetState();
}

class _AddPinSheetState extends ConsumerState<_AddPinSheet> {
  final _label = TextEditingController();
  CityResult? _place;
  late bool _visited = widget.visited;
  bool _saving = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  bool get _ready =>
      _place != null && _label.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    final place = _place;
    if (pair == null || userId == null || place == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(mapPinRepositoryProvider).add(
            pairId: pair.id,
            createdBy: userId,
            label: _label.text,
            place: place.name,
            lat: place.latitude,
            lon: place.longitude,
            visited: _visited,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      // Says so rather than closing on a pin that was never saved — the map
      // is the only place this would show up, and a silently missing pin
      // reads as the map being broken.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That pin did not save. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the sheet clear of the keyboard while the label is being typed.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add a place', style: AppText.subtitle()),
              const SizedBox(height: AppSpace.sm),
              TextField(
                controller: _label,
                autofocus: true,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Beach day, first date, the good noodles…',
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpace.xs),
              InkWell(
                onTap: () async {
                  final picked = await showCityPicker(context);
                  if (picked != null) setState(() => _place = picked);
                },
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpace.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    _place?.name ?? 'Where was it?',
                    style: _place == null
                        ? AppText.body(AppColors.muted)
                        : AppText.body(AppColors.ink),
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _visited,
                onChanged: (v) => setState(() => _visited = v),
                title: Text(
                  _visited ? 'Somewhere we went' : 'Somewhere we want to go',
                  style: AppText.body(AppColors.ink),
                ),
                subtitle: Text(
                  _visited
                      ? 'Sits on the map as a memory'
                      : 'Drawn as an outline until you have been',
                  style: AppText.caption(),
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _ready ? _save : null,
                  child: Text(_saving ? 'Saving…' : 'Add to the map'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a pin is, and how to take it off again.
Future<void> showPinSheet(BuildContext context, MapPin pin) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pin.label, style: AppText.subtitle()),
            const SizedBox(height: 2),
            Text(pin.place, style: AppText.caption()),
            if (!pin.visited) ...[
              const SizedBox(height: AppSpace.xs),
              Text('Somewhere you want to go',
                  style: AppText.caption(AppColors.secondary)),
            ],
            const SizedBox(height: AppSpace.sm),
            Consumer(
              builder: (context, ref, _) => TextButton.icon(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  // ⚠️ Either of you can remove any pin — the map is built
                  // together. See the policies in 0047.
                  try {
                    await ref.read(mapPinRepositoryProvider).remove(pin.id);
                  } catch (_) {
                    // The stream never took it, so the pin is still there
                    // and nothing on screen is now lying.
                  }
                },
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                label: Text('Remove from the map',
                    style: AppText.body(AppColors.danger)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
