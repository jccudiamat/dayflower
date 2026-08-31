import 'dart:math' show pi;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/ios_back_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand
// ─────────────────────────────────────────────────────────────────────────────
const _rose = Color(0xFFD64270);
const _roseDark = Color(0xFF8B2040);
const _blush = Color(0xFFFFF0F3);
const _charcoal = Color(0xFF2C2438);
const _grey = Color(0xFF6B7280);
const _sage = Color(0xFF3D7A60);
const _screenBg = Color(0xFFF2EDF6);

// ─────────────────────────────────────────────────────────────────────────────
// Templates
// ─────────────────────────────────────────────────────────────────────────────

enum _TplId {
  classic,
  filmStrip,
  scrapbook,
  neonBooth,
  splitFrame,
  locket,
  vintage,
  soloPortrait,
  soloFilm,
  soloAesthetic,
}

class _Tpl {
  const _Tpl({
    required this.id,
    required this.name,
    required this.tagline,
    required this.isDuo,
    required this.accent,
    required this.bg,
    required this.icon,
  });
  final _TplId id;
  final String name, tagline, icon;
  final bool isDuo;
  final Color accent, bg;
}

const _kTpls = <_Tpl>[
  _Tpl(
      id: _TplId.classic,
      name: 'Classic Polaroid',
      tagline: 'The timeless OG',
      isDuo: true,
      accent: Color(0xFFD64270),
      bg: Color(0xFFFFFEF8),
      icon: '🖼️'),
  _Tpl(
      id: _TplId.filmStrip,
      name: 'Film Strip',
      tagline: 'Cinematic moments',
      isDuo: true,
      accent: Color(0xFFD4A017),
      bg: Color(0xFF1C1C1E),
      icon: '🎞️'),
  _Tpl(
      id: _TplId.scrapbook,
      name: 'Scrapbook',
      tagline: 'Cut, paste & love',
      isDuo: true,
      accent: Color(0xFF4CAF82),
      bg: Color(0xFFFBF6EE),
      icon: '✂️'),
  _Tpl(
      id: _TplId.neonBooth,
      name: 'Neon Booth',
      tagline: 'Night vibes only',
      isDuo: true,
      accent: Color(0xFF8B5CF6),
      bg: Color(0xFF0E0720),
      icon: '🌈'),
  _Tpl(
      id: _TplId.splitFrame,
      name: 'Split Frame',
      tagline: 'Two worlds, one shot',
      isDuo: true,
      accent: Color(0xFFE8922A),
      bg: Color(0xFFF5F5F5),
      icon: '⚡'),
  _Tpl(
      id: _TplId.locket,
      name: 'Locket',
      tagline: 'Close to my heart',
      isDuo: true,
      accent: Color(0xFFE85D9A),
      bg: Color(0xFFFFF0F8),
      icon: '💞'),
  _Tpl(
      id: _TplId.vintage,
      name: 'Vintage',
      tagline: 'Old souls, new love',
      isDuo: true,
      accent: Color(0xFF8B6914),
      bg: Color(0xFFF5EED9),
      icon: '🍂'),
  _Tpl(
      id: _TplId.soloPortrait,
      name: 'Solo Portrait',
      tagline: 'The main character',
      isDuo: false,
      accent: Color(0xFF6B5CE7),
      bg: Color(0xFFFFFEF8),
      icon: '🌟'),
  _Tpl(
      id: _TplId.soloFilm,
      name: 'Solo Film',
      tagline: 'Triple feature',
      isDuo: false,
      accent: Color(0xFF374151),
      bg: Color(0xFF111827),
      icon: '🎬'),
  _Tpl(
      id: _TplId.soloAesthetic,
      name: 'Aesthetic',
      tagline: 'Soft & minimal',
      isDuo: false,
      accent: Color(0xFF9B7DB0),
      bg: Color(0xFFF9F5FF),
      icon: '🌸'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Frame sizes + dimensions
// ─────────────────────────────────────────────────────────────────────────────

enum _FSize { hero, grid, thumb, preview }

class _Dims {
  const _Dims(
      this.w, this.photoH, this.captionH, this.pad, this.emojiSz, this.labelSz);
  final double w, photoH, captionH, pad, emojiSz, labelSz;
  double get innerW => w - pad * 2;
  double get halfW => (innerW - 4) / 2;
}

_Dims _dims(_FSize s) => switch (s) {
      _FSize.hero => const _Dims(276, 200, 56, 12, 52, 14),
      _FSize.grid => const _Dims(160, 114, 44, 8, 30, 10),
      _FSize.thumb => const _Dims(100, 70, 28, 5, 22, 8),
      _FSize.preview => const _Dims(120, 88, 30, 7, 26, 9),
    };

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _PairData {
  const _PairData({
    required this.id,
    required this.label,
    required this.date,
    this.rotate = 0,
    this.offsetX = 0,
    this.offsetY = 0,
    required this.leftEmoji,
    required this.rightEmoji,
    required this.leftBg,
    required this.rightBg,
    this.isNew = false,
    this.tplId = _TplId.classic,
  });
  final int id;
  final String label, date, leftEmoji, rightEmoji;
  final double rotate, offsetX, offsetY;
  final Color leftBg, rightBg;
  final bool isNew;
  final _TplId tplId;
}

// ─────────────────────────────────────────────────────────────────────────────
// Mock data
// ─────────────────────────────────────────────────────────────────────────────

const _myPet = 'Bunny';
const _herPet = 'Sunshine';

const _kCurrent = _PairData(
  id: 0,
  label: 'today, missing you',
  date: 'Apr 20',
  leftEmoji: '🌷',
  rightEmoji: '😘',
  leftBg: Color(0xFFFDE8E0),
  rightBg: Color(0xFFE8F0FD),
  isNew: true,
);

const _kPast = <_PairData>[
  _PairData(
      id: 4,
      label: 'our first video call',
      date: 'Nov 3',
      rotate: -6,
      offsetX: -18,
      offsetY: 8,
      leftEmoji: '🤳',
      rightEmoji: '😊',
      leftBg: Color(0xFFFDE8E0),
      rightBg: Color(0xFFE0F0E8)),
  _PairData(
      id: 3,
      label: 'when it started raining',
      date: 'Jan 18',
      rotate: 4,
      offsetX: 10,
      offsetY: 5,
      leftEmoji: '😄',
      rightEmoji: '🥰',
      leftBg: Color(0xFFFDE8D0),
      rightBg: Color(0xFFE8E0FD),
      tplId: _TplId.filmStrip),
  _PairData(
      id: 2,
      label: 'the airport goodbye',
      date: 'Mar 2',
      rotate: -3,
      offsetX: -8,
      offsetY: 3,
      leftEmoji: '😢',
      rightEmoji: '🤗',
      leftBg: Color(0xFFE8F0FD),
      rightBg: Color(0xFFFDE8E8),
      tplId: _TplId.scrapbook),
  _PairData(
      id: 1,
      label: 'missing you tonight',
      date: 'Apr 14',
      rotate: 2,
      offsetX: 6,
      offsetY: 2,
      leftEmoji: '🌙',
      rightEmoji: '💭',
      leftBg: Color(0xFFF0E8FD),
      rightBg: Color(0xFFFDF0E8),
      tplId: _TplId.neonBooth),
];

_PairData _mkPreview(_TplId id) => _PairData(
      id: -1,
      label: 'our moment',
      date: 'Today',
      leftEmoji: '🌷',
      rightEmoji: '💕',
      leftBg: const Color(0xFFFDE8E0),
      rightBg: const Color(0xFFE8EDFD),
      tplId: id,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class BoothScreen extends StatefulWidget {
  const BoothScreen({super.key});
  @override
  State<BoothScreen> createState() => _BoothScreenState();
}

class _BoothScreenState extends State<BoothScreen> {
  String _view = 'stack'; // 'stack' | 'picker' | 'upload'
  _Tpl? _picked;
  late List<_PairData> _pairs;

  @override
  void initState() {
    super.initState();
    _pairs = [_kCurrent, ..._kPast];
  }

  void _generate(String caption) {
    final tpl = _picked!;
    setState(() {
      _pairs = [
        _PairData(
          id: DateTime.now().millisecondsSinceEpoch,
          label: caption.isEmpty ? 'our moment' : caption,
          date: 'Apr 29',
          leftEmoji: '🤳',
          rightEmoji: tpl.isDuo ? '🥰' : '🤳',
          leftBg: const Color(0xFFFFF0E8),
          rightBg: const Color(0xFFE8F8FF),
          isNew: true,
          tplId: tpl.id,
        ),
        ..._pairs,
      ];
      _view = 'stack';
      _picked = null;
    });
  }

  void _showDetail(_PairData item) => showDialog(
        context: context,
        barrierColor: Colors.transparent,
        builder: (_) => _DetailModal(item: item),
      );

  void _back() => setState(() {
        _view = (_view == 'upload') ? 'picker' : 'stack';
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Row(
                children: [
                  // The booth is a sub-route of the Activities hub now, so it
                  // needs its own way back out.
                  IosBackButton(
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go(Routes.activities),
                  ),
                  const SizedBox(width: 12),
                  // Expanded, not a bare Column + Spacer: the back button ate
                  // 52px of a row that was already sized to the pet names, and
                  // a long pair of names overflows without this.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Strip',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F0A14),
                                height: 1.1)),
                        Text(
                          '$_myPet & $_herPet · ${_pairs.length} pair${_pairs.length > 1 ? "s" : ""}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _view == 'stack'
                        ? () => setState(() => _view = 'picker')
                        : _back,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: _view == 'stack'
                            ? const LinearGradient(
                                colors: [_rose, _roseDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight)
                            : null,
                        color:
                            _view == 'stack' ? null : const Color(0xFFEDE8F0),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _view == 'stack'
                            ? [
                                BoxShadow(
                                    color: _rose.withValues(alpha: .38),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4))
                              ]
                            : null,
                      ),
                      child: Text(
                        _view == 'stack' ? '＋  New pair' : '← Back',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _view == 'stack' ? Colors.white : _grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position:
                        Tween(begin: const Offset(0.04, 0), end: Offset.zero)
                            .animate(anim),
                    child: child,
                  ),
                ),
                child: _view == 'stack'
                    ? _StackView(
                        key: const ValueKey('s'),
                        pairs: _pairs,
                        onViewDetail: _showDetail)
                    : _view == 'picker'
                        ? _TemplatePicker(
                            key: const ValueKey('p'),
                            onSelect: (t) => setState(() {
                              _picked = t;
                              _view = 'upload';
                            }),
                          )
                        : _UploadView(
                            key: const ValueKey('u'),
                            template: _picked!,
                            onGenerate: _generate,
                          ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stack view
// ─────────────────────────────────────────────────────────────────────────────

class _StackView extends StatefulWidget {
  const _StackView(
      {super.key, required this.pairs, required this.onViewDetail});
  final List<_PairData> pairs;
  final ValueChanged<_PairData> onViewDetail;
  @override
  State<_StackView> createState() => _StackViewState();
}

class _StackViewState extends State<_StackView> {
  int _topI = 0;

  @override
  Widget build(BuildContext context) {
    final all = widget.pairs;
    final shown = all[_topI];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
      child: Column(
        children: [
          _PolaroidStack(
            pairs: all,
            topI: _topI,
            onChangeTop: (i) => setState(() => _topI = i),
            onViewDetail: widget.onViewDetail,
          ),
          const SizedBox(height: 10),
          const Text(
            'Tap the polaroid to view full · tap thumbnails to flip through',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: _grey),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => widget.onViewDetail(shown),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF0ECF4)),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🔍 View latest',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _charcoal)),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_rose, _roseDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: _rose.withValues(alpha: .38),
                          blurRadius: 20,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text('💾 Save & share',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('ALL PAIRS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _grey,
                    letterSpacing: .8)),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemCount: all.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => widget.onViewDetail(all[i]),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: Transform.rotate(
                  angle: (i.isEven ? -1.5 : 1.5) * pi / 180,
                  child: _TemplateFrame(
                      pair: all[i], size: _FSize.grid, isNew: i == 0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Polaroid stack with thumbnails
// ─────────────────────────────────────────────────────────────────────────────

class _PolaroidStack extends StatelessWidget {
  const _PolaroidStack({
    required this.pairs,
    required this.topI,
    required this.onChangeTop,
    required this.onViewDetail,
  });
  final List<_PairData> pairs;
  final int topI;
  final ValueChanged<int> onChangeTop;
  final ValueChanged<_PairData> onViewDetail;

  static const _behind = [
    (-7.0, -22.0, 10.0),
    (5.0, 16.0, 8.0),
    (-3.0, -8.0, 14.0)
  ];

  @override
  Widget build(BuildContext context) {
    final all = pairs;
    final shown = all[topI];
    final behind =
        [...all.sublist(0, topI), ...all.sublist(topI + 1)].take(3).toList();

    return Column(
      children: [
        SizedBox(
          width: 276,
          height: 300,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (int i = 0; i < behind.length; i++)
                Positioned(
                  top: 12,
                  left: 0,
                  child: Transform(
                    transform: Matrix4.identity()
                      ..rotateZ(_behind[i].$1 * pi / 180)
                      ..translateByDouble(_behind[i].$2, _behind[i].$3, 0, 1),
                    child: Opacity(
                      opacity: (0.75 - i * 0.12).clamp(0.0, 1.0),
                      child: _TemplateFrame(pair: behind[i], size: _FSize.hero),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                child: GestureDetector(
                  onTap: () => onViewDetail(shown),
                  child: _TemplateFrame(
                      pair: shown, size: _FSize.hero, isNew: topI == 0),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 4),
            itemCount: all.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final active = topI == i;
              return GestureDetector(
                onTap: () => onChangeTop(i),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: active ? 1.0 : 0.55,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: active ? _rose : Colors.transparent, width: 2),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: active
                          ? [
                              const BoxShadow(
                                  color: _blush,
                                  blurRadius: 0,
                                  spreadRadius: 3),
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: .15),
                                  blurRadius: 16)
                            ]
                          : [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: .12),
                                  blurRadius: 8)
                            ],
                    ),
                    child: _TemplateFrame(
                      pair: all[i],
                      size: _FSize.thumb,
                      showNames: false,
                      overrideLabel: all[i].date,
                      hideDate: true,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          topI == 0
              ? 'Latest pair · ${all.length} total'
              : '${all.length - topI} pair${all.length - topI > 1 ? "s" : ""} ago · ${all.length} total',
          style: const TextStyle(fontSize: 11, color: _grey),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template frame dispatcher
// ─────────────────────────────────────────────────────────────────────────────

class _TemplateFrame extends StatelessWidget {
  const _TemplateFrame({
    required this.pair,
    required this.size,
    this.isNew = false,
    this.showNames = true,
    this.overrideLabel,
    this.hideDate = false,
  });
  final _PairData pair;
  final _FSize size;
  final bool isNew, showNames, hideDate;
  final String? overrideLabel;

  @override
  Widget build(BuildContext context) {
    Widget frame = switch (pair.tplId) {
      _TplId.classic => _ClassicFrame(
          pair: pair,
          size: size,
          showNames: showNames,
          overrideLabel: overrideLabel,
          hideDate: hideDate),
      _TplId.filmStrip => _FilmStripFrame(
          pair: pair,
          size: size,
          hideDate: hideDate,
          overrideLabel: overrideLabel),
      _TplId.scrapbook => _ScrapbookFrame(
          pair: pair,
          size: size,
          hideDate: hideDate,
          overrideLabel: overrideLabel),
      _TplId.neonBooth => _NeonBoothFrame(
          pair: pair,
          size: size,
          hideDate: hideDate,
          overrideLabel: overrideLabel),
      _TplId.splitFrame => _SplitFrame(
          pair: pair,
          size: size,
          hideDate: hideDate,
          overrideLabel: overrideLabel),
      _TplId.locket => _LocketFrame(
          pair: pair,
          size: size,
          hideDate: hideDate,
          overrideLabel: overrideLabel),
      _TplId.vintage => _VintageFrame(
          pair: pair,
          size: size,
          hideDate: hideDate,
          overrideLabel: overrideLabel),
      _TplId.soloPortrait => _SoloPortraitFrame(
          pair: pair,
          size: size,
          hideDate: hideDate,
          overrideLabel: overrideLabel),
      _TplId.soloFilm => _SoloFilmFrame(
          pair: pair,
          size: size,
          hideDate: hideDate,
          overrideLabel: overrideLabel),
      _TplId.soloAesthetic => _SoloAestheticFrame(
          pair: pair,
          size: size,
          hideDate: hideDate,
          overrideLabel: overrideLabel),
    };

    if (!isNew) return frame;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        frame,
        Positioned(
          top: -10,
          right: -10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _rose,
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(color: _rose.withValues(alpha: .33), blurRadius: 8)
              ],
            ),
            child: const Text('new',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: .8)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template 1 — Classic Polaroid
// ─────────────────────────────────────────────────────────────────────────────

class _ClassicFrame extends StatelessWidget {
  const _ClassicFrame(
      {required this.pair,
      required this.size,
      this.showNames = true,
      this.overrideLabel,
      this.hideDate = false});
  final _PairData pair;
  final _FSize size;
  final bool showNames, hideDate;
  final String? overrideLabel;

  @override
  Widget build(BuildContext context) {
    final d = _dims(size);
    return Container(
      width: d.w,
      decoration: const BoxDecoration(
        color: Color(0xFFFFFEF8),
        borderRadius: BorderRadius.all(Radius.circular(4)),
        boxShadow: [
          BoxShadow(
              color: Color(0x2E000000), blurRadius: 24, offset: Offset(0, 4)),
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 1))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(d.pad, d.pad, d.pad, 0),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: d.halfW,
              height: d.photoH,
              decoration: BoxDecoration(
                  color: pair.leftBg, borderRadius: BorderRadius.circular(2)),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(pair.leftEmoji, style: TextStyle(fontSize: d.emojiSz)),
                    if (showNames && size == _FSize.hero)
                      const Text(_myPet,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0x4D000000),
                              letterSpacing: .4)),
                  ]),
            ),
            const SizedBox(width: 4),
            Container(
              width: d.halfW,
              height: d.photoH,
              decoration: BoxDecoration(
                  color: pair.rightBg, borderRadius: BorderRadius.circular(2)),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(pair.rightEmoji,
                        style: TextStyle(fontSize: d.emojiSz)),
                    if (showNames && size == _FSize.hero)
                      const Text(_herPet,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0x4D000000),
                              letterSpacing: .4)),
                  ]),
            ),
          ]),
        ),
        SizedBox(
          height: d.captionH,
          width: d.w,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: d.pad),
              child: Text(overrideLabel ?? pair.label,
                  style: TextStyle(
                      fontSize: d.labelSz,
                      color: const Color(0xFF3A2A20),
                      letterSpacing: .3,
                      height: 1.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center),
            ),
            if (!hideDate)
              Text(pair.date,
                  style: const TextStyle(
                      fontSize: 9,
                      color: Color(0x40000000),
                      letterSpacing: .5)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template 2 — Film Strip
// ─────────────────────────────────────────────────────────────────────────────

class _FilmStripFrame extends StatelessWidget {
  const _FilmStripFrame(
      {required this.pair,
      required this.size,
      this.hideDate = false,
      this.overrideLabel});
  final _PairData pair;
  final _FSize size;
  final bool hideDate;
  final String? overrideLabel;

  @override
  Widget build(BuildContext context) {
    final d = _dims(size);
    const darkBg = Color(0xFF1A1A1A);
    final numCells = size == _FSize.hero || size == _FSize.preview ? 4 : 2;
    final perfW =
        size == _FSize.hero ? 14.0 : (size == _FSize.preview ? 10.0 : 8.0);
    final cellH = (d.photoH - (numCells - 1) * 2.0) / numCells;
    final cellW = d.w - perfW * 2;

    return Container(
      width: d.w,
      decoration: BoxDecoration(
          color: darkBg,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .4),
                blurRadius: 18,
                offset: const Offset(0, 6))
          ]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Brand header
        SizedBox(
          height: d.pad,
          child: Center(
              child: Text('KODAK 400',
                  style: TextStyle(
                      fontSize: d.labelSz * 0.6,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFD4A017),
                      letterSpacing: 1.5))),
        ),
        // Perforated photo area
        SizedBox(
          height: d.photoH,
          child: Row(children: [
            _Perfs(
                height: d.photoH,
                width: perfW,
                cellH: cellH,
                numCells: numCells),
            SizedBox(
              width: cellW,
              child: Column(
                children: List.generate(
                    numCells,
                    (i) => Container(
                          width: cellW,
                          height: cellH,
                          margin: i > 0
                              ? const EdgeInsets.only(top: 2)
                              : EdgeInsets.zero,
                          decoration: BoxDecoration(
                            color: i.isEven ? pair.leftBg : pair.rightBg,
                            borderRadius: BorderRadius.circular(1),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            i.isEven ? pair.leftEmoji : pair.rightEmoji,
                            style: TextStyle(
                                fontSize: d.emojiSz * (i == 0 ? 1.0 : 0.85)),
                          ),
                        )),
              ),
            ),
            _Perfs(
                height: d.photoH,
                width: perfW,
                cellH: cellH,
                numCells: numCells),
          ]),
        ),
        // Caption
        SizedBox(
          height: d.captionH,
          width: d.w,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(overrideLabel ?? pair.label,
                style: TextStyle(
                    fontSize: d.labelSz,
                    color: const Color(0xFFE8D8A0),
                    letterSpacing: .5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            if (!hideDate)
              Text(pair.date,
                  style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF6B6040),
                      letterSpacing: .5)),
          ]),
        ),
      ]),
    );
  }
}

