import 'package:flutter/material.dart';

/// A booth strip layout.
///
/// Extracted from `booth_screen.dart`, where the same list was private and
/// only ever rendered mock emoji. These drive the real compositor in
/// `strip_compositor.dart`, so the values here describe how a photo is
/// actually framed — not just how the picker chip looks.
///
/// [isDuo] is the whole feature: a duo template holds one half open until
/// the partner shoots theirs. See migration 0014.
class StripTemplate {
  const StripTemplate({
    required this.id,
    required this.name,
    required this.tagline,
    required this.isDuo,
    required this.emoji,
    required this.accent,
    required this.paper,
    required this.ink,
    this.stacked = true,
  });

  final String id;
  final String name;
  final String tagline;
  final bool isDuo;
  final String emoji;

  /// Border / caption colour.
  final Color accent;

  /// The frame the photos sit on.
  final Color paper;

  /// Caption text colour, chosen to read on [paper].
  final Color ink;

  /// Duo layout: true stacks the halves vertically (a photo-booth strip),
  /// false places them side by side. Ignored for solo templates.
  final bool stacked;

  static const all = <StripTemplate>[
    StripTemplate(
      id: 'classic',
      name: 'Classic Polaroid',
      tagline: 'The timeless OG',
      isDuo: true,
      emoji: '🖼️',
      accent: Color(0xFFD64270),
      paper: Color(0xFFFFFEF8),
      ink: Color(0xFF2C2438),
    ),
    StripTemplate(
      id: 'film_strip',
      name: 'Film Strip',
      tagline: 'Cinematic moments',
      isDuo: true,
      emoji: '🎞️',
      accent: Color(0xFFD4A017),
      paper: Color(0xFF1C1C1E),
      ink: Color(0xFFF5F2F8),
    ),
    StripTemplate(
      id: 'scrapbook',
      name: 'Scrapbook',
      tagline: 'Cut, paste & love',
      isDuo: true,
      emoji: '✂️',
      accent: Color(0xFF4CAF82),
      paper: Color(0xFFFBF6EE),
      ink: Color(0xFF2C2438),
    ),
    StripTemplate(
      id: 'neon',
      name: 'Neon Booth',
      tagline: 'Night vibes only',
      isDuo: true,
      emoji: '🌈',
      accent: Color(0xFF8B5CF6),
      paper: Color(0xFF0E0720),
      ink: Color(0xFFF5F2F8),
    ),
    StripTemplate(
      id: 'split',
      name: 'Split Frame',
      tagline: 'Two worlds, one shot',
      isDuo: true,
      emoji: '⚡',
      accent: Color(0xFFE8922A),
      paper: Color(0xFFF5F5F5),
      ink: Color(0xFF2C2438),
      stacked: false,
    ),
    StripTemplate(
      id: 'locket',
      name: 'Locket',
      tagline: 'Close to my heart',
      isDuo: true,
      emoji: '💞',
      accent: Color(0xFFE85D9A),
      paper: Color(0xFFFFF0F8),
      ink: Color(0xFF2C2438),
      stacked: false,
    ),
    StripTemplate(
      id: 'vintage',
      name: 'Vintage',
      tagline: 'Old souls, new love',
      isDuo: true,
      emoji: '🍂',
      accent: Color(0xFF8B6914),
      paper: Color(0xFFF5EED9),
      ink: Color(0xFF2C2438),
    ),
    StripTemplate(
      id: 'solo_portrait',
      name: 'Solo Portrait',
      tagline: 'The main character',
      isDuo: false,
      emoji: '🌟',
      accent: Color(0xFF6B5CE7),
      paper: Color(0xFFFFFEF8),
      ink: Color(0xFF2C2438),
    ),
    StripTemplate(
      id: 'solo_film',
      name: 'Solo Film',
      tagline: 'Triple feature',
      isDuo: false,
      emoji: '🎬',
      accent: Color(0xFF374151),
      paper: Color(0xFF111827),
      ink: Color(0xFFF5F2F8),
    ),
    StripTemplate(
      id: 'aesthetic',
      name: 'Aesthetic',
      tagline: 'Soft & minimal',
      isDuo: false,
      emoji: '🌸',
      accent: Color(0xFF9B7DB0),
      paper: Color(0xFFF9F5FF),
      ink: Color(0xFF2C2438),
    ),
  ];

  static final _byId = {for (final t in all) t.id: t};

  /// Unknown ids fall back rather than throw: a strip row can outlive a
  /// template being renamed, and an old message must still render.
  static StripTemplate byId(String id) => _byId[id] ?? all.first;

  static List<StripTemplate> get duo =>
      all.where((t) => t.isDuo).toList(growable: false);
  static List<StripTemplate> get solo =>
      all.where((t) => !t.isDuo).toList(growable: false);
}
