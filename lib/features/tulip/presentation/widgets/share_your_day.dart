import 'dart:typed_data';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../booth/data/strip_repository.dart';
import '../../../booth/domain/strip_templates.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../data/flower_repository.dart';

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

  /// The shot that has been taken but not sent.
  ///
  /// Pressing the shutter used to upload immediately, which made every
  /// mis-tap a photo on someone's home screen for 24 hours. Now the frame
  /// is held here, the viewfinder freezes on it, and nothing leaves the
  /// device until the send button is pressed and a destination chosen.
  Uint8List? _pending;
  String _pendingExt = 'jpg';

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

  Future<void> _shareBytes(
    Uint8List bytes,
    String ext, {
    bool toWidget = true,
  }) async {
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
            toWidget: toWidget,
          );
      if (mounted) {
        _toast(toWidget
            ? 'Shared to their home screen for 24 hours 🌼'
            : 'Sent to the conversation 💬');
      }
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
      final bytes = await shot.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pending = bytes;
        _pendingExt = 'jpg';
      });
    } catch (_) {
      if (mounted) _toast("Couldn't take that photo.");
    }
  }

  /// Throws the held shot away and goes back to the live viewfinder.
  void _discardPending() => setState(() => _pending = null);

  /// Writes the held shot to the app's own external folder.
  ///
  /// ⚠️ Not the system gallery: putting a file there needs MediaStore on
  /// modern Android, which needs a plugin. This keeps the photo without
  /// adding one, and the toast says where it went rather than implying it
  /// landed in Photos.
  Future<void> _savePending() async {
    final bytes = _pending;
    if (bytes == null) return;
    try {
      final base = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/Saved');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File(
        '${dir.path}/day_${DateTime.now().millisecondsSinceEpoch}.$_pendingExt',
      );
      await file.writeAsBytes(bytes);
      if (mounted) _toast('Saved a copy to the app folder.');
    } catch (_) {
      if (mounted) _toast("Couldn't save that.");
    }
  }

  /// Asks where the shot should go, then sends it there.
  ///
  /// Chat-only and home-screen are genuinely different acts — one is a
  /// message, the other parks a photo on someone's home screen for a day —
  /// so the choice is made explicitly rather than inferred from a setting.
  Future<void> _sendPending() async {
    final bytes = _pending;
    if (bytes == null || _busy) return;

    final toWidget = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SendTargetSheet(),
    );
    if (toWidget == null || !mounted) return;

    await _handleShot(bytes, toWidget: toWidget);
    if (mounted) setState(() => _pending = null);
  }

  /// One entry point for every source, so the camera, the gallery and a
  /// "join their strip" tap all take the same route.
  Future<void> _handleShot(Uint8List bytes, {bool toWidget = true}) async {
    final waiting = ref.read(stripAwaitingMeProvider);

    // Joining beats starting: if a half is already waiting on me, the
    // obvious meaning of pressing the shutter is "here's mine".
    if (waiting != null) return _joinStrip(waiting, bytes);

    final t = _template;
    if (t == null) return _shareBytes(bytes, _pendingExt, toWidget: toWidget);
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
      // Held for review like a fresh shot, rather than uploaded on the
      // spot. Picking the wrong photo from a grid of thumbnails is at
      // least as easy as mis-tapping the shutter.
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pending = bytes;
        _pendingExt = (file.path.split('.').last.toLowerCase() == 'png')
            ? 'png'
            : 'jpg';
      });
    } catch (_) {
      if (mounted) _toast("Couldn't open that.");
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

    ref.listen(openStripsProvider, (_, __) => _recoverStranded());

    // The "your day / their day" chips used to sit under the viewfinder.
    // The home screen's arch now shows both, and saying it twice made this
    // screen about reviewing rather than shooting.
    return _cameraCard(mine);
  }

  Widget _cameraCard(FlowerMessage? mine) {
    // Rounded only at the top: the card now runs to both edges and into the
    // nav bar, so rounding the bottom would leave two slivers of background
    // beside it.
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
      child: Container(
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_pending != null)
              Image.memory(_pending!, fit: BoxFit.cover)
            else
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
                    child: _pending != null
                        ? const SizedBox.shrink()
                        : Column(
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
                  // While a shot is held, the two controls that acted on
                  // the live camera are replaced by the two that act on the
                  // frame — same corner, so the thumb does not have to
                  // learn a second place to look.
                  if (_pending != null) ...[
                    _GlassButton(
                      icon: CupertinoIcons.xmark,
                      tooltip: 'Discard',
                      onTap: _busy ? null : _discardPending,
                    ),
                    const SizedBox(width: AppSpace.xs),
                    _GlassButton(
                      icon: CupertinoIcons.arrow_down_to_line,
                      tooltip: 'Save a copy',
                      onTap: _busy ? null : _savePending,
                    ),
                  ] else if (_camReady) ...[
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

  /// The template picker, as a scrollable row of circles.
  ///
  /// The old design hid these behind a chip that opened a sheet, on the
  /// grounds that a grid would cover the shot you were framing. A single
  /// row of thumbnails costs one strip of the frame and makes the choice
  /// visible while you compose, which is how every camera app does it.
  Widget _templateRow() {
    final awaiting = ref.watch(stripAwaitingMeProvider);

    // While a half waits on you the template is theirs, not yours to pick —
    // the strip becomes a statement of what you are joining.
    if (awaiting != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md, vertical: AppSpace.xs),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .38),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.brandLight),
            ),
            child: Text(
              'Joining ${awaiting.style.emoji} ${awaiting.style.name}',
              style: AppText.caption(Colors.white),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 74,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        children: [
          _TemplateDot(
            label: 'Plain',
            emoji: '📷',
            selected: _template == null,
            onTap: () => setState(() => _template = null),
          ),
          for (final t in StripTemplate.all)
            _TemplateDot(
              label: t.isDuo ? '${t.name} · duo' : t.name,
              emoji: t.emoji,
              paper: t.paper,
              accent: t.accent,
              selected: _template?.id == t.id,
              onTap: () => setState(() => _template = t),
            ),
        ],
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
            onTap: (_busy || _pending != null)
                ? null
                : () => _pickFrom(ImageSource.gallery),
          ),
          // The same button in the same place, because it is the same
          // gesture continued: take the picture, then send the picture.
          _ShutterButton(
            sending: _pending != null,
            onTap: _busy ? null : (_pending != null ? _sendPending : _shoot),
          ),
          // Balances the row where the flower button used to sit. The
          // flower moved out with the templates coming in — this screen is
          // the camera now, and sending a flower is a different errand.
          const SizedBox(width: 46),
        ],
      ),
    );
  }
}

