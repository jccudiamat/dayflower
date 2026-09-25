import 'package:dayflower/core/widgets/app_icon.dart';
import 'dart:typed_data';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../booth/data/strip_repository.dart';
import '../../../booth/domain/strip_templates.dart';
import '../../../../core/frames/photo_frames.dart';
import '../../../../core/frames/frame_compositor.dart';
import '../screens/templates_screen.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../data/flower_repository.dart';
import '../../domain/camera_lifecycle.dart';
import '../../domain/day_reactions.dart';
import '../../../../core/widgets/storage_image.dart';

/// Where the next shot goes.
///
/// ⚠️ Lifted out of the camera's own State so somebody arriving *at* the
/// camera can say. The chat's camera button opens this screen already set to
/// the conversation — walking into a camera that is pointed at the home
/// screen widget when you came from the thread is a trap you only notice
/// after sending.
///
/// Widget is still the default, because parking a photo on their home screen
/// is what "share your day" means; the thread copy is the extra.
final dayPhotoTargetProvider =
    StateProvider<DayPhotoTarget>((ref) => DayPhotoTarget.myDay);

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

  /// Bumped every time the camera is opened or closed. An `initialize()`
  /// that lands after its generation has passed belongs to a controller
  /// nobody wants any more, so it disposes itself instead of taking the
  /// sensor back — otherwise a pause during startup leaves a live camera
  /// held while the app is in the background.
  int _camGen = 0;

  /// Serialises opening and closing. Two controllers on one sensor is an
  /// Android "camera in use" failure, and pause/resume can easily arrive
  /// faster than `initialize()` returns.
  Future<void> _camOps = Future<void>.value();

  /// The shot that has been taken but not sent.
  ///
  /// Pressing the shutter used to upload immediately, which made every
  /// mis-tap a photo on someone's home screen for 24 hours. Now the frame
  /// is held here, the viewfinder freezes on it, and nothing leaves the
  /// device until the send button is pressed and a destination chosen.
  /// Where the next send goes. Widget first because parking a photo on
  /// their home screen is what "share your day" means — the thread copy is
  /// the extra, not the point.
  DayPhotoTarget get _target => ref.read(dayPhotoTargetProvider);

  Uint8List? _pending;
  String _pendingExt = 'jpg';

  /// Null means a plain day photo. Selecting a template routes the next
  /// shot through the booth compositor instead.
  StripTemplate? _template;

  /// The paper the next shot is taken on, or null for a bare photo.
  PhotoFrame? _frame;

  /// The frames offered under the shutter: the ones that take exactly one
  /// photo, because one press of the shutter is one photo.
  static final _quickFrames = framesForPhotos(1).toList();

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
    _camGen++;
    _cam?.dispose();
    _cam = null;
    super.dispose();
  }

  /// A live camera holds the sensor open, so hand it back when the app is
  /// backgrounded and take it again on resume.
  ///
  /// ⚠️ **Never guard this on `_cam`.** See [cameraActionFor] — a
  /// `if (_cam == null) return` here reads as "nothing to hand back", but
  /// pausing is what sets it to null, so it silently ate every resume and
  /// the viewfinder never came back from the gallery picker.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (cameraActionFor(state)) {
      case CameraLifecycleAction.open:
        _startCamera();
      case CameraLifecycleAction.close:
        _stopCamera();
    }
  }

  /// Hands the sensor back and invalidates any open still in flight.
  Future<void> _stopCamera() {
    _camGen++;
    final old = _cam;
    _cam = null;
    if (mounted) {
      setState(() => _camReady = false);
    } else {
      _camReady = false;
    }
    return _queue(() async => old?.dispose());
  }

  Future<void> _startCamera() {
    // Claimed now, not when the queue reaches us: a pause arriving in the
    // meantime has to be able to invalidate this open before it starts.
    final gen = ++_camGen;
    return _queue(() => _open(gen));
  }

  /// Runs camera work one piece at a time. A failure is swallowed here
  /// because each operation already reports its own — what must not happen
  /// is a broken chain, which would wedge every later open.
  Future<void> _queue(Future<void> Function() op) =>
      _camOps = _camOps.then((_) => op()).catchError((_) {});

  Future<void> _open(int gen) async {
    if (gen != _camGen) return;
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
      // Superseded while we were waiting — a pause, a flip, or a teardown.
      // Whoever moved on is not going to dispose this one for us.
      if (!mounted || gen != _camGen) {
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
      if (mounted && gen == _camGen) setState(() => _camUnavailable = true);
    }
  }

  bool get _canFlip => _cameras.map((c) => c.lensDirection).toSet().length > 1;

  Future<void> _flip() async {
    if (!_canFlip || _busy) return;
    _lens = _lens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    await _stopCamera();
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
    DayPhotoTarget target = DayPhotoTarget.myDay,
  }) async {
    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    if (pair == null || userId == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(flowerRepositoryProvider).sendDayPhotoTo(
            pairId: pair.id,
            senderId: userId,
            bytes: bytes,
            fileExtension: ext,
            target: target,
          );
      if (mounted) {
        _toast(switch (target) {
          DayPhotoTarget.myDay => 'On their home screen for 24 hours 🌼',
          DayPhotoTarget.chat => 'Sent to the conversation 💬',
        });
        // 🔴 Straight back where the camera was opened from. Sending used to
        // leave you on a live viewfinder with a toast over it, so the only
        // way to see what you had just sent was to find your own way back —
        // and the obvious reading of a still camera is that nothing was
        // sent at all.
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
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
    if (cam == null || !_camReady) {
      // Only when there genuinely is no camera to use. While one is still
      // opening, a shutter tap that launches the phone's camera app is not
      // a fallback — it is a different app arriving in your face, which is
      // exactly what the lifecycle bug above used to cause. Otherwise try
      // again, so a viewfinder stuck on its spinner has a way out.
      if (_camUnavailable) return _pickFrom(ImageSource.camera);
      return _startCamera();
    }
    try {
      final shot = await cam.takePicture();
      var bytes = await shot.readAsBytes();

      // The front camera hands back the selfie view — mirrored, so writing
      // reads backwards and a parting swaps sides. The preview stays
      // mirrored because that is what people expect to see while framing;
      // only the saved frame is corrected. Off the UI thread: decoding and
      // re-encoding a 1600px JPEG janks the shutter animation otherwise.
      if (_lens == CameraLensDirection.front) {
        bytes = await compute(unmirrorJpeg, bytes);
      }

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
  /// Sends the held shot to whatever the dropdown says.
  ///
  /// The destination is picked before the shutter, not asked for after it:
  /// a confirmation sheet on every send is a tax on the common case, and
  /// the pill is on screen the whole time you are framing.
  Future<void> _sendPending() async {
    final bytes = _pending;
    if (bytes == null || _busy) return;

    // Seven live days is the ceiling. The eighth is allowed — it just costs
    // the oldest one its place on the home screen, and that is worth asking
    // about rather than doing quietly.
    if (_target.toWidget && !await _makeRoomForDay()) return;

    await _handleShot(bytes, target: _target);
    if (mounted) setState(() => _pending = null);
  }

  /// Clears a slot if all seven are taken. False means the user backed out.
  ///
  /// ⚠️ Retiring is not deleting. The oldest day comes **off the widget** and
  /// stays in the conversation exactly where it was — the photo is a message
  /// first and a home-screen decoration second, and the eighth post should
  /// not be able to destroy the first.
  Future<bool> _makeRoomForDay() async {
    final mine = ref.read(myDayPhotosProvider);
    if (mine.length < maxLiveDays) return true;

    final oldest = mine.last;
    final left = oldest.widgetTimeLeft;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('That makes eight'),
            content: Text(
              'You can have $maxLiveDays days up at once. Posting this one '
              'takes your oldest off the home screen'
              '${left == null ? '' : ' (it had '
                  '${left.inHours >= 1 ? '${left.inHours} h' : '${left.inMinutes} m'} left)'}'
              '.\n\nIt stays in your conversation either way.',
              style: AppText.body(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Post it'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return false;

    try {
      await ref.read(flowerRepositoryProvider).retireDayPhoto(oldest.id);
      return true;
    } catch (e) {
      // ⚠️ Refuses rather than posting anyway. Sending on a failed retire
      // would leave eight live days and a limit that means nothing.
      debugPrint('retire day failed: $e');
      if (mounted) _toast("Couldn't make room. Try again?");
      return false;
    }
  }

  /// One entry point for every source, so the camera, the gallery and a
  /// "join their strip" tap all take the same route.
  Future<void> _handleShot(
    Uint8List bytes, {
    DayPhotoTarget target = DayPhotoTarget.myDay,
  }) async {
    final waiting = ref.read(stripAwaitingMeProvider);

    // Joining beats starting: if a half is already waiting on me, the
    // obvious meaning of pressing the shutter is "here's mine".
    if (waiting != null) return _joinStrip(waiting, bytes);

    final t = _template;
    if (t != null) {
      return t.isDuo ? _startDuo(t, bytes) : _postSolo(t, bytes);
    }

    // On paper, if paper was chosen. Baked into the picture rather than
    // kept as a layer: it is sent as an ordinary day photo, so the widget,
    // the thread and a copy saved to the gallery all have to be the same
    // image. See FrameCompositor.
    final frame = _frame;
    if (frame != null) {
      try {
        final framed = await FrameCompositor.compose(
          frame: frame,
          photos: [bytes],
        );
        return _shareBytes(framed, 'png', target: target);
      } catch (e) {
        // The photo is the point and the paper is the decoration, so a
        // compositor that fails sends the picture rather than nothing.
        debugPrint('frame compositing failed: $e');
      }
    }
    return _shareBytes(bytes, _pendingExt, target: target);
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
      if (mounted) _toast('Your half is up. Waiting for theirs 💞');
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
        _pendingExt =
            (file.path.split('.').last.toLowerCase() == 'png') ? 'png' : 'jpg';
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

            // Top row: who this is and the way out on the left, the
            // destination in the middle. The camera's own controls moved to
            // a vertical rail down the right, where a thumb reaches them
            // without crossing the shot.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm, vertical: AppSpace.xs),
                  child: Row(
                    children: [
                      _GlassButton(
                        icon: CupertinoIcons.xmark,
                        tooltip: 'Close',
                        onTap: () => context.canPop() ? context.pop() : context.go(Routes.home),
                      ),
                      const SizedBox(width: AppSpace.xs),
                      // Named after where this shot is going, not after the
                      // feature. Arriving from the thread and reading "My
                      // Day" above the viewfinder is exactly how someone
                      // concludes their photo went somewhere it did not.
                      Text(
                        switch (ref.watch(dayPhotoTargetProvider)) {
                          DayPhotoTarget.myDay => 'My Day',
                          DayPhotoTarget.chat => 'Send a photo',
                        },
                        style: AppText.title(Colors.white),
                      ),
                      // 🔴 The destination pill is gone. Where a photo
                      // goes is decided by where the camera was opened
                      // from — the thread, or My Day — and asking again
                      // here only offered a way to contradict that. The
                      // title beside it already says which one this is.
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),

            // The vertical rail. Same corner whether the camera is live or
            // a shot is held — only what the buttons do changes, so the
            // thumb never has to learn a second place to look.
            Positioned(
              top: 0,
              bottom: 0,
              right: AppSpace.sm,
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_pending != null) ...[
                        _GlassButton(
                          icon: CupertinoIcons.xmark_circle,
                          tooltip: 'Discard',
                          big: true,
                          onTap: _busy ? null : _discardPending,
                        ),
                        const SizedBox(height: AppSpace.sm),
                        _GlassButton(
                          icon: CupertinoIcons.arrow_down_to_line,
                          tooltip: 'Save a copy',
                          big: true,
                          onTap: _busy ? null : _savePending,
                        ),
                      ] else if (_camReady) ...[
                        _GlassButton(
                          icon: CupertinoIcons.arrow_2_circlepath,
                          tooltip: 'Flip camera',
                          big: true,
                          onTap: _canFlip ? _flip : null,
                        ),
                        const SizedBox(height: AppSpace.sm),
                        _GlassButton(
                          icon: _torchOn
                              ? CupertinoIcons.bolt_fill
                              : CupertinoIcons.bolt_slash,
                          tooltip: _torchOn ? 'Flash off' : 'Flash on',
                          big: true,
                          active: _torchOn,
                          onTap: _toggleTorch,
                        ),
                      ],
                    ],
                  ),
                ),
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
                  _chosenBanner(),
                  _controls(),
                  _modeRow(),
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
      // A spinner that never resolves is the one state with no way out of
      // it, so tapping it asks for the camera again.
      onTap: _camUnavailable
          ? () => _pickFrom(ImageSource.camera)
          : () => _startCamera(),
      child: ColoredBox(
        color: const Color(0xFF120C1F),
        child: Center(
          child: _camUnavailable
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(CupertinoIcons.camera,
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

  /// What the shot is being taken on, when it is not a bare photo.
  ///
  /// Says it once, above the controls, rather than relying on a lit ring in
  /// the row: a strip chosen on the Templates page has no dot to light.
  Widget _chosenBanner() {
    final awaiting = ref.watch(stripAwaitingMeProvider);
    // While a half waits on you the template is theirs, not yours to pick.
    final text = awaiting != null
        ? 'Joining ${awaiting.style.emoji} ${awaiting.style.name}'
        : _template != null
            ? '${_template!.emoji} ${_template!.name}'
            : null;
    if (text == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: GestureDetector(
        onTap:
            awaiting != null ? null : () => setState(() => _template = null),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .38),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.brandLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: AppText.caption(Colors.white)),
              if (awaiting == null) ...[
                const SizedBox(width: 6),
                const AppIcon(CupertinoIcons.xmark,
                    size: 11, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Upload, the shutter, and the frames beside it.
  ///
  /// The frames sit to the right of the shutter and scroll, the way a camera
  /// app puts its filters there: the choice stays visible while you compose,
  /// and the row can grow without pushing anything else off the screen. The
  /// old design gave the whole width to a row of strip styles above the
  /// controls, which cost a strip of the viewfinder.
  Widget _controls() {
    final picking = _busy || _pending != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.compact, AppSpace.sm, AppSpace.compact, AppSpace.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: .55)],
        ),
      ),
      child: Row(
        children: [
          _GlassButton(
            icon: CupertinoIcons.photo_on_rectangle,
            tooltip: 'Upload a photo',
            onTap: picking ? null : () => _pickFrom(ImageSource.gallery),
          ),
          const SizedBox(width: AppSpace.xs),
          // The same button in the same place, because it is the same
          // gesture continued: take the picture, then send the picture.
          _ShutterButton(
            sending: _pending != null,
            onTap: _busy ? null : (_pending != null ? _sendPending : _shoot),
          ),
          const SizedBox(width: AppSpace.xs),
          Expanded(child: _frameRow()),
        ],
      ),
    );
  }

  /// The paper you can shoot onto, as a scrolling row of round previews.
  Widget _frameRow() {
    // A strip is already a frame with photos in it, so it takes the row's
    // place rather than sitting beside it.
    if (_template != null || ref.watch(stripAwaitingMeProvider) != null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FrameDot(
            label: 'Plain',
            selected: _frame == null,
            onTap: () => setState(() => _frame = null),
          ),
          for (final frame in _quickFrames)
            _FrameDot(
              label: frame.name,
              frame: frame,
              selected: _frame?.id == frame.id,
              onTap: () => setState(() => _frame = frame),
            ),
        ],
      ),
    );
  }

  /// Camera or Templates, the way a camera app names its modes.
  ///
  /// Scrollable rather than a fixed pair, so a third mode could be added
  /// without redesigning the row. Tapping Templates opens the page and comes
  /// back with whatever was picked.
  Widget _modeRow() {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: Padding(
          // The space at the bottom: the row used to sit against the gesture
          // bar, where a swipe up was as likely to leave the app as to press
          // anything.
          padding: const EdgeInsets.symmetric(vertical: AppSpace.compact),
          child: SizedBox(
            height: 24,
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpace.screenInset),
              children: [
                const _ModeLabel(label: 'CAMERA', selected: true),
                const SizedBox(width: 26),
                _ModeLabel(
                    label: 'TEMPLATES',
                    selected: false,
                    onTap: _openTemplates),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The Templates page, and whatever it hands back.
  Future<void> _openTemplates() async {
    final choice = await context.push<TemplateChoice>(Routes.templates);
    if (!mounted || choice == null) return;
    setState(() {
      // Either, never both: see _frame.
      if (choice is FrameChoice) {
        _frame = choice.frame;
        _template = null;
      } else if (choice is StripChoice) {
        _template = choice.template;
        _frame = null;
      }
    });
  }
}

/// One frame under the shutter: its artwork in a circle, lit when chosen.
class _FrameDot extends StatelessWidget {
  const _FrameDot({
    required this.label,
    required this.selected,
    required this.onTap,
    this.frame,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Null for "Plain", which is a photo with no paper behind it.
  final PhotoFrame? frame;

  @override
  Widget build(BuildContext context) {
    final art = frame;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .14),
              border: Border.all(
                color: selected ? Colors.white : Colors.white24,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: art == null
                ? const AppIcon(CupertinoIcons.circle,
                    size: 17, color: Colors.white)
                : Padding(
                    padding: const EdgeInsets.all(5),
                    child: Image.asset(art.asset,
                        fit: BoxFit.contain, excludeFromSemantics: true),
                  ),
          ),
        ),
      ),
    );
  }
}

/// CAMERA, TEMPLATES. The one you are on is white and the rest are faded,
/// the way every camera app labels its modes.
class _ModeLabel extends StatelessWidget {
  const _ModeLabel({
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Text(
            label,
            style: AppText.label(selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: .45))
                .copyWith(fontSize: 13, letterSpacing: 1.4),
          ),
        ),
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
                  ? const AppIcon(CupertinoIcons.paperplane_fill,
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
            child: AppIcon(icon, color: Colors.white, size: big ? 24 : 18),
          ),
        ),
      ),
    );
  }
}

