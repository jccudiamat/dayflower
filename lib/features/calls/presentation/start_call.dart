import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../data/call_repository.dart';
import '../domain/call.dart';
import '../domain/call_notifier.dart';

/// Starts a call, or joins the one already running.
///
/// Joining wins over starting whenever a live call is in the thread —
/// otherwise pressing call during a call would open a second room beside
/// the one your partner is sitting in, which is the worst possible outcome
/// of a button labelled "call".
///
/// Navigation happens before the call connects, deliberately: dialling,
/// connecting and failing are all states the call screen draws, and
/// holding the user where they pressed until the media is up would make a
/// failed call look like a button that does nothing.
///
/// Shared by the chat header and chat settings, so the two call buttons
/// can never disagree about what pressing them does.
void startOrJoinCall(BuildContext context, WidgetRef ref, CallMode mode) {
  final notifier = ref.read(callNotifierProvider.notifier);
  final live = ref.read(liveCallProvider);

  if (live != null) {
    notifier.join(live);
  } else {
    notifier.place(mode);
  }
  context.push(Routes.call);
}