class _Perfs extends StatelessWidget {
  const _Perfs(
      {required this.height,
      required this.width,
      required this.cellH,
      required this.numCells});
  final double height, width, cellH;
  final int numCells;

  @override
  Widget build(BuildContext context) {
    final count = (height / (width + 3)).floor().clamp(4, 14);
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF1A1A1A),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
            count,
            (_) => Container(
                  width: width * 0.55,
                  height: width * 0.55,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A0A),
                    borderRadius: BorderRadius.circular(1.5),
                    border:
                        Border.all(color: const Color(0xFF3A3A3A), width: .5),
                  ),
                )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template 3 — Scrapbook
// ─────────────────────────────────────────────────────────────────────────────

class _ScrapbookFrame extends StatelessWidget {
  const _ScrapbookFrame(
      {required this.pair,
      required this.size,
      this.hideDate = false,
      this.overrideLabel});
  final _PairData pair;
  final _FSize size;
  final bool hideDate;
  final String? overrideLabel;

  static const _tapeColors = [
    Color(0xFFFFC0CB),
    Color(0xFFB5EAD7),
    Color(0xFFFFDAB9),
    Color(0xFFC9D8E8)
  ];
  static const _rotations = [-2.0, 2.5, -1.5, 3.0];

  @override
  Widget build(BuildContext context) {
    final d = _dims(size);
    final cellW = (d.innerW - 4) / 2;
    final cellH = (d.photoH - 4) / 2;

    return Container(
      width: d.w,
      decoration: BoxDecoration(
        color: const Color(0xFFFBF6EE),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .12),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      padding: EdgeInsets.fromLTRB(d.pad, d.pad, d.pad, 0),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: d.innerW,
          height: d.photoH,
          child: Stack(children: [
            Positioned.fill(
                child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: cellW / cellH,
              children: [
                for (int i = 0; i < 4; i++)
                  Transform.rotate(
                    angle: _rotations[i] * pi / 180,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(
                        decoration: BoxDecoration(
                          color: i.isEven ? pair.leftBg : pair.rightBg,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(i.isEven ? pair.leftEmoji : pair.rightEmoji,
                            style: TextStyle(fontSize: d.emojiSz * 0.7)),
                      ),
                      // Tape corner
                      Positioned(
                        top: -4,
                        left: i.isEven ? 10 : null,
                        right: i.isEven ? null : 10,
                        child: Transform.rotate(
                          angle: (i.isEven ? -20 : 20) * pi / 180,
                          child: Container(
                            width: cellW * 0.35,
                            height: 6,
                            color: _tapeColors[i].withValues(alpha: .75),
                          ),
                        ),
                      ),
                    ]),
                  ),
              ],
            )),
          ]),
        ),
        SizedBox(
          height: d.captionH,
          width: d.w,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(overrideLabel ?? pair.label,
                style: TextStyle(
                    fontSize: d.labelSz,
                    color: const Color(0xFF4A3728),
                    fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            if (!hideDate)
              Text(pair.date,
                  style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF8B7355),
                      letterSpacing: .5)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template 4 — Neon Booth
// ─────────────────────────────────────────────────────────────────────────────

class _NeonBoothFrame extends StatelessWidget {
  const _NeonBoothFrame(
      {required this.pair,
      required this.size,
      this.hideDate = false,
      this.overrideLabel});
  final _PairData pair;
  final _FSize size;
  final bool hideDate;
  final String? overrideLabel;

  @override
  Widget build(BuildContext context) {
    final d = _dims(size);
    final r = d.halfW / 2;

    return Container(
      width: d.w,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E0720), Color(0xFF1A0A30)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: .35),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      padding: EdgeInsets.fromLTRB(d.pad, d.pad, d.pad, 0),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // "PHOTO BOOTH" label
        if (size == _FSize.hero || size == _FSize.preview)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('✦ PHOTO BOOTH ✦',
                style: TextStyle(
                    fontSize: d.labelSz * 0.7,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF8B5CF6),
                    letterSpacing: 2)),
          ),
        Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NeonCircle(
                  emoji: pair.leftEmoji,
                  bg: pair.leftBg,
                  r: r,
                  emojiSz: d.emojiSz,
                  glowColor: const Color(0xFFFF6EC7)),
              SizedBox(width: d.pad),
              _NeonCircle(
                  emoji: pair.rightEmoji,
                  bg: pair.rightBg,
                  r: r,
                  emojiSz: d.emojiSz,
                  glowColor: const Color(0xFF00E5FF)),
            ]),
        SizedBox(
          height: d.captionH,
          width: d.w,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(overrideLabel ?? pair.label,
                style: TextStyle(
                    fontSize: d.labelSz,
                    color: Colors.white,
                    letterSpacing: .5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            if (!hideDate)
              Text(pair.date,
                  style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF6B5CE7),
                      letterSpacing: .5)),
          ]),
        ),
      ]),
    );
  }
}

