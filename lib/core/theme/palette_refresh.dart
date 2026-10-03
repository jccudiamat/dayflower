import 'package:flutter/widgets.dart';

/// Runs `build` again on every widget under [root], `const` ones included,
/// so each reads the palette [AppColors] holds now.
///
/// 🔴 **What the MaterialApp's key cannot reach.** A const widget is
/// identical to itself, so a rebuild above it skips it and a colour it read
/// from the global palette stays the one it was first built with (see
/// theme_repaint_test). Rekeying the MaterialApp throws its subtree away,
/// but GoRouter's navigator has a GlobalKey and is carried across the
/// rekey with its pages intact, so the screen on show keeps its stale const
/// pieces. Seen on the emulator: the phone went dark under Appearance,
/// System, and the welcome screen's "Dayflower" stayed dark ink on a dark
/// page.
///
/// It was survivable while the only way to switch was the setting itself,
/// on Settings, whose cards read through Theme for exactly this reason.
/// Following the phone means a switch can happen on any screen at sunset,
/// so every element is marked, as hot reload marks them. Once per switch.
///
/// ⚠️ Call it outside a build: from a post-frame callback.
void rebuildEverything(Element root) {
  void mark(Element element) {
    element.markNeedsBuild();
    element.visitChildren(mark);
  }

  root.visitChildren(mark);
}
