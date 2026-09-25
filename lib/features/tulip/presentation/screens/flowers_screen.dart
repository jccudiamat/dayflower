import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dayflower/core/widgets/app_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../calls/data/call_repository.dart';
import '../../../calls/domain/call.dart';
import '../../../calls/presentation/start_call.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../../pairing/data/pair_repository.dart';
import '../../../presence/data/presence_repository.dart';
import '../../../presence/domain/presence.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/flower_repository.dart';
import '../../data/typing_repository.dart';
import '../../domain/flower_catalog.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/conversation_row.dart';
import '../widgets/message_quote.dart';
import '../widgets/share_your_day.dart';
import '../widgets/flower_catalog_panel.dart';
import '../widgets/composer_attachment.dart';
import '../widgets/typing_bubble.dart';
import '../widgets/voice_recorder_bar.dart';
import '../../data/voice_notes.dart';
import 'chat_settings_screen.dart';
import '../../../../core/widgets/profile_photo.dart';
import '../widgets/media_viewer.dart';

/// The Chat tab: the couple's conversation.
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
  const FlowersScreen({super.key, this.openFlowers = false});
  final bool openFlowers;

  @override
  ConsumerState<FlowersScreen> createState() => _FlowersScreenState();
}

class _FlowersScreenState extends ConsumerState<FlowersScreen> {
  final _composer = TextEditingController();
  final _focus = FocusNode();

  bool _panelOpen = false;
  bool _sending = false;
  bool _marking = false;

  /// The last read receipt did not reach the database. The list already
  /// counts these read (threadReadUpToProvider), so the unread count no
  /// longer prompts a retry; this does.
  bool _receiptFailed = false;

  /// The newest of their messages a receipt has been written for. The
  /// receipt is owed for anything of theirs newer than this, whatever the
  /// unread badge says: the badge counts replying as reading, and the
  /// database's receipts should not.
  DateTime? _receiptsUpTo;

  /// Pictures picked and waiting to go, with the words being typed as
  /// their caption.
  ///
  /// 🔴 **They used to send the instant you picked one**, with no review and
  /// no way to say anything about them. That was defended as being quicker
  /// than the camera screen, and it was — it was also the only place in the
  /// app where a mis-tap posted something irreversible. Held here instead,
  /// exactly as every other messenger holds them.
  final _attachments = <({Uint8List bytes, String extension})>[];

  /// Most pictures one message may carry.
  static const _maxAttachments = 4;

  /// Recording a voice message right now: the composer becomes the
  /// recorder bar for as long as this is true.
  bool _recording = false;

  /// A voice note is uploading.
  bool _sendingVoice = false;

  /// A picked photo is uploading. The icon greys and stops taking taps —
  /// the picker takes long enough to return that a second press is easy.
  bool _attaching = false;

  /// The message being replied to, held while the reply is typed.
  ///
  /// ⚠️ The whole message rather than its id: the strip above the field has
  /// to show *what* is being answered, and looking it back up out of the
  /// thread to draw two lines of preview would be a lookup for something we
  /// already had in hand when it was tapped.
  FlowerMessage? _replyingTo;

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

  /// The thread's scroll, for taking you to the message a reply quotes.
  final _thread = ScrollController();

  /// One key per message the thread has drawn, so a quoted one can be found
  /// on screen and scrolled into the middle of it.
  final _bubbleKeys = <String, GlobalKey>{};

  /// What the thread last drew, newest first. A tapped quote looks up where
  /// its message sits in this.
  List<FlowerMessage> _shown = const [];

  /// The message a quote just took you to, tinted for a moment so the eye
  /// lands on it rather than hunting for it.
  String? _highlightId;
  Timer? _highlightTimer;

  /// How far up from the newest message before the way back down appears.
  /// About two bubbles: a nudge while reading is not reading back.
  static const _readingBackAfter = 320.0;