class _NeonCircle extends StatelessWidget {
  const _NeonCircle(
      {required this.emoji,
      required this.bg,
      required this.r,
      required this.emojiSz,
      required this.glowColor});
  final String emoji;
  final Color bg, glowColor;
  final double r, emojiSz;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: r * 2,
      height: r * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        boxShadow: [
          BoxShadow(
              color: glowColor.withValues(alpha: .6),
              blurRadius: 16,
              spreadRadius: 2)
        ],
        border: Border.all(color: glowColor.withValues(alpha: .8), width: 2),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: TextStyle(fontSize: emojiSz)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template 5 — Split Frame
// ─────────────────────────────────────────────────────────────────────────────

class _LeftDiagClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..lineTo(s.width * 0.58, 0)
    ..lineTo(s.width * 0.42, s.height)
    ..lineTo(0, s.height)
    ..close();
  @override
  bool shouldReclip(_) => false;
}

class _RightDiagClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width * 0.58, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height)
    ..lineTo(s.width * 0.42, s.height)
    ..close();
  @override
  bool shouldReclip(_) => false;
}

class _SplitFrame extends StatelessWidget {
  const _SplitFrame(
      {required this.pair,
      required this.size,
      this.hideDate = false,
      this.overrideLabel});
  final _PairData pair;
  final _FSize size;
  final bool hideDate;
  final String? overrideLabel;

