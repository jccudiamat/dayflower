import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Original Instagram-style UI artwork: 24px canvas, rounded 1.8px strokes.
/// Existing IconData keeps domain models and button APIs compatible. Brand
/// marks use their original glyphs. These are not official Instagram assets.
class AppIcon extends Icon {
  const AppIcon(
    super.icon, {
    super.key,
    super.size,
    super.color,
    super.semanticLabel,
    super.textDirection,
    this.selected = false,
  });

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final artwork = (selected ? _selected[icon] : null) ?? _artwork[icon];
    if (artwork == null) return super.build(context);
    final theme = IconTheme.of(context);
    final dimension = size ?? theme.size ?? 24;
    final foreground = color ?? theme.color ?? const Color(0xff000000);
    final opacity = theme.opacity ?? 1;
    Widget picture = SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
      'fill="none" stroke="black" stroke-width="1.8" '
      'stroke-linecap="round" stroke-linejoin="round">$artwork</svg>',
      width: dimension,
      height: dimension,
      colorFilter: ColorFilter.mode(
          foreground.withValues(alpha: foreground.a * opacity),
          BlendMode.srcIn),
      excludeFromSemantics: true,
    );
    final direction = textDirection ?? Directionality.of(context);
    if ((icon?.matchTextDirection ?? false) && direction == TextDirection.rtl) {
      picture = Transform.flip(flipX: true, child: picture);
    }
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: dimension,
          child: Center(child: picture),
        ),
      ),
    );
  }
}

const _home =
    '<path d="M3 10 12 2.8 21 10v10.2a1 1 0 0 1-1 1h-5.5v-7h-5v7H4a1 1 0 0 1-1-1Z"/>';
const _homeFilled =
    '<path fill="black" d="M3 10 12 2.8 21 10v10.2a1 1 0 0 1-1 1h-5.5v-7h-5v7H4a1 1 0 0 1-1-1Z"/>';
const _heart =
    '<path d="M20.5 4.8c-2.3-2.1-6-1.4-8.5 1.5-2.5-2.9-6.2-3.6-8.5-1.5-2.6 2.5-1.6 6.4.8 9L12 21l7.7-7.2c2.4-2.6 3.4-6.5.8-9Z"/>';
const _heartFilled = '<g fill="black">$_heart</g>';
const _camera =
    '<rect x="2.5" y="5.5" width="19" height="15" rx="3"/><path d="m7 5.5 1.5-3h7l1.5 3"/><circle cx="12" cy="13" r="4"/><circle cx="18.3" cy="8.8" r=".7" fill="black" stroke="none"/>';
const _cameraFilled =
    '<path fill="black" fill-rule="evenodd" stroke="none" d="M8 2h8l1.5 3H19a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3H5a3 3 0 0 1-3-3V8a3 3 0 0 1 3-3h1.5ZM12 8a5 5 0 1 0 0 10 5 5 0 0 0 0-10Zm0 2a3 3 0 1 1 0 6 3 3 0 0 1 0-6Z"/>';
const _gift =
    '<rect x="3" y="10" width="18" height="11" rx="1"/><rect x="2" y="6" width="20" height="4" rx="1"/><path d="M12 6v15M12 6C5 6 4 3 6 2s5 1 6 4Zm0 0c7 0 8-3 6-4s-5 1-6 4Z"/>';
const _giftFilled =
    '<path d="M12 6C5 6 4 3 6 2s5 1 6 4Zm0 0c7 0 8-3 6-4s-5 1-6 4Z"/><path fill="black" stroke="none" d="M2 6h9v4H2Zm11 0h9v4h-9ZM3 12h8v9H3Zm10 0h8v9h-8Z"/>';
const _grid =
    '<rect x="3" y="3" width="6.5" height="6.5" rx="1"/><rect x="14.5" y="3" width="6.5" height="6.5" rx="1"/><rect x="3" y="14.5" width="6.5" height="6.5" rx="1"/><rect x="14.5" y="14.5" width="6.5" height="6.5" rx="1"/>';
const _flower =
    '<path d="M12 14c-2.5 2-5.5.5-5-2.3C3.5 11 4 7.5 7 7c-.5-3 3-4.5 5-2 2-2.5 5.5-1 5 2 3 .5 3.5 4 0 4.7.5 2.8-2.5 4.3-5 2.3ZM12 15v7m0-3c-3 0-5-1-5-3m5 5c3 0 5-1 5-3"/><circle cx="12" cy="9.5" r="2"/>';
