import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';

import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

/// Where every map in the app gets its tiles.
///
/// 🔴 **One place on purpose.** The travel map and the Home card draw the same
/// world, and a provider change that reached only one of them would leave two
/// maps of the same couple looking like different products. Both call
/// [layer]; nothing else builds a TileLayer.
///
/// ⚠️ **The default is OpenStreetMap's own tiles, and it should not ship.**
/// OSM's policy treats a distributed app pulling tiles as heavy use, and this
/// app now draws a map on Home, so every launch fetches some. Set
/// `CARTO_API_KEY` and the app moves to CARTO's basemaps, which allow five
/// million tiles a month at no cost, permit commercial use, and need no
/// account to obtain a key: https://carto.com/basemaps/apikey
class MapTiles {
  const MapTiles._();

  /// CARTO's warm basemap: cream land, pale water, restrained labels that
  /// still name towns when you zoom in. Closest to the app's own palette of
  /// the styles on offer, and unlike a road-atlas style it does not turn the
  /// card into a wall of motorways.
  static const _cartoStyle = 'voyager_nolabels';

  /// The same style with place names, for the screen you actually explore.
  static const _cartoStyleLabelled = 'voyager';

  /// 🔴 Guarded, because reading `dotenv.env` before `load()` throws rather
  /// than returning empty. Widget tests never load it, and a production build
  /// whose .env failed to parse would take every map down with it. A missing
  /// key is a fallback, not a crash.
  static String? get _key {
    try {
      if (!dotenv.isInitialized) return null;
      final k = dotenv.env['CARTO_API_KEY']?.trim();
      return (k == null || k.isEmpty) ? null : k;
    } catch (_) {
      return null;
    }
  }

  static bool get configured => _key != null;

  /// `labelled: false` for the Home card, where town names at a whole-country
  /// zoom are unreadable clutter behind two faces; `true` for the travel map,
  /// where naming the place is the entire point.
  ///
  /// Takes a context so it can ask for retina tiles only where the screen can
  /// actually show them.
  static TileLayer layer(BuildContext context, {bool labelled = true}) {
    final key = _key;
    if (key == null) {
      return TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        // ⚠️ Required by OSM's policy, and the thing that gets an app blocked
        // when it is left as the default.
        userAgentPackageName: 'com.dayflower.app',
        tileProvider: NetworkTileProvider(),
      );
    }
    final style = labelled ? _cartoStyleLabelled : _cartoStyle;
    return TileLayer(
      urlTemplate:
          'https://basemaps.cartocdn.com/rastertiles/$style/{z}/{x}/{y}{r}.png?api_key=$key',
      // Retina tiles where the screen can show them: `{r}` becomes "@2x".
      retinaMode: RetinaMode.isHighDensity(context),
      userAgentPackageName: 'com.dayflower.app',
      tileProvider: NetworkTileProvider(),
    );
  }

  /// Both providers require visible credit. This is not decoration, and it is
  /// why it lives beside the layer rather than being left to each caller to
  /// remember.
  static String get credit =>
      configured ? '© CARTO © OpenStreetMap' : '© OpenStreetMap';

  /// A small, legible credit line to sit on a map.
  ///
  /// ⚠️ No background. A filled pill is the one thing on these cards that
  /// still covers the map, and the credit is the least important thing on
  /// them. The halo keeps it readable over cream land or water blue without
  /// putting a box anywhere.
  static Widget attribution({EdgeInsets padding = const EdgeInsets.all(6)}) =>
      Padding(
        padding: padding,
        child: Text(credit,
            style: AppText.label().copyWith(fontSize: 9, shadows: [
              Shadow(color: AppColors.surface, blurRadius: 3),
              Shadow(color: AppColors.surface, blurRadius: 5),
            ])),
      );
}
