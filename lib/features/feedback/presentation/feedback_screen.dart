import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app_router.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/feature_screen_header.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/ios_back_button.dart';
import '../../updates/data/update_repository.dart';
import '../data/feedback_repository.dart';

/// Picks one picture for a report. A seam, so tests can attach without a
/// gallery; null when nothing was picked.
typedef FeedbackImagePicker = Future<FeedbackImage?> Function();

final feedbackImagePickerProvider = Provider<FeedbackImagePicker>(
  (ref) => () async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // A screenshot is tall and its words are small: kept big enough to
      // read, and still a fraction of a full-resolution original.
      maxWidth: 1440,
      maxHeight: 3200,
      imageQuality: 85,
    );
    if (file == null) return null;
    final ext = file.path.split('.').last.toLowerCase() == 'png' ? 'png' : 'jpg';
    return (bytes: await file.readAsBytes(), extension: ext);
  },
);

/// Settings → Bugs and suggestions: a few words, and screenshots if they
/// help, sent to the people who make Dayflower.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _message = TextEditingController();
  var _kind = FeedbackKind.bug;
  final _images = <FeedbackImage>[];
  bool _picking = false;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  bool get _canSend => _message.text.trim().isNotEmpty && !_sending;

  Future<void> _addImage() async {
    if (_picking || _images.length >= FeedbackRepository.maxImages) return;
    setState(() => _picking = true);
    try {
      final picked = await ref.read(feedbackImagePickerProvider)();
      if (picked != null && mounted) setState(() => _images.add(picked));
    } catch (_) {
      if (mounted) _say("Couldn't open your photos. Try again?");
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _send() async {
    final userId = ref.read(currentUserIdProvider);
    if (!_canSend || userId == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Which build it came from, if it can be read quickly. A report is
      // worth more than the version number on it.
      String? version;
      try {
        version = await ref
            .read(installedVersionProvider.future)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      await ref.read(feedbackRepositoryProvider).send(
            userId: userId,
            kind: _kind,
            message: _message.text,
            images: List.of(_images),
            appVersion: version,
          );
      if (!mounted) return;
      context.canPop() ? context.pop() : context.go(Routes.settings);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(_kind == FeedbackKind.bug
                ? 'Sent. Thank you for telling us.'
                : 'Sent. Thank you for the idea.')));
    } catch (_) {
      // Everything stays as it was typed, so trying again is one tap.
      if (mounted) {
        setState(() => _sending = false);
        _say("Couldn't send that. Check your connection and try again.");
      }
    }
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.sm, AppSpace.sm, AppSpace.sm, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IosBackButton(
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go(Routes.settings)),
                  const SizedBox(width: AppSpace.xs),
                  const Expanded(
                    child: FeatureScreenHeader(
                      title: 'Bugs and suggestions',
                      subtitle: 'Straight to the people who make Dayflower',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(AppSpace.screenInset,
                    AppSpace.sm, AppSpace.screenInset, AppSpace.lg),
                children: [
                  Text('WHAT IS IT?', style: AppText.label()),
                  const SizedBox(height: AppSpace.xs),
                  Row(
                    children: [
                      for (final kind in FeedbackKind.values) ...[
                        if (kind.index > 0) const SizedBox(width: AppSpace.xs),
                        _KindChip(
                          kind: kind,
                          selected: kind == _kind,
                          onTap: _sending
                              ? null
                              : () => setState(() => _kind = kind),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  TextField(
                    controller: _message,
                    enabled: !_sending,
                    minLines: 6,
                    maxLines: 12,
                    maxLength: FeedbackRepository.maxLength,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    style: AppText.body(AppColors.ink),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: _kind.prompt,
                      hintMaxLines: 3,
                      hintStyle: AppText.body(AppColors.muted),
                      // The limit is a guard, not a target: no counter
                      // ticking down under every word.
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.all(AppSpace.sm),
                      border: _border(AppColors.border),
                      enabledBorder: _border(AppColors.border),
                      disabledBorder: _border(AppColors.border),
                      focusedBorder: _border(AppColors.secondary),
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'SCREENSHOTS · UP TO ${FeedbackRepository.maxImages}',
                    style: AppText.label(),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Wrap(
                    spacing: AppSpace.xs,
                    runSpacing: AppSpace.xs,
                    children: [
                      for (final (i, image) in _images.indexed)
                        _Attached(
                          image: image,
                          index: i,
                          onRemove: _sending
                              ? null
                              : () => setState(() => _images.removeAt(i)),
                        ),
                      if (_images.length < FeedbackRepository.maxImages)
                        _AddImage(
                          busy: _picking,
                          onTap: _sending ? null : _addImage,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  GradientButton(
                    label: 'Send',
                    loading: _sending,
                    onPressed: _canSend ? _send : null,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    'Your app version and phone system are sent with it, so '
                    'a bug can be found without asking you again.',
                    textAlign: TextAlign.center,
                    style: AppText.caption(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: color),
      );
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final FeedbackKind kind;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      side: BorderSide(
          color: selected ? AppColors.brand : AppColors.border,
          width: selected ? 1.5 : 1),
    );
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.blush : AppColors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  kind == FeedbackKind.bug
                      ? CupertinoIcons.ant
                      : CupertinoIcons.lightbulb,
                  size: 16,
                  color: selected ? AppColors.brand : AppColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  kind.label,
                  style: AppText.caption(
                          selected ? AppColors.brand : AppColors.ink)
                      .copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A picked screenshot, with a way to take it off again.
class _Attached extends StatelessWidget {
  const _Attached({
    required this.image,
    required this.index,
    required this.onRemove,
  });

  static const size = 88.0;

  final FeedbackImage image;
  final int index;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            // A tile before it decodes, so the remove button never floats
            // over nothing.
            child: Image.memory(
              frameBuilder: (_, child, frame, sync) => ColoredBox(
                color: AppColors.surfaceSubtle,
                child: frame == null && !sync ? const SizedBox.expand() : child,
              ),
              image.bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              semanticLabel: 'Screenshot ${index + 1}',
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surfaceSubtle,
                alignment: Alignment.center,
                child: AppIcon(CupertinoIcons.photo,
                    size: 20, color: AppColors.muted),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Semantics(
              button: true,
              label: 'Remove screenshot ${index + 1}',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: AppIcon(CupertinoIcons.xmark,
                      size: 11, color: AppColors.surface),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddImage extends StatelessWidget {
  const _AddImage({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      side: BorderSide(color: AppColors.border),
    );
    return Semantics(
      button: true,
      label: 'Add a screenshot',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onTap,
          customBorder: shape,
          child: SizedBox(
            width: _Attached.size,
            height: _Attached.size,
            child: busy
                ? const Center(child: CupertinoActivityIndicator())
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppIcon(CupertinoIcons.photo_on_rectangle,
                          size: 22, color: AppColors.secondary),
                      const SizedBox(height: 4),
                      Text('Add', style: AppText.caption(AppColors.ink)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