const _flowerFilled =
    '<path fill="black" fill-rule="evenodd" stroke="none" d="M12 14c-2.5 2-5.5.5-5-2.3C3.5 11 4 7.5 7 7c-.5-3 3-4.5 5-2 2-2.5 5.5-1 5 2 3 .5 3.5 4 0 4.7.5 2.8-2.5 4.3-5 2.3ZM12 7.5a2 2 0 1 0 0 4 2 2 0 0 0 0-4Z"/><path d="M12 15v7m0-3c-3 0-5-1-5-3m5 5c3 0 5-1 5-3"/>';
const _close = '<path d="m4 4 16 16M20 4 4 20"/>';
const _check = '<path d="m4 12 5 5L20 6"/>';
const _circle = '<circle cx="12" cy="12" r="9.5"/>';
const _checkCircle = '$_circle<path d="m7 12 3.3 3.3L17 8.5"/>';
const _checkCircleFilled =
    '<path fill="black" stroke="none" fill-rule="evenodd" d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm-5.7 9.7 1.4-1.4 2.6 2.6L16.3 7l1.4 1.4-7.4 7.3Z"/>';
const _down = '<path d="m6 9 6 6 6-6"/>';
const _back = '<path d="m15 3-9 9 9 9"/>';
const _forward = '<path d="m9 3 9 9-9 9"/>';
const _plus = '<path d="M12 4v16M4 12h16"/>';
const _send = '<path d="m22 2-7 20-5-9-9-5ZM10 13 22 2"/>';
const _photo =
    '<rect x="2.5" y="2.5" width="19" height="19" rx="3"/><circle cx="8" cy="8" r="1.5"/><path d="m3 17 5-5 4 4 4-6 5 7"/>';
const _video =
    '<rect x="2" y="5" width="13" height="14" rx="3"/><path d="m15 10 7-5v14l-7-5"/>';
const _slash = '<path d="m3 3 18 18"/>';
const _phone =
    '<path d="M6 2.5H3.5c-.8 0-1 .6-1 1.4C2.5 13.5 10.5 21.5 20.1 21.5c.8 0 1.4-.2 1.4-1V18l-5-3-2.5 2c-3.4-1.5-5.5-3.6-7-7L9 7.5Z"/>';
const _hangup =
    '<path d="M2 15v-3c5-6 15-6 20 0v3l-5 1-1-4a14 14 0 0 0-8 0l-1 4Z"/>';
const _mic =
    '<rect x="9" y="2" width="6" height="13" rx="3"/><path d="M5.5 10v2a6.5 6.5 0 0 0 13 0v-2M12 18.5V22M9 22h6"/>';
const _eye =
    '<path d="M2 12c5-9 15-9 20 0-5 9-15 9-20 0Z"/><circle cx="12" cy="12" r="3"/>';
const _calendar =
    '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M7 2v6m10-6v6M3 10h18M7 14h2m6 0h2m-10 4h2m6 0h2"/>';
const _clock = '$_circle<path d="M12 6v6l4 2"/>';
const _download = '<path d="M12 3v13m-5-5 5 5 5-5M4 19v3h16v-3"/>';
const _refresh =
    '<path d="M20 8a8.5 8.5 0 0 0-15-2L2 9m0-6v6h6m-4 7a8.5 8.5 0 0 0 15 2l3-3m-6 0h6v6"/>';
const _warning =
    '<path d="m12 2 10 19H2ZM12 8v5"/><circle cx="12" cy="17" r=".9" fill="black" stroke="none"/>';
const _bolt = '<path d="m14 2-11 12h8l-1 8L21 9h-8Z"/>';
const _mail =
    '<rect x="2" y="4" width="20" height="16" rx="3"/><path d="m3 6 9 7 9-7"/>';
const _arrowDown = '<path d="M12 3v18m-7-7 7 7 7-7"/>';
const _arrowUp = '<path d="M12 21V3M5 10l7-7 7 7"/>';

final _selected = <IconData, String>{
  CupertinoIcons.house_fill: _homeFilled,
  Icons.local_florist_rounded: _flowerFilled,
  CupertinoIcons.camera_fill: _cameraFilled,
  CupertinoIcons.gift_fill: _giftFilled,
  CupertinoIcons.square_grid_2x2_fill: '<g fill="black">$_grid</g>',
};