  @override
  Widget build(BuildContext context) {
    final d = _dims(size);
    return Container(
      width: d.w,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .12),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Split photo area
        SizedBox(
          width: d.w,
          height: d.photoH,
          child: Stack(children: [
            ClipPath(
              clipper: _LeftDiagClipper(),
              child: Container(
                  color: pair.leftBg,
                  width: d.w,
                  height: d.photoH,
                  alignment: const Alignment(-0.5, 0),
                  child: Text(pair.leftEmoji,
                      style: TextStyle(fontSize: d.emojiSz))),
            ),
            ClipPath(
              clipper: _RightDiagClipper(),
              child: Container(
                  color: pair.rightBg,
                  width: d.w,
                  height: d.photoH,
                  alignment: const Alignment(0.5, 0),
                  child: Text(pair.rightEmoji,
                      style: TextStyle(fontSize: d.emojiSz))),
            ),
            // Diagonal accent line
            Positioned.fill(child: CustomPaint(painter: _DiagLinePainter())),
          ]),
        ),
        // Caption
        Container(
          height: d.captionH,
          width: d.w,
          color: Colors.white,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(overrideLabel ?? pair.label,
                style: TextStyle(
                    fontSize: d.labelSz, color: const Color(0xFF2A2A2A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            if (!hideDate)
              Text(pair.date,
                  style:
                      const TextStyle(fontSize: 9, color: Color(0xFF9B8CAA))),
          ]),
        ),
      ]),
    );
  }
}