/// The big centre shutter.
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onTap, this.sending = false});
  final VoidCallback? onTap;

  /// True once a shot is held: the ring becomes a send button.
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: sending ? 'Send photo' : 'Take photo',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.standard,
          curve: AppMotion.easeOut,
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
              // The gradient disc stays; only its contents change, so the
              // control reads as the same button doing the next step
              // rather than a different button appearing.
              child: sending
                  ? const Icon(CupertinoIcons.paperplane_fill,
                      color: Colors.white, size: 26)
                  : null,
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
    this.active = false,
    this.big = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
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
                Icon(icon, color: Colors.white, size: big ? 24 : 18),
          ),
        ),
      ),
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

/// Sentinel for "no template" — lets the sheet distinguish choosing a plain
/// photo from being dismissed, which returning null alone cannot.

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

/// One template in the horizontal picker.
///
/// A circle rather than a card: the row sits over a live viewfinder, and
/// circles read as controls while rectangles read as content you might have
/// already shot.
class _TemplateDot extends StatelessWidget {
  const _TemplateDot({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
    this.paper,
    this.accent,
  });

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  /// The template's own paper and accent, so the dot previews the look
  /// instead of being a generic swatch. Null for the plain-photo option.
  final Color? paper;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppMotion.micro,
                curve: AppMotion.easeOut,
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: paper ?? Colors.black.withValues(alpha: .38),
                  border: Border.all(
                    color: selected
                        ? Colors.white
                        : (accent ?? Colors.white).withValues(alpha: .35),
                    width: selected ? 2.5 : 1.2,
                  ),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 58,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppText.label(
                    selected ? Colors.white : Colors.white70,
                  ).copyWith(fontSize: 8.5, letterSpacing: 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the held shot should go.
///
/// Two genuinely different acts, so they are two buttons rather than a
/// toggle someone sets once and forgets: a chat photo is a message, a home
/// screen photo parks itself on their phone for a day.
class _SendTargetSheet extends StatelessWidget {
  const _SendTargetSheet();

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Send it where?',
      subtitle: 'You can always send the other way next time',
      child: Column(
        children: [
          _SendOption(
            emoji: '🏠',
            title: 'Their home screen',
            blurb: 'Lands on the widget and in the chat. Gone after 24 hours.',
            onTap: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: AppSpace.xs),
          _SendOption(
            emoji: '💬',
            title: 'Just the conversation',
            blurb: 'Stays in the thread. Nothing changes on their home screen.',
            onTap: () => Navigator.pop(context, false),
          ),
          const SizedBox(height: AppSpace.xs),
        ],
      ),
    );
  }
}

class _SendOption extends StatelessWidget {
  const _SendOption({
    required this.emoji,
    required this.title,
    required this.blurb,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String blurb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: double.infinity,
          padding: AppSpace.card,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppText.subtitle(AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(blurb, style: AppText.caption()),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.chevron_forward,
                  size: 18, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
