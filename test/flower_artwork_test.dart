import 'dart:io';

import 'package:dayflower/core/providers/supabase_provider.dart';
import 'package:dayflower/features/pairing/data/pair_repository.dart';
import 'package:dayflower/features/tulip/data/flower_repository.dart';
import 'package:dayflower/features/tulip/data/reaction_repository.dart';
import 'package:dayflower/features/tulip/domain/flower_catalog.dart';
import 'package:dayflower/features/tulip/presentation/widgets/chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// 🔴 The home-screen widget draws a flower's **artwork** now, falling back
/// to [Flower.emoji] only when the asset cannot be read. That fallback used
/// to be the only thing the widget ever showed — sending "Peach Tulips" to
/// somebody's home screen put a generic 🌷 on it — and it is silent by
/// design, so a flower shipped without its painting would look like the bug
/// coming back rather than like a missing file.
void main() {
  group('flower artwork', () {
    test('every flower a person can send ships its painting', () {
      final missing = [
        for (final flower in FlowerCatalog.pickable)
          if (!File(flower.asset).existsSync())
            '${flower.id} (${flower.asset})',
      ];
      expect(missing, isEmpty,
          reason: 'These would draw as a bare emoji on the widget');
    });

    test('the two without artwork are retired, and stay retired', () {
      // Sunflower and Hibiscus predate the painted catalogue. They are out of
      // the picker, so nobody can send one — but old messages still
      // reference them, and those fall back to the glyph, which is exactly
      // what the fallback is for.
      for (final id in ['sunflower', 'hibiscus']) {
        final flower = FlowerCatalog.all.firstWhere((f) => f.id == id);
        expect(flower.retired, isTrue, reason: '$id has no artwork');
        expect(File(flower.asset).existsSync(), isFalse);
      }
    });

    test('every cut-out stem is drawn at 3:4, the shape its frame takes', () {
      // The chat frames a stem at Flower.cutoutAspect. A stem of another
      // shape would be letterboxed there — not cropped, which is the bug
      // this guards, but small inside empty margin.
      for (final flower in FlowerCatalog.all.where((f) => f.cutout)) {
        final art = img.decodeWebP(File(flower.asset).readAsBytesSync())!;
        expect(art.width / art.height, closeTo(Flower.cutoutAspect, .01),
            reason: '${flower.id} is ${art.width}x${art.height}');
      }
    });

    testWidgets('a stem arrives in the chat whole, a scene fills its frame',
        (tester) async {
      // 🔴 A daisy arrived with the top of its bloom sliced flat: the chat
      // drew every flower `cover` in a square, and a 3:4 stem scaled to
      // fill a square loses its top and its foot.
      Future<(BoxFit?, double)> drawn(String flowerId) async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('me'),
            currentPairProvider.overrideWith((ref) async => null),
            reactionsProvider.overrideWith((ref) => Stream.value(const {})),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 260,
                child: ChatBubble(
                  isMine: false,
                  message: FlowerMessage(
                    id: 'm1',
                    pairId: 'p',
                    senderId: 'them',
                    flowerType: flowerId,
                    sentAt: DateTime(2026, 9, 23),
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pump();
        final image = tester.widget<Image>(find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName.endsWith('$flowerId.webp')));
        final frame = tester.widget<AspectRatio>(find.ancestor(
            of: find.byWidget(image), matching: find.byType(AspectRatio)));
        return (image.fit, frame.aspectRatio);
      }

      expect(await drawn('stem_daisy'), (BoxFit.contain, Flower.cutoutAspect));
      expect(await drawn('red_tulips'), (BoxFit.cover, 1.0));
    });

    test('the asset path is derived from the id, not stored twice', () {
      // A second field would be a second thing to keep in step; the widget's
      // cache filename is derived from the id for the same reason.
      final flower = FlowerCatalog.all.first;
      expect(flower.asset, 'assets/images/flowers/${flower.id}.webp');
    });
  });
}