/// Full-bleed viewer, opened from a day chip.
/// All of my live days, swipeable, ending on the camera.
///
/// ⚠️ The last page is **"share your day"**, not another photo. Reaching the
/// end of your own days and finding the way to add one there is how every
/// story rail works, and it means the add button does not have to live
/// somewhere else as well.
///
/// Each page keeps its own countdown because each day is its own message
/// with its own `sentAt` — see [myDayPhotosProvider].
class MyDaysViewer extends ConsumerStatefulWidget {
  const MyDaysViewer({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<MyDaysViewer> createState() => _MyDaysViewerState();
}

class _MyDaysViewerState extends ConsumerState<MyDaysViewer> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(myDayPhotosProvider);

    // Every day gone while this was open — expired, or retired by an eighth
    // post. Nothing left to page through, so the camera is the whole screen.
    final count = days.length + 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: count,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => i == days.length
                ? const _AddDayPage()
                : DayPhotoViewer(
                    message: days[i],
                    who: 'Your day',
                    embedded: true,
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: _PageDots(count: count, index: _index),
          ),
        ],
      ),
    );
  }
}

/// The last page: a way back to the camera.
class _AddDayPage extends StatelessWidget {
  const _AddDayPage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              context.push(Routes.flowers);
            },
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.cta,
              ),
              child: const AppIcon(CupertinoIcons.camera_fill,
                  color: Colors.white, size: 34),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text('Share your day', style: AppText.hero(Colors.white)),
          const SizedBox(height: AppSpace.xxs),
          Text(
            'Up to $maxLiveDays at a time',
            style: AppText.caption(AppColors.onDarkMuted),
          ),
        ],
      ),
    );
  }
}

