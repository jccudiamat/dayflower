import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../booth/data/strip_repository.dart';
import '../../../booth/domain/strip_templates.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../data/flower_repository.dart';
import '../../domain/flower_catalog.dart';
import 'flower_catalog_panel.dart';

/// The "Share your day" bar at the top of the Flowers tab.
///
/// Camera-first: a live viewfinder you shoot straight from, with upload on
/// the left and the flower catalog on the right. The point is that sharing
/// costs one tap — routing through a picker sheet first made the common case
/// the slow one.
///
/// A day photo lands on the partner's home-screen widget and leaves it after
/// 24 hours, while the message stays in the conversation forever. Expiry is
/// computed from `sentAt`; nothing is ever deleted.
class ShareYourDayBar extends ConsumerStatefulWidget {
  const ShareYourDayBar({super.key});

  @override
  ConsumerState<ShareYourDayBar> createState() => _ShareYourDayBarState();
}

class _ShareYourDayBarState extends ConsumerState<ShareYourDayBar>
    with WidgetsBindingObserver {
  CameraController? _cam;
  List<CameraDescription> _cameras = const [];
  CameraLensDirection _lens = CameraLensDirection.front;
  bool _camReady = false;
  bool _torchOn = false;

  /// Set when there is no usable camera — no device, permission denied, or a
  /// browser that won't hand one over. The viewfinder becomes a tap-target
  /// that falls back to the OS camera, so the feature never simply vanishes.
  bool _camUnavailable = false;

  bool _busy = false;

  /// Null means a plain day photo. Selecting a template routes the next
  /// shot through the booth compositor instead.
  StripTemplate? _template;

  /// Strip ids already handed to [_recoverStranded], so a failing retry
  /// cannot spin: the provider re-emits on every stream tick.
  final Set<String> _recoveryTried = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    super.dispose();
  }

  /// A live camera holds the sensor open, so hand it back when the app is
  /// backgrounded and take it again on resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cam == null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cam?.dispose();
      _cam = null;
      if (mounted) setState(() => _camReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    try {
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _camUnavailable = true);
        return;
      }
      final cam = _cameras.firstWhere(
        (c) => c.lensDirection == _lens,
        orElse: () => _cameras.first,
      );
      final controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cam = controller;
        _lens = cam.lensDirection;
        _camReady = true;
        _camUnavailable = false;
        // The torch belonged to the controller we just replaced.
        _torchOn = false;
      });
    } catch (_) {
      // Denied, unsupported, or already in use — fall back rather than fail.
      if (mounted) setState(() => _camUnavailable = true);
    }
  }

  bool get _canFlip => _cameras.map((c) => c.lensDirection).toSet().length > 1;

  Future<void> _flip() async {
    if (!_canFlip || _busy) return;
    final next = _lens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    final old = _cam;
    setState(() {
      _cam = null;
      _camReady = false;
      _lens = next;
    });
    await old?.dispose();
    await _startCamera();
  }

  Future<void> _toggleTorch() async {
    final cam = _cam;
    if (cam == null || !_camReady) return;
    final next = !_torchOn;
    try {
      await cam.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torchOn = next);
    } catch (_) {
      // Front cameras and most webcams have no torch at all.
      if (mounted) _toast('No flash on this camera.');
    }
  }

  // ── Sending ───────────────────────────────────────

  Future<void> _shareBytes(Uint8List bytes, String ext) async {
    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    if (pair == null || userId == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(flowerRepositoryProvider).sendDayPhoto(
            pairId: pair.id,
            senderId: userId,
            bytes: bytes,
            fileExtension: ext,
          );
      if (mounted) _toast('Shared to their home screen for 24 hours 🌼');
    } catch (_) {
      // A Storage 404 here almost always means migration 0013 has not run.
      if (mounted) _toast("Couldn't share that. Try again?");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shoot() async {
    if (_busy) return;
    final cam = _cam;
    if (cam == null || !_camReady) return _pickFrom(ImageSource.camera);
    try {
      final shot = await cam.takePicture();
      await _handleShot(await shot.readAsBytes());
    } catch (_) {
      if (mounted) _toast("Couldn't take that photo.");
    }
  }

  /// One entry point for every source, so the camera, the gallery and a
  /// "join their strip" tap all take the same route.
  Future<void> _handleShot(Uint8List bytes) async {
    final waiting = ref.read(stripAwaitingMeProvider);

    // Joining beats starting: if a half is already waiting on me, the
    // obvious meaning of pressing the shutter is "here's mine".
    if (waiting != null) return _joinStrip(waiting, bytes);

    final t = _template;
    if (t == null) return _shareBytes(bytes, 'jpg');
    return t.isDuo ? _startDuo(t, bytes) : _postSolo(t, bytes);
  }

  Future<void> _postSolo(StripTemplate t, Uint8List bytes) async {
    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    if (pair == null || userId == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(stripRepositoryProvider).postSolo(
            pairId: pair.id,
            senderId: userId,
            template: t,
            bytes: bytes,
          );
      if (mounted) _toast('${t.name} sent 🌼');
    } catch (_) {
      if (mounted) _toast("Couldn't send that strip. Try again?");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startDuo(StripTemplate t, Uint8List bytes) async {
    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    if (pair == null || userId == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(stripRepositoryProvider).startDuo(
            pairId: pair.id,
            senderId: userId,
            template: t,
            bytes: bytes,
          );
      if (mounted) _toast('Your half is up — waiting for theirs 💞');
    } catch (_) {
      if (mounted) _toast("Couldn't start that strip. Try again?");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinStrip(PhotoStrip strip, Uint8List bytes) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(stripRepositoryProvider).joinDuo(
            strip: strip,
            senderId: userId,
            bytes: bytes,
          );
      if (mounted) _toast('Strip complete 🎞️');
    } catch (_) {
      if (mounted) _toast("Couldn't finish that strip. Try again?");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTemplate() async {
    final chosen = await showModalBottomSheet<StripTemplate?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplateSheet(selected: _template),
    );
    // The sheet returns the sentinel below for "no template" so that
    // choosing Plain photo is distinguishable from dismissing the sheet.
    if (chosen == null) return;
    setState(() => _template = chosen == _kPlain ? null : chosen);
  }

  Future<void> _pickFrom(ImageSource source) async {
    if (_busy) return;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        // Resized on the way in: this is the only copy that will exist.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (file == null || !mounted) return;
      await _handleShot(await file.readAsBytes());
    } catch (_) {
      if (mounted) _toast("Couldn't open that.");
    }
  }

  Future<void> _sendFlower() async {
    if (_busy) return;
    final partner = ref.read(partnerProfileProvider).valueOrNull;
    final flower = await showModalBottomSheet<Flower>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FlowerPickSheet(),
    );
    if (flower == null || !mounted) return;

    final result = await showFlowerSendSheet(
      context,
      flower: flower,
      partnerName: partner?.petName ?? partner?.displayName ?? 'their',
    );
    if (result == null || !mounted) return;

    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    if (pair == null || userId == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(flowerRepositoryProvider).sendFlower(
            pairId: pair.id,
            senderId: userId,
            flowerType: flower.id,
            note: result.note,
            toWidget: result.toWidget,
          );
      if (mounted) _toast('${flower.name} sent 🌷');
    } catch (_) {
      if (mounted) _toast("Couldn't send ${flower.name}. Try again?");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Build ─────────────────────────────────────────

  /// Both halves are in but the composite never got posted — a send that
  /// died between filling slot B and uploading the result. Finish it rather
  /// than leaving the joiner's photo stranded in Storage forever.
  void _recoverStranded() {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    for (final s in ref.read(openStripsProvider).valueOrNull ?? const []) {
      if (!s.isFullButUnposted) continue;
      // Only the person who filled slot B has any reason to retry.
      if (s.bUser != userId) continue;
      if (!_recoveryTried.add(s.id)) continue;
      ref
          .read(stripRepositoryProvider)
          .finish(strip: s, senderId: userId)
          .catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myDayPhotoProvider);
    final theirs = ref.watch(partnerDayPhotoProvider);

    ref.listen(openStripsProvider, (_, __) => _recoverStranded());

    return Column(
      children: [
        Expanded(child: _cameraCard(mine)),
        // Below the viewfinder, not floating over it — chips inside the
        // frame read as part of the shot you are composing.
        if (mine != null || theirs != null) ...[
          const SizedBox(height: AppSpace.xs),
          _LiveDays(mine: mine, theirs: theirs),
        ],
      ],
    );
  }

  Widget _cameraCard(FlowerMessage? mine) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _preview(),

            // Controls float over the viewfinder rather than stacking around
            // it — the point of the big card is that the picture is the card.
            Positioned(
              top: AppSpace.sm,
              left: AppSpace.sm,
              right: AppSpace.sm,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SHARE YOUR DAY',
                            style: AppText.label(Colors.white)),
                        const SizedBox(height: 2),
                        Text(
                          mine == null ? 'Lasts 24 hours' : _leftLabel(mine),
                          style: AppText.caption(
                            mine == null
                                ? AppColors.onDarkMuted
                                : AppColors.brandLight,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  if (_camReady) ...[
                    _GlassButton(
                      icon: _torchOn
                          ? CupertinoIcons.bolt_fill
                          : CupertinoIcons.bolt_slash,
                      tooltip: _torchOn ? 'Flash off' : 'Flash on',
                      active: _torchOn,
                      onTap: _toggleTorch,
                    ),
                    if (_canFlip) ...[
                      const SizedBox(width: AppSpace.xs),
                      _GlassButton(
                        icon: CupertinoIcons.arrow_2_circlepath,
                        tooltip: 'Flip camera',
                        onTap: _flip,
                      ),
                    ],
                  ],
                ],
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StripBanner(onCancelMine: _cancelMyStrip),
                  _templateRow(),
                  _controls(),
                ],
              ),
            ),

            if (_busy)
              Container(
                color: Colors.black.withValues(alpha: .5),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  String _leftLabel(FlowerMessage m) {
    final left = m.widgetTimeLeft;
    if (left == null) return 'Expired';
    return left.inHours >= 1
        ? '${left.inHours} h left'
        : '${left.inMinutes} m left';
  }

  Widget _preview() {
    if (_camReady && _cam != null) {
      // cover, not contain: CameraPreview reports the sensor's aspect ratio,
      // which almost never matches the card, and letterboxing would leave
      // black bars inside a full-bleed surface.
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cam!.value.previewSize?.height ?? 1080,
          height: _cam!.value.previewSize?.width ?? 1920,
          child: CameraPreview(_cam!),
        ),
      );
    }
    return GestureDetector(
      onTap: _camUnavailable ? () => _pickFrom(ImageSource.camera) : null,
      child: ColoredBox(
        color: const Color(0xFF120C1F),
        child: Center(
          child: _camUnavailable
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.camera,
                        color: AppColors.onDarkMuted, size: 30),
                    const SizedBox(height: AppSpace.xs),
                    Text('Tap to take a photo',
                        style: AppText.caption(AppColors.onDarkMuted)),
                  ],
                )
              : const CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _cancelMyStrip() async {
    final mine = ref.read(myOpenStripProvider);
    if (mine == null) return;
    try {
      await ref.read(stripRepositoryProvider).cancel(mine.id);
      if (mounted) _toast('Strip cancelled.');
    } catch (_) {
      if (mounted) _toast("Couldn't cancel that.");
    }
  }

  /// The armed template, as a single chip. A full grid over a live camera
  /// would cover the thing you are framing, so the choosing happens in a
  /// sheet and only the choice stays on screen.
  Widget _templateRow() {
    final t = _template;
    final awaiting = ref.watch(stripAwaitingMeProvider);
    // While a half waits on you the template is theirs, not yours to pick.
    final label = awaiting != null
        ? '${awaiting.style.emoji}  ${awaiting.style.name}'
        : t == null
            ? '🖼️  Plain photo'
            : '${t.emoji}  ${t.name}${t.isDuo ? " · duo" : ""}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: awaiting != null ? null : _pickTemplate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .38),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: (t == null && awaiting == null)
                    ? Colors.white.withValues(alpha: .25)
                    : AppColors.brandLight,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppText.caption(Colors.white)),
                if (awaiting == null) ...[
                  const SizedBox(width: 6),
                  const Icon(CupertinoIcons.chevron_up_chevron_down,
                      size: 12, color: Colors.white),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Upload · shutter · flower, over a scrim so they stay readable against
  /// whatever the camera happens to be pointing at.
  Widget _controls() {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: .55)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _GlassButton(
            icon: CupertinoIcons.photo_on_rectangle,
            tooltip: 'Upload a photo',
            big: true,
            onTap: _busy ? null : () => _pickFrom(ImageSource.gallery),
          ),
          _ShutterButton(onTap: _busy ? null : _shoot),
          _GlassButton(
            icon: Icons.local_florist_rounded,
            tooltip: 'Send a flower',
            big: true,
            tint: AppColors.brandLight,
            onTap: _busy ? null : _sendFlower,
          ),
        ],
      ),
    );
  }
}

