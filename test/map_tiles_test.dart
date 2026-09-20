import 'package:dayflower/core/map/map_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

/// 🔴 **This file exists because build 83 shipped a watermark to real phones.**
/// The key was passed as `api_key`, which CARTO does not recognise. It does
/// not reject the request: it returns 200, a valid PNG, byte-for-byte the
/// same image an anonymous caller gets, with "API key required" burned into
/// the pixels. Status codes, logs and widget tests all looked healthy. The
/// only signal was the map itself.
void main() {
  /// [MapTiles.layer] reads pixel density off the context, so it needs a real
  /// tree rather than a stub.
  Future<TileLayer> layer(WidgetTester tester,
      {bool labelled = true, Brightness brightness = Brightness.light}) async {
    late TileLayer built;
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Builder(builder: (context) {
          built = MapTiles.layer(context, labelled: labelled);
          return const SizedBox.shrink();
        })));
    // ⚠️ One more frame, and it matters on a tree that is being reused. A
    // Theme dependency is notified by marking the dependent dirty, so the
    // rebuild lands on the *next* frame — read straight after pumpWidget and
    // you get the layer from the theme you just replaced. Invisible in the
    // app, which paints that frame a few milliseconds later; not invisible
    // here, where it silently made this file test nothing.
    await tester.pumpAndSettle();
    return built;
  }

  tearDown(dotenv.clean);

  testWidgets('The key rides as `key`, which is the parameter CARTO reads',
      (tester) async {
    // loadFromString avoids touching the real .env, so this says the same
    // thing on a machine that has no key at all.
    dotenv.loadFromString(envString: 'CARTO_API_KEY=test-key-123');
    final url = (await layer(tester)).urlTemplate!;
    expect(url, contains('?key=test-key-123'));
    // The exact trap: a parameter CARTO ignores, which fails silently.
    expect(url, isNot(contains('api_key=')));
  });

  testWidgets('A key switches the tiles to CARTO, and its absence falls back',
      (tester) async {
    dotenv.loadFromString(envString: 'CARTO_API_KEY=test-key-123');
    expect(MapTiles.configured, isTrue);
    expect((await layer(tester)).urlTemplate, contains('basemaps.cartocdn.com'));
    expect(MapTiles.credit, contains('CARTO'));

    dotenv.loadFromString(envString: 'CARTO_API_KEY=');
    expect(MapTiles.configured, isFalse);
    // ⚠️ A missing key is a fallback, never a crash — a map on Home means a
    // throw here would take the first screen of the app down with it.
    expect((await layer(tester)).urlTemplate, contains('tile.openstreetmap.org'));
    expect(MapTiles.credit, isNot(contains('CARTO')));
  });

  testWidgets('Home drops the labels, the travel map keeps them',
      (tester) async {
    dotenv.loadFromString(envString: 'CARTO_API_KEY=test-key-123');
    expect((await layer(tester, labelled: false)).urlTemplate,
        contains('voyager_nolabels'));
    expect((await layer(tester)).urlTemplate, contains('rastertiles/voyager/'));
  });

  testWidgets('Dark mode swaps the basemap, on both maps', (tester) async {
    dotenv.loadFromString(envString: 'CARTO_API_KEY=test-key-123');
    final home = await layer(tester,
        labelled: false, brightness: Brightness.dark);
    final travel = await layer(tester, brightness: Brightness.dark);
    // ⚠️ 'dark_all' and 'dark_nolabels'. CARTO's own docs call this style
    // Dark Matter, and 'dark_matter' 404s on the raster endpoint.
    expect(home.urlTemplate, contains('rastertiles/dark_nolabels/'));
    expect(travel.urlTemplate, contains('rastertiles/dark_all/'));
    expect(home.urlTemplate, isNot(contains('voyager')));
    expect(travel.urlTemplate, isNot(contains('voyager')));
  });

  testWidgets('The style follows Theme, so a const map still repaints',
      (tester) async {
    // 🔴 The whole reason this reads Theme and not AppColors.isDark: a
    // global is not a dependency, and a const widget that read one would
    // keep whichever map it was first built with. Same failure that shipped
    // four white cards on a black Settings screen.
    dotenv.loadFromString(envString: 'CARTO_API_KEY=test-key-123');
    final light = await layer(tester, brightness: Brightness.light);
    final dark = await layer(tester, brightness: Brightness.dark);
    expect(light.urlTemplate, isNot(dark.urlTemplate));
  });
}