class _DiagLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width * 0.58, 0),
      Offset(size.width * 0.42, size.height),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Template 6 — Locket
// ─────────────────────────────────────────────────────────────────────────────

class _LocketFrame extends StatelessWidget {
  const _LocketFrame(
      {required this.pair,
      required this.size,
      this.hideDate = false,
      this.overrideLabel});
  final _PairData pair;
  final _FSize size;
  final bool hideDate;
  final String? overrideLabel;

  @override
  Widget build(BuildContext context) {
    final d = _dims(size);
    final ovalW = d.halfW * 0.95;
    final ovalH = d.photoH * 0.85;

    return Container(
      width: d.w,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB8D4), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFE85D9A).withValues(alpha: .18),
              blurRadius: 20,
              offset: const Offset(0, 6))
        ],
      ),
      padding: EdgeInsets.fromLTRB(d.pad, d.pad, d.pad, 0),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: d.photoH,
          width: d.innerW,
          child: Stack(alignment: Alignment.center, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _OvalPhoto(
                  emoji: pair.leftEmoji,
                  bg: pair.leftBg,
                  w: ovalW,
                  h: ovalH,
                  emojiSz: d.emojiSz),
              _OvalPhoto(
                  emoji: pair.rightEmoji,
                  bg: pair.rightBg,
                  w: ovalW,
                  h: ovalH,
                  emojiSz: d.emojiSz),
            ]),
            if (size == _FSize.hero || size == _FSize.preview)
              Text('💗', style: TextStyle(fontSize: d.emojiSz * 0.55)),
          ]),
        ),
        SizedBox(
          height: d.captionH,
          width: d.w,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(overrideLabel ?? pair.label,
                style: TextStyle(
                    fontSize: d.labelSz,
                    color: const Color(0xFF8B2060),
                    fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            if (!hideDate)
              Text(pair.date,
                  style:
                      const TextStyle(fontSize: 9, color: Color(0xFFE085A8))),
          ]),
        ),
      ]),
    );
  }
}