/// One dot per page, so the rail says how many there are.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppMotion.micro,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: i == index ? .95 : .4),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}

class DayPhotoViewer extends ConsumerStatefulWidget {
  const DayPhotoViewer({
    super.key,
    required this.message,
    required this.who,
    this.embedded = false,
  });

  final FlowerMessage message;
  final String who;

  /// True when this is one page of [MyDaysViewer] rather than a route of its
  /// own. ⚠️ Drops its own Scaffold and close button — nesting a Scaffold per
  /// page paints a second background over the pager, and a close button on
  /// every page would sit in a different place from the one that actually
  /// closes it.
  final bool embedded;

  @override
  ConsumerState<DayPhotoViewer> createState() => _DayPhotoViewerState();
}

class _DayPhotoViewerState extends ConsumerState<DayPhotoViewer> {
  final _reply = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final left = message.widgetTimeLeft;
    final leftLabel = left == null
        ? 'No longer on the home screen'
        : left.inHours >= 1
            ? '${left.inHours} h left on the home screen'
            : '${left.inMinutes} m left on the home screen';

    // You do not reply to your own day. Instagram hides the bar on your own
    // story for the same reason: there is nobody on the other end of it.
    final isMine = message.senderId == ref.watch(currentUserIdProvider);

    if (widget.embedded) return _body(context, message, leftLabel, isMine);