final _artwork = <IconData, String>{
  CupertinoIcons.house_fill: _home,
  Icons.local_florist_rounded: _flower,
  CupertinoIcons.camera: _camera,
  CupertinoIcons.camera_fill: _camera,
  CupertinoIcons.gift: _gift,
  CupertinoIcons.gift_fill: _gift,
  CupertinoIcons.square_grid_2x2_fill: _grid,
  CupertinoIcons.heart: _heart,
  CupertinoIcons.heart_fill: _heartFilled,
  Icons.favorite_rounded: _heartFilled,
  CupertinoIcons.xmark: _close,
  Icons.close: _close,
  CupertinoIcons.xmark_circle: '$_circle<path d="m8 8 8 8m0-8-8 8"/>',
  // clear_circled is an alias of xmark_circle and shares this artwork.
  CupertinoIcons.add: _plus,
  CupertinoIcons.add_circled: '$_circle<path d="M12 7v10M7 12h10"/>',
  CupertinoIcons.circle: _circle,
  Icons.circle: '<circle cx="12" cy="12" r="10" fill="black"/>',
  CupertinoIcons.checkmark_alt: _check,
  Icons.done_rounded: _check,
  Icons.done_all_rounded: '<path d="m1 12 5 5L17 6m-6 11L22 6"/>',
  CupertinoIcons.checkmark_alt_circle: _checkCircle,
  CupertinoIcons.checkmark_alt_circle_fill: _checkCircleFilled,
  CupertinoIcons.checkmark_seal: _checkCircle,
  CupertinoIcons.checkmark_seal_fill: _checkCircleFilled,
  CupertinoIcons.chevron_back: _back,
  CupertinoIcons.chevron_left: _back,
  CupertinoIcons.chevron_forward: _forward,
  CupertinoIcons.chevron_right: _forward,
  CupertinoIcons.chevron_down: _down,
  CupertinoIcons.paperplane: _send,
  CupertinoIcons.paperplane_fill: _send,
  CupertinoIcons.photo: _photo,
  CupertinoIcons.photo_fill: _photo,
  CupertinoIcons.photo_on_rectangle:
      '<rect x="7" y="2" width="15" height="15" rx="2"/><path d="M3 7H2v15h15v-1m-9-9 4-4 4 4 2-2 3 3"/><circle cx="17" cy="6" r="1"/>',
  CupertinoIcons.video_camera: _video,
  CupertinoIcons.video_camera_solid: _video,
  Icons.videocam_off_rounded: '$_video$_slash',
  CupertinoIcons.phone: _phone,
  CupertinoIcons.phone_fill: _phone,
  CupertinoIcons.phone_down: _hangup,
  CupertinoIcons.phone_down_fill: _hangup,
  CupertinoIcons.mic_fill: _mic,
  CupertinoIcons.mic_slash_fill: '$_mic$_slash',
  CupertinoIcons.eye: _eye,
  CupertinoIcons.eye_fill: _eye,
  CupertinoIcons.eye_slash: '$_eye$_slash',
  CupertinoIcons.eye_slash_fill: '$_eye$_slash',
  CupertinoIcons.calendar: _calendar,
  Icons.calendar_today_rounded: _calendar,
  CupertinoIcons.clock: _clock,
  CupertinoIcons.arrow_down_to_line: _download,
  CupertinoIcons.arrow_down: _arrowDown,
  CupertinoIcons.arrow_up: _arrowUp,
  CupertinoIcons.arrow_down_circle: '$_circle<path d="M12 6v12m-4-4 4 4 4-4"/>',
  CupertinoIcons.arrow_down_left: '<path d="M20 4 4 20M4 8v12h12"/>',
  CupertinoIcons.arrow_up_right: '<path d="M4 20 20 4M8 4h12v12"/>',
  CupertinoIcons.arrow_right_arrow_left:
      '<path d="M3 7h18m-5-5 5 5-5 5M21 17H3m5-5-5 5 5 5"/>',
  CupertinoIcons.arrow_2_circlepath: _refresh,
  CupertinoIcons.arrow_clockwise:
      '<path d="M21 10A9 9 0 1 0 20 17M21 3v7h-7"/>',
  CupertinoIcons.camera_rotate_fill: '$_refresh<circle cx="12" cy="12" r="3"/>',
  CupertinoIcons.repeat:
      '<path d="M3 10V6h18l-4-4m4 4-4 4M21 14v4H3l4 4m-4-4 4-4"/>',
  CupertinoIcons.exclamationmark_triangle: _warning,
  CupertinoIcons.exclamationmark_triangle_fill: _warning,
  CupertinoIcons.bolt_fill: _bolt,
  CupertinoIcons.bolt_slash: '$_bolt$_slash',
  CupertinoIcons.mail: _mail,
  Icons.mail_rounded: _mail,
  Icons.drafts_rounded:
      '<path d="m2 9 10-7 10 7v12H2Zm0 0 10 7 10-7M2 21l7-7m6 0 7 7"/>',
  CupertinoIcons.search:
      '<circle cx="10.5" cy="10.5" r="8"/><path d="m16.5 16.5 5 5"/>',
  CupertinoIcons.pencil: '<path d="m3 16-1 6 6-1L21 8l-5-5Zm10-10 5 5"/>',
  CupertinoIcons.person:
      '<circle cx="12" cy="7" r="4"/><path d="M3 22v-2a9 7 0 0 1 18 0v2Z"/>',
  CupertinoIcons.smiley:
      '$_circle<path d="M7 14c2 4 8 4 10 0"/><circle cx="8" cy="9" r=".8" fill="black"/><circle cx="16" cy="9" r=".8" fill="black"/>',
  CupertinoIcons.delete:
      '<path d="M3 6h18M9 6V3h6v3M5 6l1 16h12l1-16M10 10v7m4-7v7"/>',
  CupertinoIcons.device_phone_portrait:
      '<rect x="6" y="2" width="12" height="20" rx="2"/><path d="M10 5h4m-3 14h2"/>',
  CupertinoIcons.lock:
      '<rect x="4" y="10" width="16" height="12" rx="2"/><path d="M7 10V7a5 5 0 0 1 10 0v3m-5 5v3"/>',
  CupertinoIcons.bell_fill:
      '<path d="M5 9a7 7 0 0 1 14 0v6l2 3H3l2-3Zm4 12h6"/>',
  // Two speech bubbles, the front one overlapping the back. Drawn here
  // rather than taken from Cupertino so the stroke matches the rest of the
  // bar: the stock glyph is a filled pair and would read heavier than the
  // four outlines beside it.
  CupertinoIcons.chat_bubble_2:
      '<path d="M16.6 9.2V6.4A2.4 2.4 0 0 0 14.2 4H5.4A2.4 2.4 0 0 0 3 6.4v5.2a2.4 2.4 0 0 0 2.4 2.4h1.3"/>'
      '<path d="M21 11.8a2.4 2.4 0 0 0-2.4-2.4H9.8a2.4 2.4 0 0 0-2.4 2.4V17a2.4 2.4 0 0 0 2.4 2.4h1.4L14 21.6V19.4h4.6A2.4 2.4 0 0 0 21 17Z"/>',
  // Two lives overlapping. Circles rather than people or a heart: the ring
  // pair says "both of us, sharing the middle" without drawing anybody.
  Icons.join_full:
      '<circle cx="9.4" cy="12" r="5.8"/><circle cx="14.6" cy="12" r="5.8"/>',
  CupertinoIcons.book:
      '<path d="M12 5C9 2 5 2 2 3v17c3-1 7-1 10 1 3-2 7-2 10-1V3c-3-1-7-1-10 2Zm0 0v16"/>',
  CupertinoIcons.share: '<path d="M12 16V2m-5 5 5-5 5 5M7 10H3v12h18V10h-4"/>',
  CupertinoIcons.reply:
      '<path d="m10 3-8 7 8 7v-5c6 0 9 3 12 8 0-9-4-13-12-13Z"/>',
  CupertinoIcons.equal: '<path d="M4 8h16M4 16h16"/>',
  CupertinoIcons.star_fill:
      '<path d="m12 2 3 6.5 7 .9-5 5 1.2 7-6.2-3.3-6.2 3.3 1.2-7-5-5 7-.9Z"/>',
  CupertinoIcons.airplane:
      '<path d="m22 2-5 20-5-8-10-4Zm0 0L12 14l-2 6-3-3 3-4"/>',
  CupertinoIcons.tag:
      '<path d="M3 3h9l10 10-9 9L3 12Z"/><circle cx="8" cy="8" r="1"/>',
  CupertinoIcons.keyboard:
      '<rect x="2" y="5" width="20" height="14" rx="2"/><path d="M6 9h1m4 0h1m4 0h1M6 12h1m4 0h1m4 0h1M7 16h10"/>',
  CupertinoIcons.gear_alt_fill:
      '<path d="m9 2-.5 3-2 .9L4 4.5 2 8l2.5 2v3L2 15l2 3.5 2.5-1.4 2 .9.5 4h6l.5-4 2-.9 2.5 1.4 2-3.5-2.5-2v-3L22 8l-2-3.5L17.5 6l-2-1L15 2Z"/><circle cx="12" cy="12" r="3"/>',
};