  /// Scrolled up through older messages, so the arrow down is showing. A
  /// notifier rather than state: scrolling must not rebuild the thread.
  final _readingBack = ValueNotifier<bool>(false);

  /// The newest message there was when you scrolled up. Anything of theirs
  /// after it arrived while you were reading back, and counts on the arrow.
  DateTime? _readingBackFrom;

  /// Remembered so the catalog drawer opens at exactly the height the
  /// keyboard just vacated — otherwise swapping between the two makes the
  /// whole conversation jump. Seeded with a sane guess for the first open
  /// (and for web, where there are no view insets at all).
  double _keyboardHeight = 300;

  @override
  void initState() {
    super.initState();
    _panelOpen = widget.openFlowers;
    _thread.addListener(_onThreadScroll);
    _focus.addListener(() {
      // Tapping the field means "I want the keyboard", so the drawer yields.
      if (_focus.hasFocus && _panelOpen) setState(() => _panelOpen = false);
    });
  }

  @override
  void didUpdateWidget(covariant FlowersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openFlowers && !oldWidget.openFlowers) {
      _focus.unfocus();
      _panelOpen = true;
    }
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
    _thread.dispose();
    _readingBack.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _onThreadScroll() {
    final away = _thread.hasClients &&
        _thread.position.pixels > _readingBackAfter;
    if (away == _readingBack.value) return;
    if (away) _readingBackFrom = _shown.isEmpty ? null : _shown.first.sentAt;
    _readingBack.value = away;
  }

  /// Back down to the newest message, as WhatsApp's arrow does.
  Future<void> _toNewest() async {
    if (!_thread.hasClients) return;
    final position = _thread.position;
    // From far up, most of the way in one jump: easing through a long
    // history is a wait, not an animation.
    final screen = position.viewportDimension;
    if (position.pixels > 3 * screen) _thread.jumpTo(screen);
    await _thread.animateTo(0,
        duration: AppMotion.emotional, curve: AppMotion.easeOut);
  }

  /// Theirs, newer than where you were when you scrolled up. [shown] is
  /// newest first, so the count stops at the first one that is not.
  int _arrivedWhileReadingBack(List<FlowerMessage> shown, String? me) {
    final from = _readingBackFrom;
    if (from == null) return 0;
    var count = 0;
    for (final m in shown) {
      if (!m.sentAt.isAfter(from)) break;
      if (m.senderId != me) count++;
    }
    return count;
  }

  /// Takes you to the message a reply is answering, as WhatsApp does when
  /// you press the quote: scrolled into the middle and briefly tinted.
  ///
  /// ⚠️ The thread is a lazy list, so a message far up has not been built
  /// and has no position to scroll to. This walks toward it a screen at a
  /// time, each step short enough that nothing between two steps is skipped
  /// unbuilt, until its key has a context; then eases it into view. A quote
  /// always answers something older, so up is tried first; down covers the
  /// rare case where it is not.
  Future<void> _showQuoted(String id) async {
    final index = _shown.indexWhere((m) => m.id == id);
    if (index < 0) {
      // Not in the conversation. A My Day photo answered from the story
      // viewer never is (see chatMessagesProvider), but it still exists:
      // open the photo itself rather than saying it is gone.
      final quoted = ref.read(quotedMessageProvider(id));
      if (quoted != null && quoted.isPhoto && quoted.imagePath != null) {
        showPhotoMessage(context, ref, quoted);
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('That message is no longer here')));
      return;
    }

    BuildContext? built() {
      final context = _bubbleKeys[id]?.currentContext;
      return context != null && context.mounted ? context : null;
    }

    for (final up in [true, false]) {
      for (var step = 0; step < 600 && built() == null && mounted; step++) {
        if (!_thread.hasClients) return;
        final position = _thread.position;
        // Newest is at offset 0 in this reversed list, so older is higher.
        final edge = up ? position.maxScrollExtent : position.minScrollExtent;
        if (position.pixels == edge) break;
        // One screen: the list builds a margin past each edge, so a stride
        // of one viewport leaves no gap between what two steps built.
        final stride = position.viewportDimension;
        _thread.jumpTo((position.pixels + (up ? stride : -stride))
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble());
        await WidgetsBinding.instance.endOfFrame;
      }
      if (built() != null) break;
    }

