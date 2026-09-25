import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app_router.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../onboarding/data/user_repository.dart';
import '../../data/flower_repository.dart';
import '../widgets/conversation_row.dart';

/// The words a message can be found by: what was written on it, and for a
/// flower its name too. Null for what has none, a call or a bare photo.
String? searchableText(FlowerMessage m) {
  if (m.isCall) return null;
  final note = (m.note ?? '').trim();
  if (m.isPhoto || m.isText) return note.isEmpty ? null : note;
  final name = m.flower?.name;
  final words = [if (name != null) name, if (note.isNotEmpty) note].join(' · ');
  return words.isEmpty ? null : words;
}

/// The messages with [query] in them, newest first as [messages] are.
/// Case never matters: nobody remembers how they capitalised something.
List<FlowerMessage> searchMessages(List<FlowerMessage> messages, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return [
    for (final m in messages)
      if (searchableText(m)?.toLowerCase().contains(q) ?? false) m,
  ];
}

/// [text] from a little before the first match, so a long message still
/// shows the part you were looking for. Starts on a word, marked with "…".
String snippetAround(String text, String query, {int lead = 24}) {
  final at = text.toLowerCase().indexOf(query.trim().toLowerCase());
  if (at <= lead) return text;
  var start = at - lead;
  final space = text.indexOf(' ', start);
  if (space >= 0 && space < at) start = space + 1;
  return '…${text.substring(start)}';
}

/// Finding a message by a word in it. Reached from Search in chat settings.
///
/// A picked result goes back to the conversation, which scrolls to it and
/// tints it the way a tapped quote does: the message is worth most with
/// what was said around it, and only the thread has that.
class ChatSearchScreen extends ConsumerStatefulWidget {
  const ChatSearchScreen({super.key});

  @override
  ConsumerState<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends ConsumerState<ChatSearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _open(FlowerMessage m) {
    if (context.canPop()) {
      context.pop(m.id);
    } else {
      context.go(Routes.chat);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim();
    // The conversation as the thread shows it: a photo sent only to the
    // home screen is not in the chat, so it is not found in the chat.
    final messages = ref.watch(chatMessagesProvider).valueOrNull ?? const [];
    final me = ref.watch(currentUserIdProvider);
    final partner = ref.watch(partnerProfileProvider).valueOrNull;
    final them = partner?.petName ?? partner?.displayName ?? 'Them';
    final hits = searchMessages(messages, query);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _SearchBar(
              controller: _query,
              onChanged: () => setState(() {}),
            ),
            Expanded(
              child: query.isEmpty
                  ? const _Hint('Find a message by any word in it.')
                  : hits.isEmpty
                      ? _Hint('No messages with “$query”.')
                      : ListView.separated(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.only(bottom: AppSpace.lg),
                          itemCount: hits.length + 1,
                          separatorBuilder: (_, i) => i == 0
                              ? const SizedBox.shrink()
                              : Divider(
                                  height: 1,
                                  indent: ChatsStyle.gutter,
                                  color: AppColors.border),
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    ChatsStyle.gutter,
                                    AppSpace.sm,
                                    ChatsStyle.gutter,
                                    AppSpace.xxs),
                                child: Text(
                                  '${hits.length} '
                                  '${hits.length == 1 ? 'MESSAGE' : 'MESSAGES'}',
                                  style: AppText.label(),
                                ),
                              );
                            }
                            final m = hits[i - 1];
                            return _SearchResult(
                              message: m,
                              query: query,
                              sender: m.senderId == me ? 'You' : them,
                              onTap: () => _open(m),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back, and the field. Drawn as the chat's own header is, so the search
/// reads as part of the conversation rather than a page of its own.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(Routes.chatSettings),
            tooltip: 'Back',
            iconSize: 20,
            padding: const EdgeInsets.only(right: AppSpace.xs),
            constraints: const BoxConstraints(),
            icon: AppIcon(CupertinoIcons.chevron_back, color: AppColors.muted),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              style: AppText.body(AppColors.ink),
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceSubtle,
                hintText: 'Search messages',
                hintStyle: AppText.body(AppColors.muted),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                prefixIcon: AppIcon(CupertinoIcons.search,
                    size: 18, color: AppColors.muted),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 40, minHeight: 20),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        onPressed: () {
                          controller.clear();
                          onChanged();
                        },
                        icon: AppIcon(CupertinoIcons.xmark_circle_fill,
                            size: 18, color: AppColors.muted),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One found message: who said it and when, and the words with what you
/// typed picked out in them.
class _SearchResult extends StatelessWidget {
  const _SearchResult({
    required this.message,
    required this.query,
    required this.sender,
    required this.onTap,
  });

  final FlowerMessage message;
  final String query;
  final String sender;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = snippetAround(searchableText(message) ?? '', query);
    final kind = message.isPhoto
        ? CupertinoIcons.photo
        : message.isText
            ? null
            : Icons.local_florist_rounded;
    final body = AppText.body(AppColors.body);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: ChatsStyle.gutter, vertical: AppSpace.compact),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(sender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.subtitle().copyWith(fontSize: 15)),
                ),
                const SizedBox(width: AppSpace.xs),
                Text(searchStamp(message.sentAt), style: AppText.caption()),
              ],
            ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(children: [
                if (kind != null)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: AppIcon(kind, size: 15, color: AppColors.muted),
                    ),
                  ),
                ..._marked(text, query, body),
              ]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: body,
            ),
          ],
        ),
      ),
    );
  }

  /// [text] with every match of [query] in bold pink.
  static List<TextSpan> _marked(String text, String query, TextStyle style) {
    final q = query.trim().toLowerCase();
    final lower = text.toLowerCase();
    // Lowercasing can change a string's length (a dotted capital I, for
    // one), and then positions found in one do not fit the other. Unmarked
    // is better than marking the wrong letters.
    if (q.isEmpty || lower.length != text.length) return [TextSpan(text: text)];
    final mark = style.copyWith(
        color: AppColors.brand, fontWeight: FontWeight.w700);
    final spans = <TextSpan>[];
    var from = 0;
    while (true) {
      final at = lower.indexOf(q, from);
      if (at < 0) break;
      if (at > from) spans.add(TextSpan(text: text.substring(from, at)));
      spans.add(TextSpan(text: text.substring(at, at + q.length), style: mark));
      from = at + q.length;
    }
    if (from < text.length) spans.add(TextSpan(text: text.substring(from)));
    return spans;
  }
}

/// The chat list's ladder (time, Yesterday, weekday, date), with the year
/// added once it is not this one: a search reaches back further than a
/// list of chats ever shows.
String searchStamp(DateTime sentAt, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final at = sentAt.toLocal();
  if (at.year != clock.year) return DateFormat('d MMM y').format(at);
  return conversationStamp(sentAt, now: clock);
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(text,
              textAlign: TextAlign.center,
              style: AppText.body(AppColors.muted)),
        ),
      );
}
