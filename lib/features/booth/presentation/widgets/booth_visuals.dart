import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../domain/booth_design.dart';

class BoothPortal extends StatelessWidget {
  const BoothPortal({super.key, required this.onEnter, this.compact = false});
  final VoidCallback onEnter;
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Enter the photo booth',
        button: true,
        child: GestureDetector(
            onTap: onEnter,
            child: Column(children: [
              SizedBox(
                  height: compact ? 330 : 410,
                  child: Stack(alignment: Alignment.center, children: [
                    Image.asset('assets/images/booth_entrance.jpg',
                        fit: BoxFit.contain, excludeFromSemantics: true),
                    Positioned(
                        top: compact ? 25 : 33,
                        child: Text('PHOTO BOOTH',
                            style: AppText.label(const Color(0xFF65462E))
                                .copyWith(letterSpacing: 3))),
                  ])),
              FilledButton.icon(
                  onPressed: onEnter,
                  icon: const Icon(Icons.meeting_room_outlined),
                  label: const Text('Enter the booth')),
            ])),
      );
}

/// A real frame preview: these pane coordinates also place pixels in exports.
class BoothPaper extends StatelessWidget {
  const BoothPaper(
      {super.key, required this.design, this.photos = const [], this.active});
  final BoothDesign design;
  final List<Uint8List> photos;
  final int? active;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: design.layout.aspect,
        child: LayoutBuilder(
            builder: (context, box) => Container(
                  decoration:
                      BoxDecoration(color: design.look.paper, boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: .13),
                        blurRadius: 12,
                        offset: const Offset(2, 5))
                  ]),
                  child: Stack(children: [
                    for (var i = 0; i < design.panes.length; i++)
                      Positioned.fromRect(
                          rect: Rect.fromLTWH(
                            design.panes[i].left * box.maxWidth,
                            design.panes[i].top * box.maxHeight,
                            design.panes[i].width * box.maxWidth,
                            design.panes[i].height * box.maxHeight,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                                color:
                                    design.look.curtain.withValues(alpha: .14),
                                border: active == i
                                    ? Border.all(
                                        color: design.look.curtain, width: 2)
                                    : null),
                            child: i < photos.length
                                ? Image.memory(photos[i],
                                    fit: BoxFit.cover,
                                    semanticLabel: 'Shot ${i + 1}')
                                : Center(
                                    child: Icon(
                                        active == i
                                            ? Icons.camera_alt_outlined
                                            : Icons.favorite_border,
                                        color: design.look.ink
                                            .withValues(alpha: .35),
                                        size: (box.maxWidth * .10)
                                            .clamp(12, 28))),
                          )),
                    Positioned(
                        left: 0,
                        right: 0,
                        bottom: box.maxWidth * .025,
                        child: Text('DAYFLOWER',
                            textAlign: TextAlign.center,
                            style: AppText.label(design.look.ink).copyWith(
                                fontSize: (box.maxWidth * .032).clamp(5, 13),
                                letterSpacing: 1.2))),
                  ]),
                )),
      );
}

class BoothRoomPreview extends StatelessWidget {
  const BoothRoomPreview({super.key, required this.look});
  final BoothLook look;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
            aspectRatio: 1.35,
            child: Stack(children: [
              Positioned.fill(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                    look.curtain.withValues(alpha: .2),
                    look.curtain.withValues(alpha: .55)
                  ])))),
              Positioned(
                  top: 12,
                  left: 26,
                  right: 26,
                  bottom: 10,
                  child: Container(
                      decoration: BoxDecoration(
                          color: look.paper,
                          border: Border.all(
                              color: look.ink.withValues(alpha: .45), width: 5),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(22))),
                      child: Row(children: [
                        Expanded(
                            child: CustomPaint(
                                painter: _Curtain(look.curtain),
                                child: const SizedBox.expand())),
                        Expanded(
                            child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                              Icon(Icons.camera_alt_outlined,
                                  color: look.ink, size: 20),
                              Container(
                                  width: 24,
                                  height: 6,
                                  color: look.ink.withValues(alpha: .5)),
                            ])),
                      ]))),
            ])),
      );
}

class _Curtain extends CustomPainter {
  _Curtain(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 6; i++) {
      final rect =
          Rect.fromLTWH(i * size.width / 6, 0, size.width / 6 + 1, size.height);
      canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(colors: [
              Color.lerp(color, Colors.black, .25)!,
              color,
              Color.lerp(color, Colors.white, .2)!,
              color,
            ]).createShader(rect));
    }
  }

  @override
  bool shouldRepaint(_Curtain old) => old.color != color;
}

class PrintingPhoto extends StatelessWidget {
  const PrintingPhoto({super.key, required this.bytes, required this.onDone});
  final Uint8List bytes;
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 2600),
        curve: Curves.easeInOutCubic,
        onEnd: onDone,
        builder: (context, value, child) => Column(children: [
          Container(
              height: 22,
              decoration: BoxDecoration(
                  color: const Color(0xFF3D2C31),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFFBB9F7B), width: 5))),
          ClipRect(
              child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: value,
                  child: child)),
        ]),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Image.memory(bytes,
                fit: BoxFit.contain,
                semanticLabel: 'Your printed photo strip')),
      );
}
