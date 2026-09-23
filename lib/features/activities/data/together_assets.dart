/// Every illustration the Together tab draws, by path.
///
/// Files are named for what they depict, and the roles below point at them,
/// so one picture can serve two places — the island is both the next-trip
/// row and the savings card — without shipping twice.
///
/// 🔴 **Two are still missing, and that is expected.** Everything is drawn
/// through `TogetherArt` or an equivalent fallback, which paints a soft
/// gradient with an icon whenever a file does not exist. Dropping the file
/// into `assets/images/together/` under exactly the name in [awaitingArt] is
/// the whole job: no widget, route or provider needs to change.
///
/// ⚠️ The originals live in `design/together/` in the main checkout and are
/// 8 MB. What ships is made by `tool/shrink_together.py` — trimmed, sized to
/// 3x what is drawn, and WebP — because the APK sits under 1 MB from the
/// 50 MB limit the updater can publish.
class TogetherAssets {
  TogetherAssets._();

  static const _dir = 'assets/images/together';

  // ── The files ────────────────────────────────────────────────
  static const _coupleSunset = '$_dir/couple_sunset.webp';
  static const _airplane = '$_dir/airplane.webp';
  static const _island = '$_dir/island.webp';
  static const _piggyBank = '$_dir/piggy_bank.webp';
  static const _calendarHearts = '$_dir/calendar_hearts.webp';
  static const _giftForYou = '$_dir/gift_for_you.webp';
  static const _gameController = '$_dir/game_controller.webp';
  static const _headphones = '$_dir/headphones.webp';
  static const _popcornTv = '$_dir/popcorn_tv.webp';

  // Not drawn yet. PNG, because that is what will be dropped in.
  static const _heart = '$_dir/heart.png';
  static const _mapBackground = '$_dir/map_background.png';

  // ── Hero: "What's next for us?" ──────────────────────────────
  /// The two of you watching the sunset, on the right of the hero.
  static const hero = _coupleSunset;
  static const heroMonthsary = _heart;
  static const heroReunion = _airplane;
  static const heroTrip = _island;

  // ── Events and Gifts ─────────────────────────────────────────
  static const eventsCalendar = _calendarHearts;
  static const gift = _giftForYou;

  // ── Our Map ──────────────────────────────────────────────────
  static const mapBackground = _mapBackground;

  // ── Our Savings ──────────────────────────────────────────────
  static const savings = _island;

  /// Before there is a goal to show. (Drawn for the mockup's Shared Goals,
  /// which this tab does not have — goals live in each month's chapter.)
  static const savingsEmpty = _piggyBank;

  // ── Play Together ────────────────────────────────────────────
  static const games = _gameController;
  static const music = _headphones;
  static const watchTogether = _popcornTv;

  /// Every file the tab can draw, once each.
  static const all = [
    _coupleSunset,
    _airplane,
    _island,
    _piggyBank,
    _calendarHearts,
    _giftForYou,
    _gameController,
    _headphones,
    _popcornTv,
    ..._awaiting,
  ];

  static const _awaiting = [_heart, _mapBackground];

  /// The files not drawn yet. Everything in [all] and not here must exist
  /// on disk — a test holds that, so a typo in a path fails the build
  /// rather than showing a placeholder forever.
  static const awaitingArt = _awaiting;
}
