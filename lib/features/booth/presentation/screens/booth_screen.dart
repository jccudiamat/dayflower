import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/feature_screen_header.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../../tulip/data/flower_repository.dart';
import '../../../tulip/presentation/widgets/media_viewer.dart';
import '../../data/strip_repository.dart';
import '../../domain/strip_templates.dart';

Uint8List normalizeBoothPhoto(Uint8List bytes) {
  if (bytes.length < 12) throw const FormatException('Unsupported image');
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported image');
  return Uint8List.fromList(
      img.encodeJpg(img.bakeOrientation(decoded), quality: 88));
}

final boothPhotoPickerProvider =
    Provider<Future<Uint8List?> Function(ImageSource)>((ref) => (source) async {
          final photo = await ImagePicker().pickImage(
              source: source,
              maxWidth: 1600,
              maxHeight: 1600,
              imageQuality: 88);
          if (photo == null) return null;
          return compute(normalizeBoothPhoto, await photo.readAsBytes());
        });

/// Activities uses the same compositor, repository and private photos as
/// the Camera. There is no second collection of pretend memories.
class BoothScreen extends ConsumerStatefulWidget {
  const BoothScreen({super.key});
  @override
  ConsumerState<BoothScreen> createState() => _BoothScreenState();
}

class _BoothScreenState extends ConsumerState<BoothScreen> {
  bool _duo = true;
  bool _busy = false;
  Uint8List? _photo;
  String? _error;
  StripTemplate _template = StripTemplate.all.first;
  PhotoStrip? _joining;

