import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/sticky_note.dart';
import 'reminder_repository.dart';

/// Sticks one note on the home screen.
///
/// ## Why this is a platform channel and not a plugin
///
/// `requestPinAppWidget` is a method on `AppWidgetManager`, and the note has
/// to reach the new widget *with* it — a widget pinned first and filled in
/// afterwards shows an empty card for however long the round trip takes.
/// `home_widget` can write the data but cannot ask a launcher to pin
/// anything, so this is about forty lines of Kotlin. The same argument
/// MainActivity already makes for picture-in-picture: the last dependency
/// added to reach a platform feature would have broken the Android build.
///
/// ⚠️ **The launcher owns the last step.** `requestPinAppWidget` shows the
/// launcher's own confirmation, and a person can dismiss it. Returning true
/// means the request was *made*, never that a note is on a home screen —
/// so nothing here may tell the user it landed.
class StickyNotePinner {
  StickyNotePinner._();

  static const _channel = MethodChannel('dayflower/sticky_note');

  /// Whether asking is even possible.
  ///
  /// `requestPinAppWidget` is API 26+, and this app's `minSdk` is 24. Older
  /// phones — and any launcher that declines to support pinning — still get
  /// the widget from the tray; they just cannot be handed one.
  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// Asks the launcher to pin [reminder] as its own note.
  ///
  /// The paper colour is resolved **here** and passed across rather than
  /// re-derived in Kotlin. Two implementations of one hash in two languages
  /// drift silently, and the failure would be a note that changes colour
  /// when you put it on your home screen — see [stickyNotePaperFor].
  static Future<bool> pin(Reminder reminder) async {
    if (!supported) return false;

    final paper = stickyNotePaperFor(reminder.id);
    try {
      final asked = await _channel.invokeMethod<bool>('pin', {
        'id': reminder.id,
        'emoji': reminder.emoji,
        'title': reminder.title,
        'note': reminder.note ?? '',
        'remindAt': reminder.remindAt.millisecondsSinceEpoch,
        'done': reminder.isDone,
        'repeats': reminder.repeats,
        // ARGB ints, which is what RemoteViews.setInt wants anyway.
        'fill': _argb(paper.fill),
        'edge': _argb(paper.edge),
        'ink': _argb(paper.ink),
      });
      return asked ?? false;
    } on PlatformException {
      // A launcher that refuses, or an OEM that never implemented the
      // request. Not an error worth a crash — the widget tray still works.
      return false;
    } on MissingPluginException {
      // The Dart side shipped ahead of the Kotlin. Same answer.
      return false;
    }
  }

  static int _argb(Color c) =>
      (c.a * 255).round() << 24 |
      (c.r * 255).round() << 16 |
      (c.g * 255).round() << 8 |
      (c.b * 255).round();
}