class _OvalPhoto extends StatelessWidget {
  const _OvalPhoto(
      {required this.emoji,
      required this.bg,
      required this.w,
      required this.h,
      required this.emojiSz});
  final String emoji;
  final Color bg;
  final double w, h, emojiSz;

  @override
  Widget build(BuildContext context) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFB8D4), width: 2),
        ),
        alignment: Alignment.center,
        child: Text(emoji, style: TextStyle(fontSize: emojiSz)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Template 7 — Vintage
// ─────────────────────────────────────────────────────────────────────────────

class _VintageFrame extends StatelessWidget {
  const _VintageFrame(
      {required this.pair,
      required this.size,
      this.hideDate = false,
      this.overrideLabel});
  final _PairData pair;
  final _FSize size;
  final bool hideDate;
  final String? overrideLabel;

  @override
  Widget build(BuildContext context) {
    final d = _dims(size);
    final borderW = d.pad * 0.6;

    return Container(
      width: d.w,
      decoration: BoxDecoration(
        color: const Color(0xFFF5EED9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFB8960C), width: borderW),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .18),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Corner ornaments + photos
        Stack(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(d.pad, d.pad, d.pad, 0),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  0.393,
                  0.769,
                  0.189,
                  0,
                  0,
                  0.349,
                  0.686,
                  0.168,
                  0,
                  0,
                  0.272,
                  0.534,
                  0.131,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: Container(
                  width: d.halfW,
                  height: d.photoH,
                  decoration: BoxDecoration(
                      color: pair.leftBg,
                      borderRadius: BorderRadius.circular(2)),
                  alignment: Alignment.center,
                  child: Text(pair.leftEmoji,
                      style: TextStyle(fontSize: d.emojiSz)),
                ),
              ),
              const SizedBox(width: 4),
              ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  0.393,
                  0.769,
                  0.189,
                  0,
                  0,
                  0.349,
                  0.686,
                  0.168,
                  0,
                  0,
                  0.272,
                  0.534,
                  0.131,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: Container(
                  width: d.halfW,
                  height: d.photoH,
                  decoration: BoxDecoration(
                      color: pair.rightBg,
                      borderRadius: BorderRadius.circular(2)),
                  alignment: Alignment.center,
                  child: Text(pair.rightEmoji,
                      style: TextStyle(fontSize: d.emojiSz)),
                ),
              ),
            ]),
          ),
          // Corner ornaments
          Positioned(
              top: 2,
              left: 2,
              child: Text('✦',
                  style: TextStyle(
                      fontSize: d.labelSz * 0.7,
                      color: const Color(0xFFB8960C)))),
          Positioned(
              top: 2,
              right: 2,
              child: Text('✦',
                  style: TextStyle(
                      fontSize: d.labelSz * 0.7,
                      color: const Color(0xFFB8960C)))),
          Positioned(
              bottom: 2,
              left: 2,
              child: Text('✦',
                  style: TextStyle(
                      fontSize: d.labelSz * 0.7,
                      color: const Color(0xFFB8960C)))),
          Positioned(
              bottom: 2,
              right: 2,
              child: Text('✦',
                  style: TextStyle(
                      fontSize: d.labelSz * 0.7,
                      color: const Color(0xFFB8960C)))),
        ]),
        SizedBox(
          height: d.captionH,
          width: d.w,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(overrideLabel ?? pair.label,
                style: TextStyle(
                    fontSize: d.labelSz,
                    color: const Color(0xFF5C3A00),
                    fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            if (!hideDate)
              Text(pair.date,
                  style:
                      const TextStyle(fontSize: 9, color: Color(0xFF8B6914))),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template 8 — Solo Portrait
// ─────────────────────────────────────────────────────────────────────────────

class _SoloPortraitFrame extends StatelessWidget {
  const _SoloPortraitFrame(
      {required this.pair,
      required this.size,
      this.hideDate = false,
      this.overrideLabel});
  final _PairData pair;
  final _FSize size;
  final bool hideDate;
  final String? overrideLabel;

  @override
  Widget build(BuildContext context) {
    final d = _dims(size);
    return Container(
      width: d.w,
      decoration: const BoxDecoration(
        color: Color(0xFFFFFEF8),
        borderRadius: BorderRadius.all(Radius.circular(4)),
        boxShadow: [
          BoxShadow(
              color: Color(0x2E000000), blurRadius: 24, offset: Offset(0, 4))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(d.pad, d.pad, d.pad, 0),
          child: Container(
            width: d.innerW,
            height: d.photoH * 1.15,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [pair.leftBg, pair.rightBg]),
              borderRadius: BorderRadius.circular(2),
            ),
            alignment: Alignment.center,
            child: Text(pair.leftEmoji,
                style: TextStyle(fontSize: d.emojiSz * 1.3)),
          ),
        ),
        SizedBox(
          height: d.captionH,
          width: d.w,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(overrideLabel ?? pair.label,
                style: TextStyle(
                    fontSize: d.labelSz,
                    color: const Color(0xFF3A2A20),
                    letterSpacing: .3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            if (!hideDate)
              Text(pair.date,
                  style:
                      const TextStyle(fontSize: 9, color: Color(0x40000000))),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template 9 — Solo Film
// ─────────────────────────────────────────────────────────────────────────────

class _SoloFilmFrame extends StatelessWidget {
  const _SoloFilmFrame(
      {required this.pair,
      required this.size,
      this.hideDate = false,
      this.overrideLabel});
  final _PairData pair;
  final _FSize size;
  final bool hideDate;
  final String? overrideLabel;

  @override
  Widget build(BuildContext context) {
    final d = _dims(size);
    const darkBg = Color(0xFF111827);
    const numCells = 3;
    final perfW = size == _FSize.hero ? 14.0 : 9.0;
    final cellH = (d.photoH - (numCells - 1) * 3.0) / numCells;
    final cellW = d.w - perfW * 2;

    return Container(
      width: d.w,
      decoration: BoxDecoration(
          color: darkBg,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .4),
                blurRadius: 18,
                offset: const Offset(0, 6))
          ]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: d.pad,
          child: Center(
              child: Text('SOLO FILM',
                  style: TextStyle(
                      fontSize: d.labelSz * 0.55,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF6B7280),
                      letterSpacing: 2))),
        ),
        SizedBox(
          height: d.photoH,
          child: Row(children: [
            _Perfs(
                height: d.photoH,
                width: perfW,
                cellH: cellH,
                numCells: numCells),
            SizedBox(
              width: cellW,
              child: Column(
                children: List.generate(
                    numCells,
                    (i) => Container(
                          width: cellW,
                          height: cellH,
                          margin: i > 0
                              ? const EdgeInsets.only(top: 3)
                              : EdgeInsets.zero,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  pair.leftBg,
                                  pair.rightBg.withValues(alpha: .6)
                                ]),
                            borderRadius: BorderRadius.circular(1),
                          ),
                          alignment: Alignment.center,
                          child: Text(pair.leftEmoji,
                              style: TextStyle(
                                  fontSize: d.emojiSz * (i == 1 ? 1.0 : 0.8))),
                        )),
              ),
            ),
            _Perfs(
                height: d.photoH,
                width: perfW,
                cellH: cellH,
                numCells: numCells),
          ]),
        ),
        SizedBox(
          height: d.captionH,
          width: d.w,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(overrideLabel ?? pair.label,
                style: TextStyle(
                    fontSize: d.labelSz, color: const Color(0xFFE8E8E8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            if (!hideDate)
              Text(pair.date,
                  style:
                      const TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template 10 — Solo Aesthetic
// ─────────────────────────────────────────────────────────────────────────────

class _SoloAestheticFrame extends StatelessWidget {
  const _SoloAestheticFrame(
      {required this.pair,
      required this.size,
      this.hideDate = false,
      this.overrideLabel});
  final _PairData pair;
  final _FSize size;
  final bool hideDate;
  final String? overrideLabel;

  @override
  Widget build(BuildContext context) {
    final d = _dims(size);
    return Container(
      width: d.w,
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0D4F5), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF9B7DB0).withValues(alpha: .15),
              blurRadius: 20,
              offset: const Offset(0, 6))
        ],
      ),
      padding: EdgeInsets.fromLTRB(d.pad, d.pad, d.pad, 0),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (size == _FSize.hero || size == _FSize.preview)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('🌸  aesthetic  🌸',
                style: TextStyle(
                    fontSize: d.labelSz * 0.7,
                    color: const Color(0xFFB49CC0),
                    letterSpacing: 1.5)),
          ),
        Container(
          width: d.innerW,
          height: d.photoH,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [pair.leftBg, const Color(0xFFF0E8FF)]),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 2),
          ),
          alignment: Alignment.center,
          child:
              Text(pair.leftEmoji, style: TextStyle(fontSize: d.emojiSz * 1.1)),
        ),
        SizedBox(
          height: d.captionH,
          width: d.w,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(overrideLabel ?? pair.label,
                style: TextStyle(
                    fontSize: d.labelSz,
                    color: const Color(0xFF6B4E8A),
                    fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
            if (!hideDate)
              Text(pair.date,
                  style:
                      const TextStyle(fontSize: 9, color: Color(0xFFB49CC0))),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail modal
// ─────────────────────────────────────────────────────────────────────────────

class _DetailModal extends StatelessWidget {
  const _DetailModal({required this.item});
  final _PairData item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: const Color(0xBF0F0A14),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Transform.scale(
                    scale: 1.08,
                    child: _TemplateFrame(pair: item, size: _FSize.hero)),
                const SizedBox(height: 20),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .18)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Close',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_rose, _roseDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: _rose.withValues(alpha: .33),
                            blurRadius: 16,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: const Text('💾 Save to camera roll',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template picker
// ─────────────────────────────────────────────────────────────────────────────

class _TemplatePicker extends StatefulWidget {
  const _TemplatePicker({super.key, required this.onSelect});
  final ValueChanged<_Tpl> onSelect;
  @override
  State<_TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<_TemplatePicker> {
  bool _showDuo = true;

  List<_Tpl> get _shown => _kTpls.where((t) => t.isDuo == _showDuo).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Choose your style',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F0A14))),
            const SizedBox(height: 3),
            const Text('Pick a layout that tells your story',
                style: TextStyle(fontSize: 12, color: _grey)),
            const SizedBox(height: 14),
            // Duo / Solo toggle
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0ECF4)),
              ),
              child: Row(children: [
                for (final (label, isDuo) in [
                  ('👥  Duo', true),
                  ('👤  Solo', false)
                ])
                  Expanded(
                      child: GestureDetector(
                    onTap: () => setState(() => _showDuo = isDuo),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _showDuo == isDuo
                            ? const Color(0xFFFFF0F3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _showDuo == isDuo ? _rose : _grey)),
                    ),
                  )),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: _shown.length,
            itemBuilder: (_, i) {
              final t = _shown[i];
              return _TemplateCard(
                tpl: t,
                isFirst: i == 0 && _showDuo,
                onTap: () => widget.onSelect(t),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard(
      {required this.tpl, required this.onTap, this.isFirst = false});
  final _Tpl tpl;
  final VoidCallback onTap;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0ECF4)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .07),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(children: [
          // Preview
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                child: _TemplateFrame(
                    pair: _mkPreview(tpl.id), size: _FSize.preview),
              ),
            ),
          ),
          // Name + tagline
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(tpl.name,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F1B24)))),
                if (isFirst)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                        color: _rose, borderRadius: BorderRadius.circular(99)),
                    child: const Text('DEFAULT',
                        style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: .5)),
                  ),
              ]),
              const SizedBox(height: 2),
              Text(tpl.tagline,
                  style: const TextStyle(fontSize: 10, color: _grey)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload view (post-template-selection)
// ─────────────────────────────────────────────────────────────────────────────

class _UploadView extends StatefulWidget {
  const _UploadView(
      {super.key, required this.template, required this.onGenerate});
  final _Tpl template;
  final ValueChanged<String> onGenerate;
  @override
  State<_UploadView> createState() => _UploadViewState();
}

class _UploadViewState extends State<_UploadView> {
  bool _leftReady = false;
  bool _rightReady = false;
  bool _loading = false;
  final _captionCtrl = TextEditingController();

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  bool get _isDuo => widget.template.isDuo;
  bool get _both => _isDuo ? (_leftReady && _rightReady) : _leftReady;
  String get _btnLabel => _loading
      ? '📸 Developing your pair...'
      : _both
          ? '📸 Create ${_isDuo ? "Our" : "My"} ${widget.template.name}'
          : 'Waiting for ${!_leftReady ? _myPet : _herPet}\'s photo';

  void _generate() {
    if (!_both || _loading) return;
    setState(() => _loading = true);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) widget.onGenerate(_captionCtrl.text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final tpl = widget.template;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
      child: Column(children: [
        // Template banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: tpl.accent.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tpl.accent.withValues(alpha: .2)),
          ),
          child: Row(children: [
            Text(tpl.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(tpl.name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tpl.accent)),
                  Text(tpl.tagline,
                      style: const TextStyle(fontSize: 11, color: _grey)),
                ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: tpl.accent, borderRadius: BorderRadius.circular(99)),
              child: Text(_isDuo ? '👥 Duo' : '👤 Solo',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Upload slots
        _UploadSlots(
          template: tpl,
          leftReady: _leftReady,
          rightReady: _rightReady,
          captionCtrl: _captionCtrl,
          onToggleLeft: () => setState(() => _leftReady = !_leftReady),
          onToggleRight: () => setState(() => _rightReady = !_rightReady),
        ),
        const SizedBox(height: 14),

        // Instructions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0ECF4))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('✨', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
                child: RichText(
                    text: TextSpan(
              style: const TextStyle(fontSize: 12, color: _grey, height: 1.6),
              children: [
                const TextSpan(
                    text: 'Tap each slot',
                    style: TextStyle(
                        color: Color(0xFF0F0A14), fontWeight: FontWeight.w600)),
                TextSpan(
                    text: _isDuo
                        ? ' to add your photo.\nYou each upload one selfie — Dayflower places them in the ${tpl.name} template.'
                        : ' to add your photo.\nThis template is all about you — pick your best shot.'),
              ],
            ))),
          ]),
        ),
        const SizedBox(height: 8),

        if (_isDuo) ...[
          Row(children: [
            Expanded(
                child:
                    _StatusPill(name: _myPet, ready: _leftReady, color: _rose)),
            const SizedBox(width: 8),
            Expanded(
                child: _StatusPill(
                    name: _herPet, ready: _rightReady, color: _sage)),
          ]),
          const SizedBox(height: 8),
        ],

        // Generate button
        GestureDetector(
          onTap: _both && !_loading ? _generate : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: _both && !_loading
                  ? LinearGradient(colors: [
                      tpl.accent,
                      Color.lerp(tpl.accent, Colors.black, .25)!
                    ], begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : null,
              color: _both && !_loading ? null : const Color(0xFFEDE8F0),
              borderRadius: BorderRadius.circular(16),
              boxShadow: _both && !_loading
                  ? [
                      BoxShadow(
                          color: tpl.accent.withValues(alpha: .35),
                          blurRadius: 24,
                          offset: const Offset(0, 8))
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(_btnLabel,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _both && !_loading
                        ? Colors.white
                        : const Color(0xFFB8A8C8))),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload slots
// ─────────────────────────────────────────────────────────────────────────────

class _UploadSlots extends StatelessWidget {
  const _UploadSlots({
    required this.template,
    required this.leftReady,
    required this.rightReady,
    required this.captionCtrl,
    required this.onToggleLeft,
    required this.onToggleRight,
  });
  final _Tpl template;
  final bool leftReady, rightReady;
  final TextEditingController captionCtrl;
  final VoidCallback onToggleLeft, onToggleRight;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: template.isDuo
              ? const Color(0xFFFFFEF8)
              : template.bg.withValues(alpha: .08),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          border: Border.all(color: template.accent.withValues(alpha: .2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .1),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            _Slot(
              ready: leftReady,
              onTap: onToggleLeft,
              name: _myPet,
              emoji: '🤳',
              readyBg: const Color(0xFFFDE8E0),
              readyColor: _rose,
              placeholder: 'Your\nphoto',
            ),
            if (template.isDuo) ...[
              const SizedBox(width: 4),
              _Slot(
                ready: rightReady,
                onTap: onToggleRight,
                name: _herPet,
                emoji: '🥰',
                readyBg: const Color(0xFFE0F0E8),
                readyColor: _sage,
                placeholder: '$_herPet\'s\nphoto',
              ),
            ],
          ]),
          // Caption bar
          SizedBox(
            height: 50,
            width: template.isDuo ? 256 : 126,
            child: Center(
                child: TextField(
              controller: captionCtrl,
              maxLength: 36,
              textAlign: TextAlign.center,
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF3A2A20), letterSpacing: .3),
              decoration: const InputDecoration(
                hintText: 'write a caption...',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFFC4B0CC)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            )),
          ),
        ]),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot(
      {required this.ready,
      required this.onTap,
      required this.name,
      required this.emoji,
      required this.readyBg,
      required this.readyColor,
      required this.placeholder});
  final bool ready;
  final VoidCallback onTap;
  final String name, emoji, placeholder;
  final Color readyBg, readyColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 126,
        height: 160,
        decoration: BoxDecoration(
          color: ready ? readyBg : const Color(0xFFF5F0F8),
          border: Border.all(
              color: ready
                  ? readyColor.withValues(alpha: .4)
                  : const Color(0xFFFFD6E0),
              width: 2),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Stack(alignment: Alignment.center, children: [
          if (ready)
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(emoji, style: const TextStyle(fontSize: 48)),
              Text(name,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: readyColor)),
            ])
          else
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('📷',
                  style: TextStyle(fontSize: 26, color: Color(0x4D000000))),
              const SizedBox(height: 6),
              Text(placeholder,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 10, color: _grey, height: 1.4)),
            ]),
          if (ready)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                    color: Color(0xFF52C41A), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Text('✓',
                    style: TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status pill
// ─────────────────────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill(
      {required this.name, required this.ready, required this.color});
  final String name;
  final bool ready;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ready ? color.withValues(alpha: .10) : const Color(0xFFF5F0F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                ready ? color.withValues(alpha: .25) : const Color(0xFFF0ECF4)),
      ),
      child: Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: ready ? color : const Color(0xFFD1C8DA),
                shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ready ? color : _grey)),
          Text(ready ? 'photo ready ✓' : 'waiting...',
              style: const TextStyle(fontSize: 10, color: _grey)),
        ])),
      ]),
    );
  }
}
