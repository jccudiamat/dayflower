import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';
import 'together_assets.dart';

// ═══════════════════════════════════════════════════════════════════════
//   🔴 MOCK DATA — nothing in this file comes from a backend.
// ═══════════════════════════════════════════════════════════════════════
//
// Play Together has no games, playlist or watch-party behind it yet: no
// tables, no screens, no routes. Everything the card shows about it lives
// here, in one place, so that when a real feature arrives it is obvious
// what to replace and nothing else on the tab has to change.
//
// Every other card on the Together tab reads real data. If you are looking
// for where a number on that tab comes from and it is not in this file, it
// is live.

/// One tile under "Play Together".
@immutable
class PlayTile {
  const PlayTile({
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.fallbackIcon,
    required this.tint,
  });

  final String title;

  /// 🔴 Mock: "6 games" counts nothing — there are no games.
  final String subtitle;

  final String asset;
  final IconData fallbackIcon;
  final TogetherTile tint;
}

/// The line under the card's title.
const playTogetherSubtitle = 'Fun moments, even when we’re apart.';

/// 🔴 Mock. None of these open anything yet; tapping one says so.
const playTogetherTiles = <PlayTile>[
  PlayTile(
    title: 'Games',
    subtitle: '6 games',
    asset: TogetherAssets.games,
    fallbackIcon: Icons.sports_esports_rounded,
    tint: TogetherTile.lavender,
  ),
  PlayTile(
    title: 'Music',
    subtitle: 'Our playlist',
    asset: TogetherAssets.music,
    fallbackIcon: Icons.headphones_rounded,
    tint: TogetherTile.pink,
  ),
  PlayTile(
    title: 'Watch Together',
    subtitle: 'Movie nights',
    asset: TogetherAssets.watchTogether,
    fallbackIcon: Icons.movie_rounded,
    tint: TogetherTile.peach,
  ),
];
