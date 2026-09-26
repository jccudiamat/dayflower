import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Every snackbar in the app: shown clear of whatever is at the bottom of
/// the screen, and always with an X to close it.
///
/// 🔴 **Snackbars sat on top of the tab bar and the chat's text box.** The
/// shell (AppShell) wraps every page in a Scaffold of its own, and a
/// snackbar is drawn by the outermost Scaffold, which has no tab bar or
/// composer to keep clear of. So it floated at the very bottom of the
/// screen, over them. That Scaffold stays: it is also what puts a snackbar
/// shown from a bottom sheet above the sheet, and lets one shown as a page
/// closes outlive the page. Instead, this is the messenger every
/// `ScaffoldMessenger.of(context)` in the app finds, and it measures what is
/// at the bottom when a snackbar is shown and lifts the snackbar clear:
///
///  - anything wrapped in a [SnackBarObstacle] on a page that is showing:
///    the tab bar, the chat's composer, the camera's controls; and
///  - a text field being typed in, if it sits where the snackbar would.
///
/// ⚠️ The X is added here, to every snackbar, rather than at each of the
/// sixty places that show one. A rule kept in one place cannot be forgotten
/// in the sixty-first, and a snackbar that says `showCloseIcon: false` gets
/// one anyway.
class AppSnackBars extends ScaffoldMessenger {
  const AppSnackBars({super.key, required super.child});

  @override
  ScaffoldMessengerState createState() => _AppSnackBarsState();
}

class _AppSnackBarsState extends ScaffoldMessengerState {
  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) =>
      super.showSnackBar(placeSnackBar(context, snackBar),
          snackBarAnimationStyle: snackBarAnimationStyle);
}

/// Something at the bottom of the screen a snackbar must not cover.
///
/// Counted only while its page is showing: a tab bar on a page underneath
/// the chat is still in the tree, and lifting the chat's snackbars clear of
/// it would put them in the middle of the conversation.
class SnackBarObstacle extends SingleChildRenderObjectWidget {
  const SnackBarObstacle({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderSnackBarObstacle(showing: TickerMode.valuesOf(context).enabled);

  @override
  void updateRenderObject(BuildContext context, RenderSnackBarObstacle renderObject) {
    renderObject.showing = TickerMode.valuesOf(context).enabled;
  }
}

final _obstacles = <RenderSnackBarObstacle>{};

/// The render object behind [SnackBarObstacle].
class RenderSnackBarObstacle extends RenderProxyBox {
  RenderSnackBarObstacle({required this.showing});

  /// False once its page is covered by another, where tickers stop too.
  bool showing;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _obstacles.add(this);
  }

  @override
  void detach() {
    _obstacles.remove(this);
    super.detach();
  }
}

/// Space kept between a snackbar and what it is lifted over.
const snackBarGap = 8.0;

/// [snackBar] as it is shown: with its X, and lifted clear of the bottom of
/// the screen as it is when shown.
///
/// Measured once, when shown. The Scaffold drawing it still moves it up with
/// the keyboard, and the tab bar and the composer ride on the keyboard too,
/// so the gap holds while it is up.
@visibleForTesting
SnackBar placeSnackBar(BuildContext context, SnackBar snackBar) {
  final media = MediaQuery.of(context);
  final defaults =
      Theme.of(context).snackBarTheme.insetPadding ??
          const EdgeInsets.fromLTRB(15, 5, 15, 10);
  final floating = (snackBar.behavior ??
          Theme.of(context).snackBarTheme.behavior ??
          SnackBarBehavior.fixed) ==
      SnackBarBehavior.floating;

  var margin = snackBar.margin?.resolve(Directionality.of(context));
  if (floating) {
    margin ??= snackBar.width == null
        ? defaults
        : defaults.copyWith(
            left: math.max(0, (media.size.width - snackBar.width!) / 2),
            right: math.max(0, (media.size.width - snackBar.width!) / 2));
    final lift = _lift(media);
    if (lift > margin.bottom) margin = margin.copyWith(bottom: lift);
  }

  return SnackBar(
    key: snackBar.key,
    content: snackBar.content,
    backgroundColor: snackBar.backgroundColor,
    elevation: snackBar.elevation,
    // ⚠️ A fixed snackbar spans the bottom edge and takes no margin; only a
    // floating one (the app's theme) can be lifted.
    margin: floating ? margin : null,
    padding: snackBar.padding,
    width: null,
    shape: snackBar.shape,
    hitTestBehavior: snackBar.hitTestBehavior,
    behavior: snackBar.behavior,
    action: snackBar.action,
    actionOverflowThreshold: snackBar.actionOverflowThreshold,
    showCloseIcon: true,
    closeIconColor: snackBar.closeIconColor,
    duration: snackBar.duration,
    persist: snackBar.persist,
    animation: snackBar.animation,
    onVisible: snackBar.onVisible,
    dismissDirection: snackBar.dismissDirection,
    clipBehavior: snackBar.clipBehavior,
  );
}

/// How far above its usual place a snackbar has to sit, from the bottom of
/// the space the Scaffold already keeps it in, to clear what is there.
double _lift(MediaQueryData media) {
  final height = media.size.height;
  // Where a floating snackbar's bottom edge goes on its own: on the
  // keyboard when it is up, above the gesture bar otherwise. The Scaffold
  // does this much by itself.
  final keyboard = media.viewInsets.bottom;
  final floor = height - (keyboard > 0 ? keyboard : media.viewPadding.bottom);

  var clearTop = double.infinity;
  for (final obstacle in _obstacles) {
    if (!obstacle.showing || !obstacle.attached || !obstacle.hasSize) continue;
    final top = obstacle.localToGlobal(Offset.zero).dy;
    // Something drawn off the bottom of the screen covers nothing.
    if (top >= height) continue;
    clearTop = math.min(clearTop, top);
  }

  // A text field being typed in, if it sits where the snackbar would. One
  // higher up is not in the way, and lifting the snackbar over a search box
  // at the top of the screen would take it off the screen.
  final field = _typingIn();
  if (field != null && field.bottom > floor - _zone) {
    clearTop = math.min(clearTop, field.top);
  }

  if (clearTop == double.infinity) return 0;
  final lift = floor - clearTop + snackBarGap;
  // Never so high that a snackbar of a few lines leaves the screen: the
  // Scaffold asserts on that, and a snackbar out of sight says nothing.
  final highest = floor - media.viewPadding.top - _tallest;
  return lift.clamp(0.0, math.max(0.0, highest));
}

/// The height of a snackbar, from its bottom edge up, that a text field has
/// to be inside to count as underneath it.
const _zone = 96.0;

/// Room kept above a lifted snackbar for a few lines of text.
const _tallest = 140.0;

/// Where the text field being typed in is on screen, if one is.
Rect? _typingIn() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null || !context.mounted) return null;
  final editable = context.widget is EditableText
      ? context
      : context.findAncestorStateOfType<EditableTextState>()?.context;
  final box = editable?.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  // The box drawn around the text sits a little outside it.
  return (box.localToGlobal(Offset.zero) & box.size).inflate(snackBarGap);
}
