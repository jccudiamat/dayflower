import 'package:flutter/material.dart';

/// Two kinds of thing you can send. Named for what the artwork actually
/// *is*: a bouquet or bloom is a flower; a place is a scene. Mislabelling
/// a meadow as a species reads as sloppy, so the split is honest instead.
enum FlowerCategory {
  flower,
  scene;

  String get label => this == flower ? 'Flowers' : 'Scenes';
}

/// Something the sender can pick. `id` is the stable string stored in
/// `flower_messages.flower_type` — **never rename an existing id**, old
/// messages reference them.
class Flower {
  const Flower({
    required this.id,
    required this.emoji,
    required this.name,
    required this.color,
    required this.meaning,
    required this.category,
    this.retired = false,
  });

  final String id;

  /// Fallback glyph — used by the home-screen widget, and in-app whenever
  /// [asset] is missing from the bundle.
  final String emoji;

  final String name;
  final Color color;
  final String meaning;
  final FlowerCategory category;

  /// Kept so old messages still resolve, but hidden from the picker.
  final bool retired;

  /// Artwork path, by convention `<id>.webp`. Render with `FlowerImage`,
  /// which falls back to [emoji] if the file isn't there.
  String get asset => 'assets/images/flowers/$id.webp';
}

class FlowerCatalog {
  /// Everything, including retired entries. Use [pickable] for the picker.
  static const all = <Flower>[
    // ── Flowers ────────────────────────────────────────────
    Flower(
      id: 'classic_tulip',
      emoji: '🌷',
      name: 'Classic Tulips',
      color: Color(0xFFD64270),
      meaning: 'Declaration of love',
      category: FlowerCategory.flower,
    ),
    Flower(
      id: 'roses_and_tulips',
      emoji: '🌹',
      name: 'Roses & Tulips',
      color: Color(0xFFC81E4A),
      meaning: 'I still choose you',
      category: FlowerCategory.flower,
    ),
    Flower(
      id: 'red_tulips',
      emoji: '🌷',
      name: 'Red Tulips',
      color: Color(0xFFD8324B),
      meaning: 'Thinking of you all day',
      category: FlowerCategory.flower,
    ),
    Flower(
      id: 'peach_tulips',
      emoji: '🌷',
      name: 'Peach Tulips',
      color: Color(0xFFF0A085),
      meaning: 'Something gentle for today',
      category: FlowerCategory.flower,
    ),
    Flower(
      id: 'lavender_roses',
      emoji: '💜',
      name: 'Lavender Roses',
      color: Color(0xFF9B7FD4),
      meaning: 'You are on my mind',
      category: FlowerCategory.flower,
    ),
    Flower(
      id: 'tulips_and_lilies',
      emoji: '🪷',
      name: 'Tulips & Lilies',
      color: Color(0xFFEFB8C8),
      meaning: 'Soft place to land',
      category: FlowerCategory.flower,
    ),
    Flower(
      id: 'tulip_protea',
      emoji: '💐',
      name: 'Tulip & Protea',
      color: Color(0xFFCE5A8E),
      meaning: 'Something rare, like you',
      category: FlowerCategory.flower,
    ),
    Flower(
      id: 'wrapped_bouquet',
      emoji: '💐',
      name: 'Wrapped Bouquet',
      color: Color(0xFF9C6BAF),
      meaning: 'Wish I could hand you this',
      category: FlowerCategory.flower,
    ),
    Flower(
      id: 'bouquet',
      emoji: '💐',
      name: 'Full Bouquet',
      color: Color(0xFFE8722A),
      meaning: 'You mean everything',
      category: FlowerCategory.flower,
    ),
    Flower(
      id: 'seaside_posy',
      emoji: '🌼',
      name: 'Seaside Posy',
      color: Color(0xFFE8B94A),
      meaning: 'Somewhere we should go',
      category: FlowerCategory.flower,
    ),
    Flower(
      id: 'driftwood_posy',
      emoji: '🌼',
      name: 'Driftwood Posy',
      color: Color(0xFFD9A84E),
      meaning: 'Slow morning, thinking of us',
      category: FlowerCategory.flower,
    ),
    Flower(
      id: 'terrace_tulips',
      emoji: '🌷',
      name: 'Terrace Tulips',
      color: Color(0xFFE0522F),
      meaning: 'Ordinary day, still yours',
      category: FlowerCategory.flower,
    ),

    // ── Scenes ─────────────────────────────────────────────
    Flower(
      id: 'sunlit_wood',
      emoji: '🌲',
      name: 'Sunlit Wood',
      color: Color(0xFFD9713F),
      meaning: 'A good morning to you',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'garden_path',
      emoji: '🪻',
      name: 'Garden Path',
      color: Color(0xFF8E7BC8),
      meaning: 'Walk it with me',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'jungle_bloom',
      emoji: '🦜',
      name: 'Jungle Bloom',
      color: Color(0xFF2E8B57),
      meaning: 'Somewhere wild together',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'lavender_doves',
      emoji: '🕊️',
      name: 'Lavender & Doves',
      color: Color(0xFF9A86D6),
      meaning: 'Peace, wherever you are',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'paradise_grove',
      emoji: '🌺',
      name: 'Paradise Grove',
      color: Color(0xFFE2445C),
      meaning: 'Running away with you',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'sunset_shore',
      emoji: '🌅',
      name: 'Sunset Shore',
      color: Color(0xFFE9A05C),
      meaning: 'Same sun, different window',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'canyon_poppies',
      emoji: '🏜️',
      name: 'Canyon Poppies',
      color: Color(0xFFE07B39),
      meaning: 'Even the dry places bloom',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'misty_grove',
      emoji: '🌫️',
      name: 'Misty Grove',
      color: Color(0xFF9E86A8),
      meaning: 'Quiet day, loud heart',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'blossom_heron',
      emoji: '🌸',
      name: 'Blossom & Heron',
      color: Color(0xFFEFA8BE),
      meaning: 'Stillness I wish we shared',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'fox_in_tulips',
      emoji: '🦊',
      name: 'Fox in the Tulips',
      color: Color(0xFFE08A6A),
      meaning: 'Something small made me smile',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'cliffside_bloom',
      emoji: '🌊',
      name: 'Cliffside Bloom',
      color: Color(0xFF4E9FC4),
      meaning: 'Miles of sea, still close',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'lavender_fields',
      emoji: '💜',
      name: 'Lavender Fields',
      color: Color(0xFF8B72E0),
      meaning: "Rest — I've got you",
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'highland_tulips',
      emoji: '⛰️',
      name: 'Highland Tulips',
      color: Color(0xFFDE8FA6),
      meaning: 'Worth the long way',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'desert_bloom',
      emoji: '🐢',
      name: 'Desert Bloom',
      color: Color(0xFFE09240),
      meaning: 'Slow and certain, like us',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'alpine_meadow',
      emoji: '🦅',
      name: 'Alpine Meadow',
      color: Color(0xFF5B8DEF),
      meaning: 'Thinking big of you',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'deer_clearing',
      emoji: '🦌',
      name: 'Deer Clearing',
      color: Color(0xFF7FA05C),
      meaning: 'Gentle day to you',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'quiet_woodland',
      emoji: '🌿',
      name: 'Quiet Woodland',
      color: Color(0xFF6C9A6E),
      meaning: 'Nothing to say, just here',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'misty_blossom',
      emoji: '🌸',
      name: 'Misty Blossom',
      color: Color(0xFFE9AFC6),
      meaning: 'Soft start to the day',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'bench_in_bloom',
      emoji: '🪑',
      name: 'Bench in Bloom',
      color: Color(0xFFB3894F),
      meaning: 'Saving you a seat',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'mountain_spring',
      emoji: '🏔️',
      name: 'Mountain Spring',
      color: Color(0xFF4A7FD4),
      meaning: 'Fresh start, together',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'fawn_butterflies',
      emoji: '🦋',
      name: 'Fawn & Butterflies',
      color: Color(0xFFCE93D8),
      meaning: 'You make it lighter',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'morning_meadow',
      emoji: '🌾',
      name: 'Morning Meadow',
      color: Color(0xFFA8B87A),
      meaning: 'First thought was you',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'dappled_light',
      emoji: '✨',
      name: 'Dappled Light',
      color: Color(0xFFD9B84E),
      meaning: 'Little bit of sun for you',
      category: FlowerCategory.scene,
    ),
    Flower(
      id: 'wildflower_haze',
      emoji: '🌸',
      name: 'Wildflower Haze',
      color: Color(0xFFC77BA8),
      meaning: 'Dreaming in your direction',
      category: FlowerCategory.scene,
    ),

    // ── Retired ────────────────────────────────────────────
    // No artwork in the set matches these, but flower_messages rows still
    // reference them. Kept so history renders correctly; hidden from the
    // picker so nobody sends a lone emoji among the photographs.
    Flower(
      id: 'sunflower',
      emoji: '🌻',
      name: 'Sunflower',
      color: Color(0xFFE8922A),
      meaning: 'Always watching',
      category: FlowerCategory.flower,
      retired: true,
    ),
    Flower(
      id: 'hibiscus',
      emoji: '🌺',
      name: 'Hibiscus',
      color: Color(0xFFEF4444),
      meaning: 'Rare beauty',
      category: FlowerCategory.flower,
      retired: true,
    ),
  ];

  /// What the picker offers.
  static final pickable = all.where((f) => !f.retired).toList();

  static final _byId = {for (final f in all) f.id: f};

  /// Falls back to the classic tulip for unknown ids so old messages
  /// never crash the UI.
  static Flower byId(String id) => _byId[id] ?? all.first;
}