    return Scaffold(
      backgroundColor: Colors.black,
      // The bar has to ride the keyboard, and `resizeToAvoidBottomInset`
      // alone would squash the photo instead of moving the bar.
      resizeToAvoidBottomInset: false,
      body: _body(context, message, leftLabel, isMine),
    );
  }

  Widget _body(
    BuildContext context,
    FlowerMessage message,
    String leftLabel,
    bool isMine,
  ) {
    return SafeArea(
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
                      Text(widget.who, style: AppText.subtitle(Colors.white)),
                      // ⚠️ Each day's own clock. They are separate messages
                      // with separate timestamps, so paging from one to the
                      // next changes this line — the fifth expires five
                      // posts after the first.
                      Text(leftLabel,
                          style: AppText.caption(AppColors.onDarkMuted)),
                    ],
                  ),
                ),
                // ⚠️ Yours only, and it shows in the pager too — unlike
                // the close button, which the pager owns. Deleting is about
                // *this* photo, so it belongs on the page showing it.
                if (isMine)
                  IconButton(
                    onPressed: () => _confirmDelete(message),
                    tooltip: 'Delete this day',
                    icon: const AppIcon(CupertinoIcons.delete,
                        color: Colors.white, size: 19),
                  ),
                // One close button, owned by the pager. A per-page one would
                // sit in the same place and mean something different.
                if (!widget.embedded)
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const AppIcon(CupertinoIcons.xmark,
                        color: Colors.white, size: 20),
                  ),
              ],
            ),
          ),
          Expanded(
            // ⚠️ A photo that no longer exists still ends in "unavailable",
            // never a spinner that runs forever - StorageImage's error path
            // is a finished state, as the old hasError check made this one.
            child: InteractiveViewer(
              child: Center(
                child: StorageImage.dayPhoto(
                  message.imagePath!,
                  fit: BoxFit.contain,
                  decodeWidth: MediaQuery.sizeOf(context).width * 2,
                  placeholder:
                      const CircularProgressIndicator(color: Colors.white),
                  error: (retry) => GestureDetector(
                    onTap: retry,
                    child: Text('Photo unavailable',
                        style: AppText.body(AppColors.onDarkMuted)),
                  ),
                ),
              ),
            ),
          ),
          if (message.note != null && message.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md, vertical: AppSpace.xs),
              child:
                  Text('“${message.note}”', style: AppText.note(Colors.white)),
            ),
          if (!isMine)
            Padding(
              // Lifted by the keyboard when there is one, so the field
              // being typed into is never behind it.
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: _ReplyBar(
                controller: _reply,
                focus: _focus,
                busy: _sending,
                onSend: _sendText,
                onReact: _sendReaction,
              ),
            ),
          // Room for the pager's dots.
          if (widget.embedded) const SizedBox(height: 28),
        ],
      ),
    );
  }

  /// Deletes this day, for both of you.
  ///
  /// ⚠️ Confirmed first. This is the one destructive control in the viewer
  /// and it sits next to a close button — a mis-tap should not be able to
  /// take a photo away permanently.
  ///
  /// ⚠️ It leaves the *thread* as well, not just the home screen. Retiring
  /// (the seven-day limit) and deleting are different acts: one takes a
  /// photo off the widget and keeps the message, the other takes the message
  /// back.
  Future<void> _confirmDelete(FlowerMessage message) async {
    final yes = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete this day?'),
            content: Text(
              'It leaves your conversation as well as the home screen, for '
              'both of you.',
              style: AppText.body(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text('Delete', style: AppText.body(AppColors.danger)),
              ),
            ],
          ),
        ) ??
        false;
    if (!yes) return;

    try {
      await ref.read(flowerRepositoryProvider).deleteMessage(message.id);
      // The pager drops the page on its own — myDayPhotosProvider is derived
      // from the thread. A viewer opened on its own has nothing left to show.
      if (mounted && !widget.embedded) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't delete that. Try again?")),
        );
      }
    }
  }

  /// Both replies go into the thread as ordinary messages.
  ///
  /// That is the point rather than a shortcut: a reply is a message, so the
  /// thread, the unread badge, the notification and the realtime stream all
  /// carry it with no second code path. `replyTo` is the only part that
  /// could not be inferred — without it a 🌷 arriving three hours later is
  /// just a flower.
  Future<void> _send(
      Future<void> Function(String pairId, String me) send) async {
    if (_sending) return;
    final me = ref.read(currentUserIdProvider);
    final pair = ref.read(currentPairProvider).valueOrNull;
    if (me == null || pair == null || !pair.isLinked) return;

    setState(() => _sending = true);
    try {
      await send(pair.id, me);
      if (!mounted) return;
      _reply.clear();
      _focus.unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sent 💛')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("That didn't send. Try again?")),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendText() {
    final text = _reply.text.trim();
    // The DB's content check rejects an empty message anyway; catching it
    // here means the button simply does nothing rather than surfacing a
    // constraint violation as "that didn't send".
    if (text.isEmpty) return Future.value();
    return _send((pairId, me) => ref.read(flowerRepositoryProvider).sendText(
          pairId: pairId,
          senderId: me,
          text: text,
          replyTo: widget.message.id,
        ));
  }

  /// A reaction is a **reply to this photo**, sent as text.
  ///
  /// ⚠️ It used to send a real `classic_tulip` flower. A flower is a
  /// deliberate act in this app — one you pick out of a catalog and mean —
  /// and spending one on a tap that means "nice" made the two gestures the
  /// same thing. The emoji goes into the thread quoting the photo, which is
  /// what a story reaction is everywhere else.
  Future<void> _sendReaction(DayReaction reaction) =>
      _send((pairId, me) => ref.read(flowerRepositoryProvider).sendText(
            pairId: pairId,
            senderId: me,
            text: reaction.emoji,
            replyTo: widget.message.id,
          ));
}

