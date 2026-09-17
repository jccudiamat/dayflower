import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../../tulip/data/flower_repository.dart';
import '../../../tulip/presentation/widgets/media_viewer.dart';
import '../../data/booth_camera.dart';
import '../../data/strip_repository.dart';
import '../../domain/booth_design.dart';
import '../../domain/booth_renderer.dart';
import '../../domain/strip_compositor.dart';
import '../../domain/strip_templates.dart';
import '../widgets/booth_visuals.dart';
import '../../data/booth_photo_picker.dart';

final boothRenderProvider =
    Provider<Future<Uint8List> Function(BoothDesign, List<Uint8List>)>(
        (ref) => BoothRenderer.render);

enum _Step { mode, room, frame, camera, review, printing, finished, waiting }

class BoothStudioScreen extends ConsumerStatefulWidget {
  const BoothStudioScreen({super.key, this.joining});
  final PhotoStrip? joining;
  @override
  ConsumerState<BoothStudioScreen> createState() => _BoothStudioScreenState();
}

class _BoothStudioScreenState extends ConsumerState<BoothStudioScreen>
    with WidgetsBindingObserver {
  late final BoothCamera _camera;
  _Step _step = _Step.mode;
  BoothDesign _design = const BoothDesign();
  bool _couple = false, _remote = false, _busy = false, _shooting = false;
  bool _saved = false, _kept = false, _flash = false;
  int _run = 0;
  int? _countdown;
  String? _error;
  final List<Uint8List> _shots = [];
  Uint8List? _print;
  PhotoStrip? _pendingInvite;
  String get _partner =>
      ref.read(partnerProfileProvider).valueOrNull?.petName ??
      ref.read(partnerProfileProvider).valueOrNull?.displayName ??
      'your partner';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _camera = ref.read(boothCameraProvider)()..addListener(_changed);
    final invite = widget.joining;
    if (invite != null) {
      _design = BoothDesign.parse(invite.template)!;
      _couple = _remote = true;
      _step = _Step.camera;
      _camera.open();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _run++;
    WidgetsBinding.instance.removeObserver(this);
    _camera.removeListener(_changed);
    _camera.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _cancelShoot();
      _camera.close();
    } else if (state == AppLifecycleState.resumed && _step == _Step.camera) {
      _camera.open();
    }
  }

  void _cancelShoot() {
    _run++;
    if (mounted) {
      setState(() {
        _shooting = false;
        _countdown = null;
        _flash = false;
      });
    }
  }

  void _go(_Step step) {
    _cancelShoot();
    setState(() {
      _step = step;
      _error = null;
    });
    if (step == _Step.camera) {
      _camera.open();
    } else {
      _camera.close();
    }
  }

  Future<void> _back() async {
    if (_busy) return;
    _cancelShoot();
    if (_step == _Step.mode ||
        _step == _Step.finished ||
        _step == _Step.waiting) {
      Navigator.of(context).pop();
    } else if (_step == _Step.room) {
      _go(_Step.mode);
    } else if (_step == _Step.frame) {
      _go(_Step.room);
    } else {
      final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Leave this photo session?'),
                content: const Text('Photos you have not saved will be lost.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep taking photos')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Leave session'))
                ],
              ));
      if (mounted && leave == true) Navigator.of(context).pop();
    }
  }

  Future<void> _shoot() async {
    if (_shooting || _busy || !_camera.ready) return;
    final run = ++_run;
    setState(() {
      _shooting = true;
      _error = null;
    });
    try {
      while (_shots.length < _design.layout.shots) {
        for (var n = 3; n > 0; n--) {
          if (!mounted || run != _run) return;
          setState(() => _countdown = n);
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        if (!mounted || run != _run) return;
        setState(() {
          _countdown = null;
          _flash = !MediaQuery.disableAnimationsOf(context);
        });
        final bytes = await _camera.capture();
        if (!mounted || run != _run) return;
        setState(() {
          _shots.add(bytes);
          _flash = false;
        });
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (mounted && run == _run) await _review();
    } catch (_) {
      if (mounted && run == _run) {
        setState(() => _error =
            'That shot did not finish. Your earlier photos are kept. Try again.');
      }
    } finally {
      if (mounted && run == _run) {
        setState(() {
          _shooting = false;
          _countdown = null;
          _flash = false;
        });
      }
    }
  }

  Future<void> _upload() async {
    if (_busy || _shooting) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final photo =
          await ref.read(boothPhotoPickerProvider)(ImageSource.gallery);
      if (!mounted || photo == null) return;
      setState(() => _shots.add(photo));
      if (_shots.length == _design.layout.shots) await _review();
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not read that photo. Please choose another.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review() async {
    await _camera.close();
    setState(() {
      _busy = true;
      _shooting = false;
      _countdown = null;
    });
    try {
      final output = await ref.read(boothRenderProvider)(_design, _shots);
      if (mounted) {
        setState(() {
          _print = output;
          _step = _Step.review;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not prepare the strip. Your photos are still here. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printPhotos() async {
    if (_busy || _print == null) return;
    if (!_remote) {
      _go(_Step.printing);
      return;
    }
    final pair = ref.read(currentPairProvider).valueOrNull;
    final user = ref.read(currentUserIdProvider);
    final open = ref.read(openStripsProvider);
    if (pair?.isLinked != true || user == null) {
      setState(() =>
          _error = 'Connect with your partner before sharing a couple strip.');
      return;
    }
    if (!open.hasValue || open.hasError) {
      setState(() => _error =
          'Waiting strips could not be loaded. Reopen the booth before sending.');
      return;
    }
    final invite = widget.joining;
    if (invite == null && open.requireValue.any((s) => s.aUser == user)) {
      setState(() => _error =
          'You already have a waiting strip. Finish or cancel it in Saved & waiting strips.');
      return;
    }
    if (invite != null &&
        !open.requireValue.any((s) => s.id == invite.id && s.bPath == null)) {
      setState(() => _error =
          'This invitation has changed. Check Saved & waiting strips. Your photos are still here.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await BoothRenderer.pack(_shots);
      final repository = ref.read(stripRepositoryProvider);
      if (invite == null) {
        final pending = await repository.startDuo(
            pairId: pair!.id,
            senderId: user,
            template: StripTemplate.byId(_design.id),
            bytes: bytes);
        if (mounted) {
          setState(() {
            _pendingInvite = pending;
            _step = _Step.waiting;
          });
        }
      } else {
        final first = await ref
            .read(flowerRepositoryProvider)
            .downloadPhoto(invite.aPath);
        final output = await StripCompositor.render(
            template: invite.style, first: first, second: bytes);
        await repository.joinDuo(strip: invite, senderId: user, bytes: bytes);
        if (mounted) {
          setState(() {
            _print = output;
            _kept = true;
            _step = _Step.printing;
          });
        }
      }
      ref.invalidate(openStripsProvider);
      ref.invalidate(flowerMessagesProvider);
    } catch (_) {
      ref.invalidate(openStripsProvider);
      if (mounted) {
        setState(() => _error =
            'Sharing did not finish. Your photos are still here. Check Saved & waiting strips before retrying.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _print == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await MediaSaver.save(_print!,
        'dayflower-booth-${DateTime.now().millisecondsSinceEpoch}.jpg');
    if (mounted) {
      setState(() {
        _busy = false;
        _saved = ok;
        if (!ok) {
          _error =
              'Could not save to Photos. You can try Share to save a copy.';
        }
      });
    }
  }

  Future<void> _share() async {
    if (_busy || _print == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(_print!, mimeType: 'image/jpeg')],
        fileNameOverrides: ['dayflower-booth.jpg'],
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not open sharing. Your strip is still here.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _keep() async {
    if (_busy || _kept || _print == null) return;
    final pair = ref.read(currentPairProvider).valueOrNull;
    final user = ref.read(currentUserIdProvider);
    if (pair?.isLinked != true || user == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(flowerRepositoryProvider).sendDayPhoto(
          pairId: pair!.id,
          senderId: user,
          bytes: _print!,
          fileExtension: 'jpg',
          note: _design.title,
          toWidget: false);
      if (mounted) setState(() => _kept = true);
      ref.invalidate(flowerMessagesProvider);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Could not share to Memories. Your strip is still here.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pair = ref.watch(currentPairProvider).valueOrNull;
    ref.watch(partnerProfileProvider);
    ref.watch(openStripsProvider);
    final title = switch (_step) {
      _Step.mode => 'Who is stepping in?',
      _Step.room => 'Pick your booth',
      _Step.frame => 'Find your frame',
      _Step.camera => 'Make a little memory',
      _Step.review => 'A keeper?',
      _Step.printing => 'Printing your moments',
      _Step.finished => 'Fresh from the booth',
      _Step.waiting => 'Your half is ready',
    };
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  children: [
                Row(children: [
                  IconButton(
                      tooltip: 'Back',
                      onPressed: _busy ? null : _back,
                      icon: const Icon(Icons.arrow_back)),
                  Expanded(
                      child: Text('DAYFLOWER PHOTO BOOTH',
                          style: AppText.label(), textAlign: TextAlign.center)),
                  const SizedBox(width: 40)
                ]),
                const SizedBox(height: 20),
                Text(title, style: AppText.hero(), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                if (_step == _Step.mode) ...[
                  Text('A moment for you. Or the two of you.',
                      style: AppText.body(), textAlign: TextAlign.center),
                  const SizedBox(height: 30),
                  _choice(
                      'Solo', 'Just you, all the frames.', Icons.person_outline,
                      () {
                    _couple = _remote = false;
                    _go(_Step.room);
                  }),
                  const SizedBox(height: 16),
                  _choice(
                      'Couple',
                      'Make something together.',
                      Icons.favorite_border,
                      () => setState(() => _couple = true)),
                  if (_couple) ...[
                    const SizedBox(height: 24),
                    _choice(
                        'Together on one phone',
                        'Step into the frame side by side.',
                        Icons.people_outline, () {
                      _remote = false;
                      _go(_Step.room);
                    }),
                    const SizedBox(height: 12),
                    _choice(
                        'From separate phones',
                        pair?.isLinked == true
                            ? 'Take turns. Your partner adds their photos to the same strip.'
                            : 'Connect with your partner in Us first.',
                        Icons.phonelink,
                        pair?.isLinked != true
                            ? null
                            : () {
                                _remote = true;
                                _go(_Step.room);
                              }),
                  ],
                ],
                if (_step == _Step.room) ...[
                  Text('Choose the room and paper you love.',
                      style: AppText.body(), textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  LayoutBuilder(
                      builder: (context, box) =>
                          Wrap(spacing: 16, runSpacing: 22, children: [
                            for (final look in BoothLook.values)
                              SizedBox(
                                width:
                                    MediaQuery.textScalerOf(context).scale(14) >
                                            22
                                        ? box.maxWidth
                                        : (box.maxWidth - 16) / 2,
                                child: Semantics(
                                    button: true,
                                    label: look.title,
                                    child: InkWell(
                                        onTap: () {
                                          _design = BoothDesign(
                                              look: look,
                                              layout: _design.layout);
                                          _go(_Step.frame);
                                        },
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              BoothRoomPreview(look: look),
                                              const SizedBox(height: 10),
                                              Text(look.title,
                                                  style: AppText.subtitle()),
                                              Text(look.subtitle,
                                                  style: AppText.caption()),
                                            ]))),
                              ),
                          ])),
                ],
                if (_step == _Step.frame) ...[
                  Text(
                      '${_design.look.title} · Pick the shape of your keepsake.',
                      style: AppText.body(),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                      builder: (context, box) =>
                          Wrap(spacing: 16, runSpacing: 16, children: [
                            for (final layout in BoothLayout.values)
                              SizedBox(
                                width:
                                    MediaQuery.textScalerOf(context).scale(14) >
                                            22
                                        ? box.maxWidth
                                        : (box.maxWidth - 16) / 2,
                                child: InkWell(
                                    onTap: () => setState(() => _design =
                                        BoothDesign(
                                            look: _design.look,
                                            layout: layout)),
                                    child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: _design.layout == layout
                                                    ? AppColors.brand
                                                    : AppColors.border,
                                                width: _design.layout == layout
                                                    ? 2
                                                    : 1)),
                                        child: Column(children: [
                                          SizedBox(
                                              height: 155,
                                              child: Center(
                                                  child: BoothPaper(
                                                      design: BoothDesign(
                                                          look: _design.look,
                                                          layout: layout)))),
                                          const SizedBox(height: 16),
                                          Text(layout.title,
                                              style: AppText.subtitle()),
                                          Text(layout.subtitle,
                                              style: AppText.caption(),
                                              textAlign: TextAlign.center),
                                        ]))),
                              ),
                          ])),
                  const SizedBox(height: 24),
                  FilledButton(
                      onPressed: () => _go(_Step.camera),
                      child: const Text('Step inside')),
                ],
                if (_step == _Step.camera) ...[
                  Text(
                      _remote
                          ? 'Your photos first. Each countdown takes one shot.'
                          : _couple
                              ? 'Both of you in frame. A new pose every countdown.'
                              : 'Get comfy. A new pose every countdown.',
                      style: AppText.body(),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            _design.look.curtain,
                            Color.lerp(_design.look.curtain, Colors.black, .35)!
                          ]),
                          borderRadius: BorderRadius.circular(24)),
                      child: Column(children: [
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(_design.look.title.toUpperCase(),
                                style: AppText.label(Colors.white))),
                        ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AspectRatio(
                                aspectRatio: 4 / 3,
                                child: Stack(fit: StackFit.expand, children: [
                                  ColoredBox(
                                      color: const Color(0xFF251E29),
                                      child: _camera.ready
                                          ? (_remote
                                              ? Row(
                                                  textDirection:
                                                      widget.joining == null
                                                          ? TextDirection.ltr
                                                          : TextDirection.rtl,
                                                  children: [
                                                      Expanded(
                                                          child: _camera
                                                              .preview()),
                                                      Expanded(
                                                          child: Container(
                                                              color: _design
                                                                  .look.paper,
                                                              child: Center(
                                                                  child: Padding(
                                                                      padding: const EdgeInsets.all(16),
                                                                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                                                                        Icon(
                                                                            Icons
                                                                                .favorite_border,
                                                                            color:
                                                                                _design.look.curtain),
                                                                        const SizedBox(
                                                                            height:
                                                                                12),
                                                                        Text(
                                                                            'Your partner adds their photos',
                                                                            textAlign:
                                                                                TextAlign.center,
                                                                            style: AppText.caption(_design.look.ink)),
                                                                      ]))))),
                                                    ])
                                              : _camera.preview())
                                          : Center(
                                              child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(20),
                                                  child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                            Icons
                                                                .camera_alt_outlined,
                                                            color: Colors.white,
                                                            size: 34),
                                                        const SizedBox(
                                                            height: 12),
                                                        Text(
                                                            _camera.error ??
                                                                'Opening the camera…',
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: AppText.body(
                                                                Colors.white)),
                                                        if (_camera.error !=
                                                            null)
                                                          TextButton(
                                                              onPressed:
                                                                  _camera.open,
                                                              child: const Text(
                                                                  'Try camera again',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white))),
                                                      ])))),
                                  if (_countdown != null)
                                    Center(
                                        child: Semantics(
                                            liveRegion: true,
                                            child: Text('$_countdown',
                                                style:
                                                    AppText.stat(Colors.white)
                                                        .copyWith(
                                                            fontSize: 80,
                                                            shadows: const [
                                                      Shadow(
                                                          blurRadius: 20,
                                                          color: Colors.black)
                                                    ])))),
                                  if (_flash)
                                    const ColoredBox(color: Colors.white),
                                ]))),
                        const SizedBox(height: 12),
                        Text(
                            '${_shots.length} of ${_design.layout.shots} photos',
                            style: AppText.caption(Colors.white)),
                      ])),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (_camera.canFlip)
                      IconButton(
                          tooltip: 'Switch camera',
                          onPressed: _shooting || _busy ? null : _camera.flip,
                          icon: const Icon(Icons.cameraswitch_outlined)),
                    TextButton.icon(
                        onPressed: _shooting ||
                                _busy ||
                                _shots.length == _design.layout.shots
                            ? null
                            : _upload,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Upload a photo')),
                  ]),
                  if (_shooting)
                    OutlinedButton(
                        onPressed: _cancelShoot,
                        child: const Text('Pause the shoot'))
                  else
                    FilledButton(
                        onPressed: _busy
                            ? null
                            : _shots.length == _design.layout.shots
                                ? _review
                                : _camera.ready
                                    ? _shoot
                                    : null,
                        child: Text(_shots.length == _design.layout.shots
                            ? 'Review photos'
                            : _shots.isEmpty
                                ? 'Start countdown'
                                : 'Continue shooting')),
                  const SizedBox(height: 24),
                  SizedBox(
                      height: 170,
                      child: Center(
                          child: BoothPaper(
                              design: _design,
                              photos: _shots,
                              active: _shots.length))),
                  const SizedBox(height: 12),
                  Text('Nothing is shared until you choose to share it.',
                      textAlign: TextAlign.center, style: AppText.caption()),
                ],
                if (_step == _Step.review) ...[
                  Text(
                      _remote
                          ? 'These are your photos. Your partner has their own set.'
                          : 'Your photos, ready for the printer.',
                      style: AppText.body(),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  SizedBox(
                      height: 370,
                      child: Image.memory(_print!, fit: BoxFit.contain)),
                  const SizedBox(height: 24),
                  FilledButton(
                      onPressed: _busy ? null : _printPhotos,
                      child: Text(!_remote
                          ? 'Print my strip'
                          : widget.joining == null
                              ? 'Send my photos to $_partner'
                              : 'Finish our strip')),
                  TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              _shots.clear();
                              _print = null;
                              _go(_Step.camera);
                            },
                      child: const Text('Retake photos')),
                ],
                if (_step == _Step.printing) ...[
                  const SizedBox(height: 24),
                  Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 250),
                          child: PrintingPhoto(
                              bytes: _print!,
                              onDone: () {
                                if (mounted) {
                                  setState(() => _step = _Step.finished);
                                }
                              }))),
                ],
                if (_step == _Step.finished) ...[
                  Text('A little moment, made to keep.',
                      style: AppText.body(), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  SizedBox(
                      height: 340,
                      child: Image.memory(_print!, fit: BoxFit.contain)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                      onPressed: _busy || _saved ? null : _save,
                      icon:
                          Icon(_saved ? Icons.check : Icons.download_outlined),
                      label:
                          Text(_saved ? 'Saved to Photos' : 'Save to Photos')),
                  OutlinedButton.icon(
                      onPressed: _busy ? null : _share,
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Share strip')),
                  if (pair?.isLinked == true)
                    TextButton(
                        onPressed: _busy || _kept ? null : _keep,
                        child: Text(_kept
                            ? 'Shared in Memories & Chat'
                            : 'Keep in Memories & share in Chat')),
                  TextButton(
                      onPressed: _busy ? null : _back,
                      child: const Text('Back to the booth')),
                ],
                if (_step == _Step.waiting) ...[
                  const SizedBox(height: 30),
                  const Icon(Icons.mark_email_read_outlined,
                      size: 60, color: AppColors.brand),
                  const SizedBox(height: 20),
                  Text('Waiting for $_partner',
                      style: AppText.title(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(
                      'Your photos are saved privately. Your partner can open the booth on their phone to finish the strip.',
                      style: AppText.body(),
                      textAlign: TextAlign.center),
                  if (_pendingInvite != null) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                        height: 220,
                        child: Center(
                            child:
                                BoothPaper(design: _design, photos: _shots))),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                      onPressed: _back, child: const Text('Back to the booth')),
                ],
                if (_busy)
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: LinearProgressIndicator()),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_error!,
                          style: AppText.body(AppColors.danger),
                          textAlign: TextAlign.center)),
              ])),
        ));
  }

  Widget _choice(
          String title, String body, IconData icon, VoidCallback? onTap) =>
      OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(22),
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22))),
          child: Row(children: [
            Icon(icon, size: 30),
            const SizedBox(width: 18),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: AppText.title()),
                  const SizedBox(height: 6),
                  Text(body, style: AppText.body()),
                ])),
          ]));
}