    final target = built();
    if (target == null || !target.mounted) return;
    await Scrollable.ensureVisible(
      target,
      alignment: .5,
      duration: AppMotion.standard,
      curve: AppMotion.easeOut,
    );
    if (!mounted) return;
    _highlightTimer?.cancel();
    setState(() => _highlightId = id);
    _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _highlightId = null);
    });
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
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    // Read on this phone the moment it is on screen, before the receipt
    // round-trips. See threadReadUpToProvider.
    FlowerMessage? newest;
    for (final m in ref.read(flowerMessagesProvider).valueOrNull ?? const []) {
      if (m.senderId != userId) {
        if (newest == null || m.sentAt.isAfter(newest.sentAt)) newest = m;
      }
    }
    if (newest != null) {
      final read = ref.read(threadReadUpToProvider);
      if (read == null ||
          read.pairId != newest.pairId ||
          newest.sentAt.isAfter(read.at)) {
        ref.read(threadReadUpToProvider.notifier).state =
            (pairId: newest.pairId, at: newest.sentAt);
      }
    }

    if (_marking) return;
    final pair = ref.read(currentPairProvider).valueOrNull;
    if (pair == null) return;

    _marking = true;
    try {
      await ref
          .read(flowerRepositoryProvider)
          .markThreadSeen(pairId: pair.id, userId: userId);
      _receiptFailed = false;
      if (newest != null &&
          (_receiptsUpTo == null || newest.sentAt.isAfter(_receiptsUpTo!))) {
        _receiptsUpTo = newest.sentAt;
      }
    } catch (_) {
      // A failed receipt is not worth interrupting anyone over; the next
      // build will try again.
      _receiptFailed = true;
    } finally {
      _marking = false;
    }
  }

  void _startReply(FlowerMessage message) {
    setState(() => _replyingTo = message);
    _focus.requestFocus();
  }

  Future<void> _deleteMessage(FlowerMessage message) async {
    // ⚠️ Dropped from the pending list too. A message sent this session and
    // then deleted before the stream echoed it would otherwise stay on
    // screen — the row is gone, so no echo is ever coming to remove it.
    setState(() => _pending.removeWhere((m) => m.id == message.id));
    try {
      await ref.read(flowerRepositoryProvider).deleteMessage(message.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't delete that. Try again?")),
        );
      }
    }
  }

  /// Sends what is in the composer: the pictures on it, captioned by the
  /// words, or just the words.
  ///
  /// ⚠️ The caption goes on the **first** picture only. Repeating it on
  /// four would read as having said the same thing four times.
  Future<void> _sendText() async {
    final text = _composer.text.trim();
    if (_attachments.isNotEmpty) {
      await _sendAttachments(text);
      return;
    }
    if (text.isEmpty || _sending) return;

    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    if (pair == null || userId == null) return;

    // Cleared up front so the field empties on tap like every other chat;
    // restored below if the send actually fails.
    // ⚠️ Both cleared up front, so the field empties and the reply strip
    // closes on tap like every other chat. Restored below if the send
    // actually fails — including what it was answering, or the retry would
    // send a bare message where a reply was meant.
    final replyTo = _replyingTo;
    _composer.clear();
    // The message is the end of the sentence they were watching you write.
    ref.read(typingLineProvider)?.stop();
    // Sent from up in the history, it still lands at the bottom: go there
    // with it, as every chat does.
    if (_readingBack.value) _toNewest();
    setState(() {
      _sending = true;
      _replyingTo = null;
    });
    try {
      final sent = await ref.read(flowerRepositoryProvider).sendText(
            pairId: pair.id,
            senderId: userId,
            text: text,
            replyTo: replyTo?.id,
          );
      if (mounted) setState(() => _pending.add(sent));
    } catch (_) {
      if (mounted) {
        _composer.text = text;
        setState(() => _replyingTo = replyTo);
        _showError("Couldn't send that. Try again?");
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Uploads the pictures on the composer, oldest first so they land in the
  /// order they were picked.
  Future<void> _sendAttachments(String caption) async {
    if (_sending) return;
    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    if (pair == null || userId == null) return;

    final going = List.of(_attachments);
    final replyTo = _replyingTo;
    _composer.clear();
    ref.read(typingLineProvider)?.stop();
    setState(() {
      _sending = true;
      _attachments.clear();
      _replyingTo = null;
    });
    if (_readingBack.value) _toNewest();

    try {
      for (final (i, photo) in going.indexed) {
        final sent = await ref.read(flowerRepositoryProvider).sendDayPhotoTo(
              pairId: pair.id,
              senderId: userId,
              bytes: photo.bytes,
              fileExtension: photo.extension,
              note: i == 0 && caption.isNotEmpty ? caption : null,
              replyTo: i == 0 ? replyTo?.id : null,
              target: DayPhotoTarget.chat,
            );
        if (mounted) setState(() => _pending.add(sent));
      }
    } catch (_) {
      if (mounted) {
        // Put back what did not go, so trying again is one tap rather than
        // picking them all over.
        setState(() {
          _attachments.addAll(going);
          _replyingTo = replyTo;
        });
        _composer.text = caption;
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
    if (_readingBack.value) _toNewest();
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

    // Receipts for anything of theirs still unseen in the chat, once per
    // new message, and again only after a write that failed. Not the unread
    // count: that treats your reply as reading, which the database's
    // receipts (their ticks) must not assume.
    final me = ref.watch(currentUserIdProvider);
    DateTime? owed;
    for (final m in ref.watch(flowerMessagesProvider).valueOrNull ?? const []) {
      if (m.senderId != me && m.toChat && !m.isSeen &&
          (owed == null || m.sentAt.isAfter(owed))) {
        owed = m.sentAt;
      }
    }
    if (me != null &&
        owed != null &&
        (_receiptFailed ||
            _receiptsUpTo == null ||
            owed.isAfter(_receiptsUpTo!))) {
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ChatHeader(
              onVoiceCall: () => _startCall(CallMode.voice),
              onVideoCall: () => _startCall(CallMode.video),
              onOpenSettings: _openSettings,
            ),
            Expanded(child: _buildThread()),
            // ⚠️ At the foot of the conversation, where the next message
            // will appear, rather than in the header. The header says who
            // you are talking to; this is a thing happening in the thread,
            // and it belongs where you are already looking.
            const TypingFooter(),
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
        _shown = list;
        // Keys for messages since deleted would otherwise pile up forever.
        if (_bubbleKeys.length > list.length + 64) {
          final live = {for (final m in list) m.id};
          _bubbleKeys.removeWhere((id, _) => !live.contains(id));
        }
        if (list.isEmpty) return const _EmptyThread();

        return Stack(children: [
          _threadList(list, userId),
          // The way back down once you are reading back, carrying how many
          // of theirs came in meanwhile. Rebuilt with the thread, so a
          // message that lands while you are up there counts at once.
          Positioned(
            right: 12,
            bottom: 12,
            child: ValueListenableBuilder<bool>(
              valueListenable: _readingBack,
              builder: (context, away, _) => _ToNewestButton(
                visible: away,
                arrived: away ? _arrivedWhileReadingBack(list, userId) : 0,
                onTap: _toNewest,
              ),
            ),
          ),
        ]);
      },
    );
  }

  Widget _threadList(List<FlowerMessage> list, String? userId) {
    return ListView.builder(
          controller: _thread,
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
            final startsDay =
                older == null || !_sameDay(older.sentAt, message.sentAt);

            return Column(
              children: [
                if (startsDay) ChatDateDivider(date: message.sentAt),
                // The key is how a quote finds this message; the tint is
                // how you do, once it has scrolled you here. Drawn behind
                // the bubble and past it evenly on every side: the bubble
                // carries its own gap below, and a tint cut to its box
                // hugged the top and sagged at the bottom.
                Stack(
                  key: _bubbleKeys.putIfAbsent(message.id, GlobalKey.new),
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: -6,
                      bottom: 0,
                      left: -8,
                      right: -8,
                      child: IgnorePointer(
                        child: AnimatedContainer(
                          duration: AppMotion.emotional,
                          curve: AppMotion.easeOut,
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(
                                alpha: _highlightId == message.id ? .16 : 0),
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ),
                    ChatBubble(
                    message: message,
                    isMine: message.senderId == userId,
                    onReply: () => _startReply(message),
                    onQuoteTap: _showQuoted,
                    // ⚠️ Yours only. Deleting is taking back something you
                    // said, and nobody gets to take back what somebody else
                    // said.
                    onDelete: message.senderId == userId
                        ? () => _deleteMessage(message)
                        : null,
                  ),
                  ],
                ),
              ],
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

  /// The composer.
  ///
  /// 🔴 **Stacked, not a pill.** The field used to share one row with five
  /// icons, which gave the words about half the width and pushed the icons
  /// around every time the text grew. Now the text has the full width on
  /// top and the controls sit in their own row underneath, where they stay
  /// in the same place whether you have typed one line or five. Claude's
  /// composer, and every editor that has to hold both text and tools.
  Widget _buildComposer() {
    final canSend = !_sending && !_sendingVoice;
    final hasWords = _composer.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // What is being answered, above the field it is answered in.
          if (_replyingTo != null) _replyStrip(_replyingTo!),
          if (_recording)
            VoiceRecorderBar(
              onCancel: () => setState(() => _recording = false),
              onSend: _sendVoice,
            )
          else
            // A Material rather than a decorated Container so the icons
            // inside splash onto the box itself — ink looks for the nearest
            // Material, and on a plain Container that is the Scaffold
            // underneath, where the ripple is hidden.
            Material(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pictures waiting to go, above the words that will
                    // caption them.
                    if (_attachments.isNotEmpty) _attachmentStrip(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                      child: TextField(
                        controller: _composer,
                        focusNode: _focus,
                        minLines: 1,
                        // Taller than the old five: the field owns the full
                        // width now, so a long message is worth showing.
                        maxLines: 6,
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
                          contentPadding: EdgeInsets.zero,
                          hintText: _attachments.isEmpty
                              ? 'Message'
                              : 'Add a caption',
                          hintStyle: AppText.body(AppColors.muted),
                        ),
                        // Rebuilds the send button as the field fills, and
                        // tells them you are writing. Stopping on an empty
                        // field matters: clearing what you typed is changing
                        // your mind, and the ellipsis should go with it.
                        onChanged: (text) {
                          final line = ref.read(typingLineProvider);
                          text.trim().isEmpty ? line?.stop() : line?.poke();
                          setState(() {});
                        },
                      ),
                    ),
                    Row(
                      children: [
                        // The catalog opener. Becomes a keyboard glyph while
                        // the drawer is up, so one button always toggles back
                        // to the other input.
                        _ComposerIcon(
                          icon: _panelOpen
                              ? CupertinoIcons.keyboard
                              : Icons.local_florist_rounded,
                          color: _panelOpen ? AppColors.muted : AppColors.brand,
                          tooltip: _panelOpen ? 'Keyboard' : 'Send a flower',
                          onTap: _togglePanel,
                        ),
                        _ComposerIcon(
                          icon: CupertinoIcons.photo,
                          tooltip: 'Attach a photo',
                          onTap: _attaching || _full ? () {} : _attachPhoto,
                          color:
                              _attaching || _full ? AppColors.muted : null,
                        ),
                        _ComposerIcon(
                          icon: CupertinoIcons.camera,
                          tooltip: 'Take a photo',
                          onTap: _openCamera,
                        ),
                        // ⚠️ Only where there is something to record with.
                        // Every other platform gets no button rather than one
                        // that fails when pressed.
                        if (VoiceNotes.supported)
                          _ComposerIcon(
                            icon: CupertinoIcons.mic,
                            tooltip: 'Record a voice message',
                            onTap: _sendingVoice ? () {} : _startRecording,
                            color: _sendingVoice ? AppColors.muted : null,
                          ),
                        const Spacer(),
                        _SendButton(
                          enabled: canSend &&
                              (hasWords || _attachments.isNotEmpty),
                          loading: _sending || _sendingVoice,
                          onTap: _sendText,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Whether the most pictures one message may carry are already on.
  bool get _full => _attachments.length >= _maxAttachments;

  /// Pictures picked but not yet sent, each with a way to take it off again.
  Widget _attachmentStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: SizedBox(
        height: ComposerAttachment.size + 6,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _attachments.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) => ComposerAttachment(
            bytes: _attachments[i].bytes,
            index: i,
            onRemove: () => setState(() => _attachments.removeAt(i)),
          ),
        ),
      ),
    );
  }

  /// The "replying to" strip.
  ///
  /// ⚠️ Carries its own way out. A reply you cannot cancel is a mode you are
  /// stuck in, and the only other exit would be sending something.
  Widget _replyStrip(FlowerMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: MessageQuote(replyTo: message.id, onDark: false)),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _replyingTo = null),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child:
                  AppIcon(CupertinoIcons.xmark, size: 15, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the camera, pointed at this conversation.
  ///
  /// ⚠️ The destination is set *before* navigating. The camera defaults to
  /// the home-screen widget, which is right when you go there yourself and
  /// wrong when you arrived from the thread — a photo taken from here should
  /// land where you were, and finding out otherwise costs a send.
  void _openCamera() {
    _focus.unfocus();
    ref.read(dayPhotoTargetProvider.notifier).state = DayPhotoTarget.chat;
    context.push(Routes.flowers);
  }

  /// Puts pictures from the gallery on the composer, ready to send.
  ///
  /// 🔴 **Chat only.** A photo attached to a message is a message, not a
  /// day on their home screen — see DayPhotoTarget, which lost its "Both"
  /// for the same reason. The camera screen still offers My Day; this does
  /// not, because nobody attaching a picture mid-sentence means to park it
  /// on somebody's home screen for a day.
  Future<void> _attachPhoto() async {
    if (_attaching || _full) return;
    _focus.unfocus();
    setState(() => _attaching = true);
    try {
      final picked = await ImagePicker().pickMultiImage(
        // ⚠️ The same ceiling the camera uses. This is the only copy that
        // will exist, and a 12MP original helps nobody read a message.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
        limit: _maxAttachments - _attachments.length,
      );
      if (picked.isEmpty || !mounted) return;
      final read = [
        for (final file in picked.take(_maxAttachments - _attachments.length))
          (
            bytes: await file.readAsBytes(),
            extension: file.path.split('.').last.toLowerCase() == 'png'
                ? 'png'
                : 'jpg',
          ),
      ];
      if (!mounted) return;
      setState(() => _attachments.addAll(read));
      _focus.requestFocus();
    } catch (_) {
      if (mounted) _showError("Couldn't open your photos. Try again?");
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  /// Begins a voice message. The composer becomes the recorder bar.
  ///
  /// ⚠️ The keyboard goes first. The bar replaces the field, so leaving the
  /// keyboard up would leave it pointing at something that is no longer
  /// there.
  Future<void> _startRecording() async {
    if (_recording || _sendingVoice) return;
    _focus.unfocus();
    ref.read(typingLineProvider)?.stop();
    // One sound at a time: recording over a playing voice note would put
    // their voice into yours.
    if (ref.read(playingVoiceProvider) != null) {
      await VoiceNotes.stopPlaying();
      ref.read(playingVoiceProvider.notifier).state = null;
    }
    try {
      await VoiceNotes.startRecording();
      if (mounted) setState(() => _recording = true);
    } catch (e) {
      // Refused microphone, or a phone that will not record while something
      // else holds it. Saying so beats a bar that never moves.
      if (mounted) {
        _showError('Dayflower needs the microphone to record a voice message.');
      }
    }
  }

  /// Uploads what was recorded and puts it in the thread.
  Future<void> _sendVoice(({String path, Duration length})? recording) async {
    setState(() => _recording = false);
    if (recording == null) return;

    final pair = ref.read(currentPairProvider).valueOrNull;
    final userId = ref.read(currentUserIdProvider);
    if (pair == null || userId == null) return;

    final replyTo = _replyingTo;
    setState(() {
      _sendingVoice = true;
      _replyingTo = null;
    });
    if (_readingBack.value) _toNewest();
    try {
      final file = File(recording.path);
      final bytes = await file.readAsBytes();
      final sent = await ref.read(flowerRepositoryProvider).sendVoiceNote(
            pairId: pair.id,
            senderId: userId,
            bytes: bytes,
            length: recording.length,
            replyTo: replyTo?.id,
          );
      // Their own voice plays from the phone rather than downloading back
      // down what was just uploaded.
      if (sent.audioPath != null) {
        await VoiceNoteFiles.prime(sent.audioPath!, recording.path);
      }
      if (mounted) setState(() => _pending.add(sent));
    } catch (e) {
      if (mounted) {
        setState(() => _replyingTo = replyTo);
        _showError("Couldn't send that voice message. Try again?");
      }
    } finally {
      if (mounted) setState(() => _sendingVoice = false);
    }
  }

  /// Starts a call, or joins the one already running. See startOrJoinCall.
  void _startCall(CallMode mode) {
    _focus.unfocus();
    startOrJoinCall(context, ref, mode);
  }

  /// Chat settings, and whatever it sends you back here to do: write to
  /// them, or look at a message a search found.
  Future<void> _openSettings() async {
    _focus.unfocus();
    final back = await context.push<ChatReturn>(Routes.chatSettings);
    if (!mounted || back == null) return;
    switch (back) {
      case ChatReturn(showId: final id?):
        await _showQuoted(id);
      case _:
        setState(() => _panelOpen = false);
        _focus.requestFocus();
    }
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
      icon: AppIcon(icon, color: color ?? AppColors.muted),
    );
  }
}

/* ── Header ──────────────────────────────────────── */
class _ChatHeader extends ConsumerWidget {
  const _ChatHeader({
    required this.onVoiceCall,
    required this.onVideoCall,
    required this.onOpenSettings,
  });

  /// Start a call, or join the one already running — see `_startCall`.
  ///
  /// The media provider is still behind [CallTransport] and unconfigured, so
  /// on today's build these reach the call screen and land on its "not
  /// switched on yet" state. That is deliberate rather than a stub: the row
  /// in the thread is written either way, so the partner gets a real
  /// invitation even on a build (or a network) where the audio never comes
  /// up. See the header of migration 0025.
  final VoidCallback onVoiceCall, onVideoCall;

  /// Their name opens chat settings; see `_openSettings` for what comes
  /// back from it.
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The live row, not the cached one, so a changed name or face lands
    // while they are looking at the thread.
    final partner = ref.watch(partnerProfileStreamProvider).valueOrNull ??
        ref.watch(partnerProfileProvider).valueOrNull;
    final name = partner?.petName ?? partner?.displayName ?? '…';
    // Their mood lives on the Flowers card now. Here, the useful thing about
    // the person you are typing to is whether they are there to read it.
    final active = activeLabel(ref.watch(partnerLastActiveProvider).valueOrNull);
    final live = ref.watch(liveCallProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Back to the Chats list, which is where the conversation is
          // opened from. Not `Routes.flowers`: that path is the camera (see
          // messages_screen.dart). Opened from a notification there is
          // nothing to pop, so it goes to the list rather than Home.
          IconButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(Routes.chats),
            tooltip: 'Back',
            iconSize: 20,
            padding: const EdgeInsets.only(right: AppSpace.xs),
            constraints: const BoxConstraints(),
            icon:
                AppIcon(CupertinoIcons.chevron_back, color: AppColors.muted),
          ),
          // Two targets now, as WhatsApp has them: their face opens their
          // photo, their name opens chat settings. It used to be one target,
          // on the grounds that people press the person - but pressing the
          // picture is how everyone expects to see the picture.
          ProfilePhotoButton(profile: partner, name: name, size: 40),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: InkWell(
              onTap: onOpenSettings,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Row(children: [
                Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: AppText.title().copyWith(fontSize: 17)),
                // Whether they are there, rather than a running total of
                // flowers. The count was true and told you nothing you would
                // act on; this is the one line that changes while you read.
                //
                // ⚠️ Nothing at all when we have never heard from their
                // phone — see activeLabel. A partner on a build with no
                // heartbeat is not "away", we simply do not know, and a
                // header must not turn that into a claim about them.
                if (active != null)
                  Text(
                    active,
                    style: active == 'Active now'
                        ? AppText.caption(AppColors.secondary)
                        : AppText.caption(),
                  ),
              ],
            ),
                ),
              ]),
            ),
          ),
          // A live call re-labels both icons and tints them: during a call
          // these are the way back into it, and offering "Voice call" while
          // one is already running invites a second empty room.
          _HeaderAction(
            icon: CupertinoIcons.phone,
            tooltip: live == null ? 'Voice call' : 'Join the call',
            color: live == null ? null : AppColors.brand,
            onTap: onVoiceCall,
          ),
          _HeaderAction(
            icon: CupertinoIcons.video_camera,
            tooltip: live == null ? 'Video call' : 'Join the call',
            color: live == null ? null : AppColors.brand,
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
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Purple unless told otherwise. Overridden to pink only while a call is
  /// live, which is the one moment these icons mean something different
  /// from what they usually mean.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      iconSize: 22,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
      icon: AppIcon(icon, color: color ?? AppColors.secondary),
    );
  }
}

/* ── Back to the newest ──────────────────────────── */
/// The round arrow in the corner of the thread while you read back, as
/// WhatsApp has it. Carries a count when theirs arrived meanwhile.
class _ToNewestButton extends StatelessWidget {
  const _ToNewestButton({
    required this.visible,
    required this.arrived,
    required this.onTap,
  });

  final bool visible;
  final int arrived;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppMotion.micro,
        child: AnimatedScale(
          scale: visible ? 1 : .6,
          duration: AppMotion.standard,
          curve: AppMotion.easeOut,
          child: Semantics(
            button: true,
            label: arrived > 0
                ? '$arrived new, go to the newest message'
                : 'Go to the newest message',
            excludeSemantics: true,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                DecoratedBox(
                  // The card's shadow, not the lift's: this floats over
                  // bubbles, and a deep shadow smudged the one under it.
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: AppElevation.card,
                  ),
                  child: Material(
                    color: AppColors.surface,
                    shape: CircleBorder(
                        side: BorderSide(color: AppColors.border)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onTap,
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: AppIcon(CupertinoIcons.chevron_down,
                            size: 18, color: AppColors.body),
                      ),
                    ),
                  ),
                ),
                if (arrived > 0)
                  Positioned(
                    top: -8,
                    right: -6,
                    child: UnreadBadge(arrived),
                  ),
              ],
            ),
          ),
        ),
      ),
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
                  : const AppIcon(
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
