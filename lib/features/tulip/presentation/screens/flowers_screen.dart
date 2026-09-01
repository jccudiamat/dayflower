import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/flower_avatar.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../data/flower_repository.dart';
import '../../domain/flower_catalog.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/flower_catalog_panel.dart';

/// The Flowers tab — the couple's conversation.
///
/// It reads as a messaging thread because that is what it now is: flowers
/// and text share one table and one timeline. The flower button left of the
/// field opens the catalog in place of the keyboard, the way a GIF drawer
/// does, so picking one never leaves the conversation.
///
/// The daily flower ritual used to live here as a full-screen picker gated
/// by a one-per-day DB index. Migration 0009 removed the index; what made
/// a flower special was never the scarcity, it was the artwork and the note.
class FlowersScreen extends ConsumerStatefulWidget {
  const FlowersScreen({super.key});

  @override
  ConsumerState<FlowersScreen> createState() => _FlowersScreenState();
}

class _FlowersScreenState extends ConsumerState<FlowersScreen> {
  final _composer = TextEditingController();
  final _focus = FocusNode();

  bool _panelOpen = false;
  bool _sending = false;
  bool _marking = false;

  /// Messages this session has successfully written to the database but that
  /// the live stream has not echoed back yet.
  ///
  /// The thread used to render *only* what the realtime stream delivered, so
  /// a send that inserted perfectly well still left the screen unchanged if
  /// the echo never arrived — the message existed in Postgres and nowhere the
  /// sender could see it. These are merged into the thread by id and drop out
  /// again the moment the stream catches up, so a healthy realtime connection
  /// behaves exactly as before.
  final List<FlowerMessage> _pending = [];