/// The big centre shutter.
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Take photo',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: .85), width: 3),
          ),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.cta,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Translucent round button used for every control over the viewfinder.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.tint,
    this.active = false,
    this.big = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? tint;
  final bool active;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 52.0 : 38.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? AppColors.brand.withValues(alpha: .85)
            : Colors.black.withValues(alpha: .35),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child:
                Icon(icon, color: tint ?? Colors.white, size: big ? 24 : 18),
          ),
        ),
      ),
    );
  }
}

/// The live days — yours and theirs — shown only while one exists.
class _LiveDays extends ConsumerWidget {
  const _LiveDays({required this.mine, required this.theirs});

  final FlowerMessage? mine;
  final FlowerMessage? theirs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final partnerName = partner?.petName ?? partner?.displayName ?? 'Theirs';

    return Row(
      children: [
        if (theirs != null) ...[
          _DayChip(message: theirs!, label: partnerName),
          const SizedBox(width: AppSpace.xs),
        ],
        if (mine != null) _DayChip(message: mine!, label: 'Yours'),
      ],
    );
  }
}

class _DayChip extends ConsumerWidget {
  const _DayChip({required this.message, required this.label});

  final FlowerMessage message;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => DayPhotoViewer(message: message, who: label),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.blushMid),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: SizedBox(
                width: 22,
                height: 22,
                child: _Thumb(message: message),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: AppText.label(AppColors.body)),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

