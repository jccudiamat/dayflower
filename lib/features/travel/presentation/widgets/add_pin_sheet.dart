import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/services/city_search.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/city_picker.dart';
import '../../../../core/widgets/storage_image.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../data/map_pin_repository.dart';

/// "12 March 2026", for a pin's date.
String pinDateLabel(DateTime day) => DateFormat('d MMMM y').format(day);

/// Drops a place on the map: what it was, where, and if they like, a photo
/// of it, when, and a few words. With a photo, the map shows the photo
/// itself; the rest is what tapping it opens (showPinSheet).
///
/// 🔴 The coordinates come from [showCityPicker] — the same search that sets
/// "Where you are" — and nowhere else. No photo is read for EXIF: a pin is a
/// place one of them chose to name. See the header of migration 0047.
Future<void> showAddPinSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _AddPinSheet(),
  );
}

class _AddPinSheet extends ConsumerStatefulWidget {
  const _AddPinSheet();

  @override
  ConsumerState<_AddPinSheet> createState() => _AddPinSheetState();
}

class _AddPinSheetState extends ConsumerState<_AddPinSheet> {
  final _label = TextEditingController();
  final _note = TextEditingController();
  CityResult? _place;
  Uint8List? _photo;
  DateTime? _when;
  bool _visited = true;
  bool _saving = false;

  @override
  void dispose() {
    _label.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _ready =>
      _place != null && _label.text.trim().isNotEmpty && !_saving;

  Future<void> _pickPhoto() async {
    try {
      // Shrunk by the picker itself: a travel photo needs to fill a phone,
      // not a poster, and every byte of it is stored for as long as the pin.
      final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    } on PlatformException {
      // Refused, or no gallery. The pin works without one.
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _when ?? now,
      firstDate: DateTime(1950),
      // Ahead too: "somewhere we want to go" can have its date already.
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked != null && mounted) setState(() => _when = picked);
  }

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
            photo: _photo,
            visitedOn: _when,
            note: _note.text,
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
    final field = BoxDecoration(
      color: AppColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    );
    return Padding(
      // Lifts the sheet clear of the keyboard while the label is being typed.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add a place', style: AppText.subtitle()),
              const SizedBox(height: AppSpace.sm),
              _PhotoPicker(
                photo: _photo,
                onPick: _pickPhoto,
                onClear: () => setState(() => _photo = null),
              ),
              const SizedBox(height: AppSpace.sm),
              TextField(
                key: const ValueKey('pin-label'),
                controller: _label,
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
                  decoration: field,
                  child: Text(
                    _place?.name ?? 'Where was it?',
                    style: _place == null
                        ? AppText.body(AppColors.muted)
                        : AppText.body(AppColors.ink),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              InkWell(
                key: const ValueKey('pin-date'),
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpace.sm),
                  decoration: field,
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        _when == null ? 'When? (optional)' : pinDateLabel(_when!),
                        style: _when == null
                            ? AppText.body(AppColors.muted)
                            : AppText.body(AppColors.ink),
                      ),
                    ),
                    if (_when != null)
                      GestureDetector(
                        onTap: () => setState(() => _when = null),
                        child: Icon(Icons.close,
                            size: 18, color: AppColors.muted),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              TextField(
                key: const ValueKey('pin-note'),
                controller: _note,
                maxLength: 500,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'What happened there? (optional)',
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

/// The photo the pin will be on the map, or a place to add one.
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker(
      {required this.photo, required this.onPick, required this.onClear});

  final Uint8List? photo;
  final VoidCallback onPick, onClear;

  @override
  Widget build(BuildContext context) {
    final picked = photo;
    return Semantics(
      button: true,
      label: picked == null ? 'Add a photo' : 'Change the photo',
      child: InkWell(
        key: const ValueKey('pin-photo'),
        onTap: onPick,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: picked == null ? 96 : 180,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: picked == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined,
                        color: AppColors.secondary),
                    const SizedBox(height: 4),
                    Text('Add a photo', style: AppText.caption(AppColors.ink)),
                    Text('It becomes the pin on your map',
                        style: AppText.caption()),
                  ],
                )
              : Stack(fit: StackFit.expand, children: [
                  Image.memory(picked, fit: BoxFit.cover, cacheWidth: 900),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.black45,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Remove the photo',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: onClear,
                      ),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }
}

/// A pin's photo path: its own, or the chat photo it was made from.
String? pinPhotoPath(WidgetRef ref, MapPin pin) =>
    pin.photoPath ??
    (pin.messageId == null
        ? null
        : ref.watch(pinPhotoPathProvider(pin.messageId!)).valueOrNull);

/// Everything about a pin: its photo large, what it was, where and when,
/// the words kept with it. What tapping a pin opens; the map itself shows
/// only the photo.
Future<void> showPinSheet(BuildContext context, MapPin pin) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(builder: (context, ref, _) {
      final path = pinPhotoPath(ref, pin);
      final where = [
        pin.place,
        if (pin.visitedOn != null) pinDateLabel(pin.visitedOn!),
      ].where((s) => s.isNotEmpty).join(' · ');
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (path != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: StorageImage.dayPhoto(
                        path,
                        key: ValueKey('pin-sheet-photo-${pin.id}'),
                        fit: BoxFit.cover,
                        semanticLabel: pin.label,
                        error: (_) =>
                            Container(color: AppColors.surfaceSubtle),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                ],
                Text(pin.label, style: AppText.subtitle()),
                if (where.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(where, style: AppText.caption()),
                ],
                if (!pin.visited) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text('Somewhere you want to go',
                      style: AppText.caption(AppColors.secondary)),
                ],
                if (pin.note != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  Text(pin.note!, style: AppText.body(AppColors.ink)),
                ],
                const SizedBox(height: AppSpace.sm),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    // ⚠️ Either of you can remove any pin — the map is built
                    // together. See the policies in 0047.
                    try {
                      await ref.read(mapPinRepositoryProvider).remove(pin);
                    } catch (_) {
                      // The stream never took it, so the pin is still there
                      // and nothing on screen is now lying.
                    }
                  },
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.danger),
                  label: Text('Remove from the map',
                      style: AppText.body(AppColors.danger)),
                ),
              ],
            ),
          ),
        ),
      );
    }),
  );
}
