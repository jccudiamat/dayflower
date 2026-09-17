import 'package:flutter/material.dart';

enum BoothLayout {
  strip('4 cut', 'The classic strip', 4, 1),
  grid('2 × 2', 'Four moments together', 4, 2),
  two('2 cut', 'A little more room', 2, 1),
  portrait('Polaroid', 'One to keep', 1, 1);

  const BoothLayout(this.title, this.subtitle, this.shots, this.columns);
  final String title, subtitle;
  final int shots, columns;
  int get rows => shots ~/ columns;
  // Shared by the live frame, layout picker and exported JPEG.
  double get aspect => 1 / ((rows * .76 / columns) + .20);
}

enum BoothLook {
  rose('Rose room', 'Blush curtains & pink paper', Color(0xFFAC526D),
      Color(0xFFFFEDF3), Color(0xFF4C2433)),
  classic('Classic', 'Cream paper, timeless moments', Color(0xFF516C60),
      Color(0xFFFFFCF2), Color(0xFF263C31)),
  vintage('Vintage', 'Walnut & warm ivory', Color(0xFF78503D),
      Color(0xFFF2E5C8), Color(0xFF47392E)),
  midnight('After hours', 'Violet lights & dark paper', Color(0xFF6B50AC),
      Color(0xFF252037), Color(0xFFF5EFFF));

  const BoothLook(
      this.title, this.subtitle, this.curtain, this.paper, this.ink);
  final String title, subtitle;
  final Color curtain, paper, ink;
}

class BoothDesign {
  const BoothDesign(
      {this.look = BoothLook.rose, this.layout = BoothLayout.strip});
  final BoothLook look;
  final BoothLayout layout;
  String get id => 'studio_${look.name}_${layout.name}';
  String get title => 'Dayflower booth · ${look.title} · ${layout.title}';

  static BoothDesign? parse(String id) {
    for (final look in BoothLook.values) {
      for (final layout in BoothLayout.values) {
        final design = BoothDesign(look: look, layout: layout);
        if (design.id == id) return design;
      }
    }
    return null;
  }

  /// Normalized coordinates leave a real paper border and caption area.
  List<Rect> get panes {
    final height = 1 / layout.aspect;
    const pad = .045;
    final width = (1 - pad * (layout.columns + 1)) / layout.columns;
    final paneHeight = (height - .14 - pad * (layout.rows + 1)) / layout.rows;
    return [
      for (var i = 0; i < layout.shots; i++)
        Rect.fromLTWH(
            pad + (i % layout.columns) * (width + pad),
            (pad + (i ~/ layout.columns) * (paneHeight + pad)) / height,
            width,
            paneHeight / height),
    ];
  }
}