/// Signed-URL thumbnail. The bucket is private, so there is no permanent URL
/// to cache — each render mints one that expires.
class _Thumb extends ConsumerWidget {
  const _Thumb({required this.message});
  final FlowerMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future:
          ref.read(flowerRepositoryProvider).signedPhotoUrl(message.imagePath!),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const ColoredBox(color: AppColors.surfaceSubtle);
        }
        return Image.network(
          snap.data!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.photo,
              size: 14, color: AppColors.muted),
        );
      },
    );
  }
}

/// Full-bleed viewer, opened from a day chip.
class DayPhotoViewer extends ConsumerWidget {
  const DayPhotoViewer({super.key, required this.message, required this.who});

  final FlowerMessage message;
  final String who;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = message.widgetTimeLeft;
    final leftLabel = left == null
        ? 'No longer on the home screen'
        : left.inHours >= 1
            ? '${left.inHours} h left on the home screen'
            : '${left.inMinutes} m left on the home screen';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpace.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(who, style: AppText.subtitle(Colors.white)),
                        Text(leftLabel,
                            style: AppText.caption(AppColors.onDarkMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(CupertinoIcons.xmark,
                        color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<String>(
                future: ref
                    .read(flowerRepositoryProvider)
                    .signedPhotoUrl(message.imagePath!),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  return InteractiveViewer(
                    child: Center(
                      child: Image.network(snap.data!, fit: BoxFit.contain),
                    ),
                  );
                },
              ),
            ),
            if (message.note != null && message.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Text('“${message.note}”',
                    style: AppText.note(Colors.white)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Grid of the catalog, for the flower button on the right of the bar.
class _FlowerPickSheet extends StatelessWidget {
  const _FlowerPickSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md,
          AppSpace.lg + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text('Send a flower', style: AppText.hero()),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: [
              // `pickable`, not `all`: retired flowers stay renderable for
              // old messages but must not be offered as new sends.
              for (final f in FlowerCatalog.pickable)
                GestureDetector(
                  onTap: () => Navigator.pop(context, f),
                  child: Container(
                    width: 72,
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Text(f.emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 2),
                        Text(
                          f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppText.label(),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sentinel for "no template" — lets the sheet distinguish choosing a plain
/// photo from being dismissed, which returning null alone cannot.
const _kPlain = StripTemplate(
  id: '__plain__',
  name: 'Plain photo',
  tagline: 'No frame',
  isDuo: false,
  emoji: '🖼️',
  accent: Color(0xFF8E8698),
  paper: Color(0xFFFFFFFF),
  ink: Color(0xFF1C1024),
);

/// "They started one / yours is waiting" — the async half of the feature.
///
/// This is what makes a duo strip work across timezones: the invite sits
/// here until the other person happens to open the app.
class _StripBanner extends ConsumerWidget {
  const _StripBanner({required this.onCancelMine});

  final VoidCallback onCancelMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final awaiting = ref.watch(stripAwaitingMeProvider);
    final mine = ref.watch(myOpenStripProvider);
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final name = partner?.petName ?? partner?.displayName ?? 'They';

    if (awaiting == null && mine == null) return const SizedBox.shrink();

    final joining = awaiting != null;
    final strip = awaiting ?? mine!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.md, 0, AppSpace.md, AppSpace.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm, vertical: AppSpace.xs),
        decoration: BoxDecoration(
          color: (joining ? AppColors.brand : Colors.black)
              .withValues(alpha: joining ? .85 : .45),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
        ),
        child: Row(
          children: [
            Text(strip.style.emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: Text(
                joining
                    ? '$name started a ${strip.style.name} — shoot your half'
                    : 'Waiting for $name to add their half',
                maxLines: 2,
                style: AppText.caption(Colors.white)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (!joining) ...[
              const SizedBox(width: AppSpace.xs),
              GestureDetector(
                onTap: onCancelMine,
                child: Text('Cancel',
                    style: AppText.caption(AppColors.brandLight)
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Template chooser. Duo templates are listed first and labelled, because
/// picking one commits your partner to a second shot.
class _TemplateSheet extends StatelessWidget {
  const _TemplateSheet({required this.selected});

  final StripTemplate? selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md,
          AppSpace.lg + MediaQuery.paddingOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Text('Booth templates', style: AppText.hero()),
            const SizedBox(height: 4),
            Text(
              'Duo templates wait for their half — they can add it whenever '
              'they wake up.',
              style: AppText.caption(),
            ),
            const SizedBox(height: AppSpace.md),
            _Tile(
              template: _kPlain,
              selected: selected == null,
              onTap: () => Navigator.pop(context, _kPlain),
            ),
            const SizedBox(height: AppSpace.md),
            Text('TOGETHER', style: AppText.label()),
            const SizedBox(height: AppSpace.xs),
            for (final t in StripTemplate.duo) ...[
              _Tile(
                template: t,
                selected: selected?.id == t.id,
                onTap: () => Navigator.pop(context, t),
              ),
              const SizedBox(height: AppSpace.xs),
            ],
            const SizedBox(height: AppSpace.xs),
            Text('ON YOUR OWN', style: AppText.label()),
            const SizedBox(height: AppSpace.xs),
            for (final t in StripTemplate.solo) ...[
              _Tile(
                template: t,
                selected: selected?.id == t.id,
                onTap: () => Navigator.pop(context, t),
              ),
              const SizedBox(height: AppSpace.xs),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final StripTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.xs + 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            // design.md: selection is a tinted outline, never a fill swap.
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: template.accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(AppRadius.sm - 4),
                ),
                child:
                    Text(template.emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(template.name,
                        style: AppText.body(AppColors.ink)
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text(template.tagline, style: AppText.caption()),
                  ],
                ),
              ),
              if (selected)
                const Icon(CupertinoIcons.checkmark_alt,
                    size: 16, color: AppColors.brand),
            ],
          ),
        ),
      ),
    );
  }
}