  void _setMode(bool duo) {
    setState(() {
      _duo = duo;
      _joining = null;
      _template = StripTemplate.all.firstWhere((t) => t.isDuo == duo);
    });
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await ref.read(boothPhotoPickerProvider)(source);
      if (mounted && bytes != null) setState(() => _photo = bytes);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not open that photo. Try your camera or another image.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || _photo == null) return;
    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    if (pair == null || !pair.isLinked || userId == null) return;
    final open = ref.read(openStripsProvider);
    if (!open.hasValue || open.hasError) {
      setState(() => _error = 'Wait for your strips to load, then try again.');
      return;
    }
    final joining = _joining;
    if (joining == null &&
        _duo &&
        open.requireValue.any((s) => s.aUser == userId)) {
      setState(() => _error =
          'Finish or cancel your waiting strip before starting another couple strip.');
      return;
    }
    if (joining != null &&
        !open.requireValue.any((s) => s.id == joining.id && s.bPath == null)) {
      setState(() {
        _joining = null;
        _error = 'That invitation has changed. Your photo is still here.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(stripRepositoryProvider);
      if (joining != null) {
        await repository.joinDuo(
            strip: joining, senderId: userId, bytes: _photo!);
      } else if (_template.isDuo) {
        await repository.startDuo(
            pairId: pair.id,
            senderId: userId,
            template: _template,
            bytes: _photo!);
      } else {
        await repository.postSolo(
            pairId: pair.id,
            senderId: userId,
            template: _template,
            bytes: _photo!);
      }
      if (!mounted) return;
      setState(() {
        _photo = null;
        _joining = null;
      });
      ref.invalidate(openStripsProvider);
      ref.invalidate(flowerMessagesProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
        joining != null || !_template.isDuo
            ? 'Your strip is ready and shared.'
            : 'Your photo is saved. Waiting for your partner.',
      )));
    } catch (_) {
      if (mounted) {
        ref.invalidate(openStripsProvider);
        setState(() => _error =
            'Could not finish your strip. Your photo is still here. Check the waiting strips below before retrying.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateStrip(PhotoStrip strip, {bool cancel = false}) async {
    if (_busy) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(stripRepositoryProvider);
      if (cancel) {
        await repository.cancel(strip.id);
      } else {
        await repository.finish(strip: strip, senderId: userId);
      }
      if (!mounted) return;
      if (_joining?.id == strip.id) setState(() => _joining = null);
      ref.invalidate(openStripsProvider);
      ref.invalidate(flowerMessagesProvider);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not update this strip. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(userProfileProvider).valueOrNull;
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final userId = ref.watch(currentUserIdProvider);
    final pair = ref.watch(currentPairProvider).valueOrNull;
    final myName = me?.petName ?? me?.displayName ?? 'You';
    final theirName =
        partner?.petName ?? partner?.displayName ?? 'Your partner';
    final open = ref.watch(openStripsProvider);
    final messages = ref.watch(flowerMessagesProvider);
    final templateNames = StripTemplate.all.map((t) => t.name).toSet();
    final history = (messages.valueOrNull ?? const <FlowerMessage>[])
        .where((m) => m.isPhoto && templateNames.contains(m.note))
        .toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(18), children: [
        Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Back to Memories',
              icon: const AppIcon(Icons.arrow_back),
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(Routes.memories),
            )),
        FeatureScreenHeader(
            title: 'Booth & Strip', subtitle: '$myName & $theirName'),
        const SizedBox(height: 16),
        Wrap(spacing: 8, children: [
          ChoiceChip(
              label: const Text('Solo'),
              selected: !_duo,
              onSelected: _busy ? null : (_) => _setMode(false)),
          ChoiceChip(
              label: const Text('Couple'),
              selected: _duo,
              onSelected: _busy ? null : (_) => _setMode(true)),
        ]),
        const SizedBox(height: 12),
        if (_joining != null) ...[
          Text('Joining $theirName’s ${_joining!.style.name}',
              style: AppText.subtitle()),
          TextButton(
              onPressed: _busy ? null : () => setState(() => _joining = null),
              child: const Text('Choose a different strip')),
        ] else
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final t in StripTemplate.all.where((t) => t.isDuo == _duo))
              ChoiceChip(
                  label: Text(t.name),
                  selected: _template.id == t.id,
                  onSelected:
                      _busy ? null : (_) => setState(() => _template = t)),
          ]),
        const SizedBox(height: 16),
        Container(
          height: 240,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: (_joining?.style ?? _template).paper,
              borderRadius: BorderRadius.circular(18)),
          child: _photo == null
              ? Center(
                  child: Text('Add your photo to get started',
                      style: AppText.body((_joining?.style ?? _template).ink)))
              : Image.memory(_photo!,
                  fit: BoxFit.contain, semanticLabel: 'Your selected photo'),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 12, children: [
          OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.camera),
              icon: const AppIcon(Icons.camera_alt),
              label: const Text('Take photo')),
          OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.gallery),
              icon: const AppIcon(Icons.photo_library),
              label: const Text('Upload photo')),
        ]),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!, style: AppText.body(AppColors.danger))),
        if (_busy) const LinearProgressIndicator(),
        const SizedBox(height: 8),
        Text(
            _duo
                ? 'Each of you adds one photo. The completed strip is shared in chat and on the home screen widget for 24 hours.'
                : 'Your completed strip is shared in chat and on the home screen widget for 24 hours.',
            style: AppText.caption()),
        const SizedBox(height: 8),
        FilledButton(
            onPressed: _busy || _photo == null || pair?.isLinked != true
                ? null
                : _submit,
            child: Text(_joining != null
                ? 'Add my half & share'
                : _duo
                    ? 'Save my half for $theirName'
                    : 'Create & share strip')),
        const SizedBox(height: 24),
        Text('Waiting strips', style: AppText.title()),
        open.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => _retry('Could not load waiting strips.',
              () => ref.invalidate(openStripsProvider)),
          data: (strips) => strips.isEmpty
              ? const Text('No strips waiting for a photo.')
              : Column(children: [
                  for (final strip in strips)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(strip.style.name,
                                      style: AppText.subtitle()),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                      height: 140,
                                      width: double.infinity,
                                      child: _StoredPhoto(path: strip.aPath)),
                                  const SizedBox(height: 8),
                                  Text(strip.isFullButUnposted
                                      ? 'Both photos saved. Finish sharing your strip.'
                                      : strip.aUser == userId
                                          ? 'Your photo is saved. Waiting for $theirName.'
                                          : '$theirName added a photo. Add yours to finish.'),
                                  if (strip.isFullButUnposted)
                                    TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _updateStrip(strip),
                                        child: const Text('Finish sharing'))
                                  else if (strip.aUser != userId)
                                    TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => setState(() {
                                                  _joining = strip;
                                                  _template = strip.style;
                                                  _duo = true;
                                                }),
                                        child: const Text('Join this strip')),
                                  if (strip.aUser == userId)
                                    TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _updateStrip(strip,
                                                cancel: true),
                                        child:
                                            const Text('Cancel waiting strip')),
                                ]))),
                ]),
        ),
        const SizedBox(height: 24),
        Text('Your strips', style: AppText.title()),
        if (messages.isLoading) const LinearProgressIndicator(),
        if (messages.hasError)
          _retry('Could not load your strips.',
              () => ref.invalidate(flowerMessagesProvider)),
        if (messages.hasValue && history.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child:
                  Text('Your first strip will appear here once it is shared.')),
        for (final message in history)
          Card(
              child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => MediaViewer(
                      title: message.note ?? 'Photo strip',
                      subtitle: DateFormat.yMMMd().format(message.sentAt),
                      imagePath: message.imagePath!,
                      fileName: 'dayflower-strip-${message.id}.jpg',
                    ))),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          height: 220,
                          width: double.infinity,
                          child: _StoredPhoto(path: message.imagePath!)),
                      const SizedBox(height: 8),
                      Text(message.note ?? 'Photo strip',
                          style: AppText.subtitle()),
                      Text(
                          '${DateFormat.yMMMd().format(message.sentAt)} · Open to view or save',
                          style: AppText.caption()),
                    ])),
          )),
      ])),
    );
  }

  Widget _retry(String message, VoidCallback retry) => Column(children: [
        Text(message),
        TextButton(onPressed: retry, child: const Text('Retry')),
      ]);
}

class _StoredPhoto extends ConsumerWidget {
  const _StoredPhoto({required this.path});
  final String path;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(dayPhotoUrlProvider(path)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => TextButton(
                onPressed: () => ref.invalidate(dayPhotoUrlProvider(path)),
                child: const Text('Retry photo')),
            data: (url) => url == null
                ? const Text('Photo unavailable')
                : Image.network(url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => TextButton(
                        onPressed: () =>
                            ref.invalidate(dayPhotoUrlProvider(path)),
                        child: const Text('Retry photo'))),
          );
}