/// A row of reactions over a field and a send arrow.
///
/// Shaped after the story reply bar everyone already knows. The reactions
/// sit **above** the field rather than beside it: five of them do not fit
/// next to a text field at a size anybody can hit, and putting them on
/// their own line is what the app this is modelled on does.
///
/// The flower is one of the five rather than the only one. This app's
/// vocabulary is flowers, but a tulip is a poor way to say "that's sad",
/// and a reaction nobody can find the right one in is not used at all.
class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.controller,
    required this.focus,
    required this.busy,
    required this.onSend,
    required this.onReact,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool busy;
  final Future<void> Function() onSend;
  final Future<void> Function(DayReaction) onReact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.sm, AppSpace.xs, AppSpace.sm, AppSpace.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final reaction in DayReaction.values)
                _BarButton(
                  busy: busy,
                  onTap: () => onReact(reaction),
                  child: Semantics(
                    label: reaction.label,
                    child: Text(reaction.emoji,
                        style: const TextStyle(fontSize: 26)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .55)),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focus,
                    style: AppText.body(Colors.white),
                    cursorColor: AppColors.brandLight,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      isDense: true,
                      // ⚠️ `filled: false` and every border spelled out. The
                      // app's InputDecorationTheme fills fields with the light
                      // surface colour and draws its own outline — correct on
                      // every other form, and over a photo it painted a solid
                      // white block inside this pill.
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      hintText: 'Send message',
                      hintStyle:
                          AppText.body(Colors.white.withValues(alpha: .7)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              _BarButton(
                busy: busy,
                onTap: onSend,
                child: const AppIcon(CupertinoIcons.paperplane,
                    color: Colors.white, size: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.child,
    required this.busy,
    required this.onTap,
  });

  final Widget child;
  final bool busy;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? null : () => onTap(),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : child,
          ),
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
      padding:
          const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.xs),
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
                    ? '$name started a ${strip.style.name}. Shoot your half'
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

/// Flips a JPEG horizontally and re-encodes it.
///
/// Top level and free of any state so it can run in an isolate via
/// `compute` — the booth compositor does the same for the same reason.
///
/// Returns the input untouched if it cannot be decoded. A photo that is the
/// wrong way round is a far smaller problem than one that vanishes because
/// a decode failed, so this never throws.
Uint8List unmirrorJpeg(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    return Uint8List.fromList(
      img.encodeJpg(img.flipHorizontal(decoded), quality: 90),
    );
  } catch (_) {
    return bytes;
  }
}