  /// Remembered so the catalog drawer opens at exactly the height the
  /// keyboard just vacated — otherwise swapping between the two makes the
  /// whole conversation jump. Seeded with a sane guess for the first open
  /// (and for web, where there are no view insets at all).
  double _keyboardHeight = 300;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      // Tapping the field means "I want the keyboard", so the drawer yields.
      if (_focus.hasFocus && _panelOpen) setState(() => _panelOpen = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery is inherited, so this fires every time the keyboard moves.
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset > 120) _keyboardHeight = inset;
  }

  @override
  void dispose() {
    _composer.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────

  void _togglePanel() {
    if (_panelOpen) {
      setState(() => _panelOpen = false);
      _focus.requestFocus();
    } else {
      _focus.unfocus();
      setState(() => _panelOpen = true);
    }
  }

  /// Opening the thread is what "read" means, so the receipts fire here for
  /// everything unseen, not just the newest message.
  Future<void> _markThreadSeen() async {
    if (_marking) return;
    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    if (pair == null || userId == null) return;

    _marking = true;
    try {
      await ref
          .read(flowerRepositoryProvider)
          .markThreadSeen(pairId: pair.id, userId: userId);
    } catch (_) {
      // A failed receipt is not worth interrupting anyone over; the next
      // stream tick will try again.
    } finally {
      _marking = false;
    }
  }

  Future<void> _sendText() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;

    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    if (pair == null || userId == null) return;

    // Cleared up front so the field empties on tap like every other chat;
    // restored below if the send actually fails.
    _composer.clear();
    setState(() => _sending = true);
    try {
      final sent = await ref.read(flowerRepositoryProvider).sendText(
            pairId: pair.id,
            senderId: userId,
            text: text,
          );
      if (mounted) setState(() => _pending.add(sent));
    } catch (_) {
      if (mounted) {
        _composer.text = text;
        _showError("Couldn't send that. Try again?");
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickFlower(Flower flower) async {
    final partner = ref.read(partnerProfileProvider).valueOrNull;
    final result = await showFlowerSendSheet(
      context,
      flower: flower,
      // Whatever's already typed becomes the caption — the same thing
      // WhatsApp does when you attach a photo mid-sentence.
      initialNote: _composer.text.trim(),
      partnerName: partner?.petName ?? partner?.displayName ?? 'their',
    );
    if (result == null || !mounted) return;

    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    if (pair == null || userId == null) return;

    // Restore what they typed *in the sheet*, not what was in the composer
    // before it opened — the sheet is where the caption was actually written.
    final note = result.note;
    _composer.clear();
    setState(() {
      _panelOpen = false;
      _sending = true;
    });
    try {
      final sent = await ref.read(flowerRepositoryProvider).sendFlower(
            pairId: pair.id,
            senderId: userId,
            flowerType: flower.id,
            note: result.note,
            toWidget: result.toWidget,
          );
      if (mounted) setState(() => _pending.add(sent));
    } catch (_) {
      if (mounted) {
        _composer.text = note;
        _showError("Couldn't send ${flower.name}. Try again?");
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;

    if (ref.watch(unreadMessageCountProvider) > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markThreadSeen());
    }

    // Once the stream carries a message itself, the local copy is redundant —
    // dropping it here keeps the merge in _withPending cheap and makes the
    // stream the single source of truth again.
    ref.listen(flowerMessagesProvider, (_, next) {
      final known = (next.valueOrNull ?? const <FlowerMessage>[])
          .map((m) => m.id)
          .toSet();
      if (_pending.any((m) => known.contains(m.id))) {
        setState(() => _pending.removeWhere((m) => known.contains(m.id)));
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      // No tab bar in the thread at all. The chat is a sub-route of the
      // Messages inbox now, so the nav belongs to the list you came from —
      // keeping it here would sit it between the composer and the keyboard
      // and make the conversation read as a form pinned inside a tab. The
      // header's back chevron is the way out.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ChatHeader(
              onVoiceCall: () => _comingSoon('Voice calls'),
              onVideoCall: () => _comingSoon('Video calls'),
            ),
            Expanded(child: _buildThread()),
            _buildComposer(),
            if (_panelOpen)
              FlowerCatalogPanel(
                height: _keyboardHeight,
                onPick: _pickFlower,
              ),
            // Nothing sits below the composer/drawer any more, so whichever
            // is bottom-most has to clear the gesture bar itself. With the
            // keyboard up the keyboard already covers it.
            if (!keyboardUp)
              SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildThread() {
    // chatMessagesProvider, not the raw stream: a photo sent only to the
    // home screen is deliberately absent from the conversation.
    final messages = ref.watch(chatMessagesProvider);
    final userId = ref.watch(currentUserIdProvider);

    return messages.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text("Couldn't load your conversation.", style: AppText.body()),
      ),
      data: (streamed) {
        final list = _withPending(streamed);
        if (list.isEmpty) return const _EmptyThread();

        return ListView.builder(
          // Newest at index 0, pinned to the bottom: a new message slides in
          // without shifting anything above it.
          reverse: true,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final message = list[i];
            // list[i + 1] is the *older* neighbour, so a mismatch here means
            // this message opens a new day.
            final older = i + 1 < list.length ? list[i + 1] : null;
            final startsDay = older == null || !_sameDay(older.sentAt, message.sentAt);

            return Column(
              children: [
                if (startsDay) ChatDateDivider(date: message.sentAt),
                ChatBubble(
                  message: message,
                  isMine: message.senderId == userId,
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// The streamed thread plus anything sent this session that hasn't come
  /// back down the stream yet. Both are newest-first, and a pending message
  /// is always newer than everything streamed, so they simply go in front.
  List<FlowerMessage> _withPending(List<FlowerMessage> streamed) {
    if (_pending.isEmpty) return streamed;
    final known = streamed.map((m) => m.id).toSet();
    final extra = _pending.where((m) => !known.contains(m.id)).toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    if (extra.isEmpty) return streamed;
    return [...extra, ...streamed];
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildComposer() {
    final canSend = !_sending;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            // A Material rather than a decorated Container so the icons
            // sitting inside it splash onto the pill itself — ink looks for
            // the nearest Material, and on a plain Container that's the
            // Scaffold underneath, where the ripple is hidden.
            child: Material(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  // Icons hold the bottom line as the field grows to five
                  // lines, instead of drifting to the vertical middle.
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Mirrors the trailing gap below — without it the leading
                    // icon hugs the pill's left curve while the camera icon
                    // has 4px of air on the right.
                    const SizedBox(width: 4),
                    // The catalog opener. Becomes a keyboard glyph while the
                    // drawer is up, so one button always toggles back to the
                    // other input.
                    _ComposerIcon(
                      icon: _panelOpen
                          ? CupertinoIcons.keyboard
                          : Icons.local_florist_rounded,
                      color: _panelOpen ? AppColors.muted : AppColors.brand,
                      tooltip: _panelOpen ? 'Keyboard' : 'Send a flower',
                      onTap: _togglePanel,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _composer,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                        style: AppText.body(AppColors.ink),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 4),
                          hintText: 'Message',
                          hintStyle: AppText.body(AppColors.muted),
                        ),
                        // Rebuilds the send button as the field fills.
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    _ComposerIcon(
                      icon: CupertinoIcons.paperclip,
                      tooltip: 'Upload a photo',
                      onTap: () => _comingSoon('Uploading photos'),
                    ),
                    _ComposerIcon(
                      icon: CupertinoIcons.camera,
                      tooltip: 'Take a photo',
                      onTap: () => _comingSoon('Taking photos'),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _SendButton(
            enabled: canSend && _composer.text.trim().isNotEmpty,
            loading: _sending,
            onTap: _sendText,
          ),
        ],
      ),
    );
  }

  /// Photo messages need a Supabase Storage bucket and a message kind that
  /// don't exist yet, so the two icons announce themselves rather than
  /// opening a picker that could never deliver anything. Same pattern the
  /// login screen uses for the reserved OAuth buttons.
  void _comingSoon(String what) {
    _focus.unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what is coming soon.')),
    );
  }
}

/* ── Composer icon ───────────────────────────────── */
/// Compact tap target for the controls living inside the input pill.
/// [IconButton]'s default 48pt box would push the pill far taller than the
/// single line of text it wraps.
class _ComposerIcon extends StatelessWidget {
  const _ComposerIcon({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      iconSize: 21,
      // Vertical padding matches the field's contentPadding, and
      // VisualDensity.compact is deliberately NOT set: it silently shaves 8px
      // off both axes, which made the icons 33px against the field's 45px.
      // The row is bottom-aligned, so that mismatch parked the glyphs ~6px
      // below the text's optical centre. Equal heights = equal centres.
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      constraints: const BoxConstraints(),
      icon: Icon(icon, color: color ?? AppColors.muted),
    );
  }
}

/* ── Header ──────────────────────────────────────── */
class _ChatHeader extends ConsumerWidget {
  const _ChatHeader({required this.onVoiceCall, required this.onVideoCall});

  /// Both reserved: there is no calling backend (no WebRTC, no Agora/Twilio
  /// in pubspec), so these announce themselves rather than opening a call
  /// that could never connect — same pattern as the composer's photo icons.
  final VoidCallback onVoiceCall, onVideoCall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final name = partner?.petName ?? partner?.displayName ?? '…';
    final flowers = (ref.watch(flowerMessagesProvider).valueOrNull ?? const [])
        .where((m) => !m.isText)
        .length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // The thread is a sub-route of the inbox now, so it needs a way
          // back to it.
          IconButton(
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(Routes.flowers),
            tooltip: 'Back',
            iconSize: 20,
            padding: const EdgeInsets.only(right: AppSpace.xs),
            constraints: const BoxConstraints(),
            icon: const Icon(CupertinoIcons.chevron_back,
                color: AppColors.muted),
          ),
          FlowerAvatar.of(partner, size: 40),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: AppText.title().copyWith(fontSize: 17)),
                Text(
                  flowers == 0
                      ? 'No flowers yet'
                      : '$flowers ${flowers == 1 ? 'flower' : 'flowers'} between you',
                  style: AppText.caption(),
                ),
              ],
            ),
          ),
          _HeaderAction(
            icon: CupertinoIcons.phone,
            tooltip: 'Voice call',
            onTap: onVoiceCall,
          ),
          _HeaderAction(
            icon: CupertinoIcons.video_camera,
            tooltip: 'Video call',
            onTap: onVideoCall,
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      iconSize: 22,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
      icon: Icon(icon, color: AppColors.secondary),
    );
  }
}

/* ── Empty thread ────────────────────────────────── */
class _EmptyThread extends StatelessWidget {
  const _EmptyThread();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpace.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌷', style: TextStyle(fontSize: 46)),
            const SizedBox(height: AppSpace.sm),
            Text('Nothing here yet', style: AppText.title()),
            const SizedBox(height: AppSpace.xxs),
            Text(
              'Tap the flower to start, or just say hello.',
              textAlign: TextAlign.center,
              style: AppText.body(),
            ),
          ],
        ),
      ),
    );
  }
}

/* ── Send button ─────────────────────────────────── */
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: AppMotion.micro,
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: AppGradients.cta,
            shape: BoxShape.circle,
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: SizedBox(
              // Matches the pill's single-line height so the circle sits
              // flush with it instead of looking sunken against the bottom.
              width: 44,
              height: 44,
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  : const Icon(
                      CupertinoIcons.paperplane_fill,
                      color: Colors.white,
                      size: 19,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
