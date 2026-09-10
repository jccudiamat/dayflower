import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/gift_catalog.dart';
import '../../data/gift_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/ios_back_button.dart';

class GiftsScreen extends ConsumerStatefulWidget {
  const GiftsScreen({super.key, this.occasion, this.openLink});
  final String? occasion;
  final Future<bool> Function(Uri)? openLink;
  @override
  ConsumerState<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends ConsumerState<GiftsScreen> {
  final _search = TextEditingController();

  /// 🔴 Keyed by product **id**, not by position. The catalogue is loaded from
  /// the server now and can reorder or shrink between builds; a set of indices
  /// would quietly start pointing at different gifts.
  final _saved = <String>{};
  String _recipient = 'All';
  String _category = 'All types';
  int? _budget;
  bool _savedOnly = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openProduct(GiftProduct product) async {
    // 🔴 **Wrapped, and never awaited.** Two ways this can fail and neither
    // may reach the tap: the insert can reject, and `ref.read` can throw
    // before there is anything to insert with — no Supabase yet, offline, or
    // a test harness that never overrode the client. The first version put
    // the read outside a try and a gift stopped opening at all, which the
    // navigation test caught. Bookkeeping does not get to break the feature
    // it is counting.
    try {
      unawaited(ref
          .read(giftRepositoryProvider)
          .logClick(product.id)
          .catchError((Object e) => debugPrint('gift click log failed: $e')));
    } catch (e) {
      debugPrint('gift click log unavailable: $e');
    }

    var opened = false;
    try {
      final uri = Uri.parse(product.url);
      opened = await (widget.openLink?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      // Surface launch failures without losing the current filters or saves.
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not open Shopee. Please try again.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    // ⚠️ `.valueOrNull ?? giftProducts` rather than a spinner. The catalogue
    // is a list of shopping links, not the user's own data: showing the
    // shipped snapshot for the half-second the network takes is better than
    // an empty screen that looks like a broken feature, and better than a
    // loading state on a page nobody is waiting on.
    final catalog = ref.watch(giftCatalogProvider).valueOrNull ?? giftProducts;
    final products = [
      for (final p in catalog)
        if (p.matches(
                query: query,
                recipient: _recipient,
                category: _category,
                budget: _budget) &&
            (!_savedOnly || _saved.contains(p.id)))
          p
    ];
    return Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: const AppBottomNav(),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            if (context.canPop()) ...[
              IosBackButton(onTap: () => context.pop()),
              const SizedBox(width: 8)
            ],
            Expanded(child: Text('Gifts', style: AppText.hero())),
            IconButton(
                tooltip: _savedOnly ? 'Show all gifts' : 'Show saved gifts',
                onPressed: () => setState(() => _savedOnly = !_savedOnly),
                icon: Icon(
                    _savedOnly
                        ? CupertinoIcons.heart_fill
                        : CupertinoIcons.heart,
                    color: AppColors.secondary)),
          ]),
          Text('A little something. A lot of love.',
              style: AppText.body(AppColors.muted)),
          const SizedBox(height: 16),
          TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Find something thoughtful',
                hintStyle: AppText.caption(),
                prefixIcon: const Icon(CupertinoIcons.search, size: 20),
                filled: true,
                fillColor: AppColors.surface,
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_search.clear)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.border)),
              )),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final recipient in ['All', 'Partner', 'Family', 'Friends'])
              ChoiceChip(
                  label: Text(recipient),
                  selected: _recipient == recipient,
                  showCheckmark: false,
                  selectedColor: AppColors.surface,
                  backgroundColor: AppColors.background,
                  side: BorderSide(
                      color: _recipient == recipient
                          ? AppColors.secondary
                          : AppColors.border),
                  onSelected: (_) => setState(() => _recipient = recipient))
          ]),
          Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PopupMenuButton<int>(
                    tooltip: 'Filter by budget',
                    onSelected: (v) =>
                        setState(() => _budget = v == 0 ? null : v),
                    itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 0, child: Text('Any budget')),
                          const PopupMenuItem(
                              value: 200, child: Text('Up to ₱200')),
                          const PopupMenuItem(
                              value: 500, child: Text('Up to ₱500')),
                          const PopupMenuItem(
                              value: 1000, child: Text('Up to ₱1,000'))
                        ],
                    child: Chip(
                        label: Text(
                            _budget == null ? 'Budget' : 'Up to ₱$_budget'),
                        avatar: const Icon(CupertinoIcons.tag, size: 16))),
                Text('Shopee Philippines', style: AppText.caption()),
              ]),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final category in [
                'All types',
                // From the live catalogue, so a category introduced from
                // the dashboard gets a chip without a build.
                ...catalog.map((p) => p.category).toSet()
              ])
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                        label: Text(category),
                        selected: _category == category,
                        showCheckmark: false,
                        onSelected: (_) =>
                            setState(() => _category = category))),
            ]),
          ),
          if (widget.occasion?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text('A gift for your ${widget.occasion!.toLowerCase()}',
                style: AppText.subtitle(AppColors.secondary))
          ],
          const SizedBox(height: 16), const _GiftUsCard(),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: Text(_savedOnly ? 'Saved gifts' : 'Thoughtful finds',
                    style: AppText.title())),
            Text(
                '${products.length} ${products.length == 1 ? 'idea' : 'ideas'}',
                style: AppText.caption())
          ]),
          const SizedBox(height: 4),
          Text(
              _recipient == 'All'
                  ? 'For partners, family & friends'
                  : 'A little something for ${_recipient.toLowerCase()}',
              style: AppText.caption()),
          Text(
              'Prices checked $giftCatalogChecked. Prices, options and availability may change on Shopee.',
              style: AppText.caption()),
          const SizedBox(height: 12),
          if (products.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                    _savedOnly
                        ? 'No saved gifts match yet. Tap a heart to keep an idea here for this visit.'
                        : 'No gifts match. Try another search or budget.',
                    style: AppText.body())),
          // Natural row heights accommodate large text without clipped grid cells.
          for (var i = 0; i < products.length; i += 2)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var j = i; j < i + 2; j++) ...[
                        if (j > i) const SizedBox(width: 12),
                        Expanded(
                            child: j >= products.length
                                ? const SizedBox()
                                : _ProductCard(
                                    product: products[j],
                                    saved: _saved.contains(products[j].id),
                                    onView: () => _openProduct(products[j]),
                                    onSave: () => setState(() {
                                          final id = products[j].id;
                                          if (!_saved.add(id)) {
                                            _saved.remove(id);
                                          }
                                        }))),
                      ]
                    ])),
          const SizedBox(height: 8),
          Text(
              'Favourites are kept for this visit. Product photos belong to the sellers. Orders and delivery are handled on Shopee.',
              style: AppText.caption(),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
        ])));
  }
}

class _GiftUsCard extends StatelessWidget {
  const _GiftUsCard();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: AppGradients.hero, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('Gift us', style: AppText.hero(AppColors.onDark))),
          const Icon(CupertinoIcons.gift_fill,
              color: AppColors.gradientPink, size: 32)
        ]),
        const SizedBox(height: 8),
        Text('Dayflower Premium', style: AppText.subtitle(AppColors.onDark)),
        const SizedBox(height: 4),
        Text(
            'A subscription for the two of you. More little ways to feel close.',
            style: AppText.body(AppColors.onDarkMuted)),
        const SizedBox(height: 12),
        Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white),
                  onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      isScrollControlled: true,
                      builder: (context) => SafeArea(
                          child: SingleChildScrollView(
                              child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 0, 24, 24),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Gift us', style: AppText.hero()),
                                        const SizedBox(height: 8),
                                        Text('Dayflower Premium · Coming soon',
                                            style: AppText.subtitle()),
                                        const SizedBox(height: 16),
                                        Text(
                                            'A shared subscription, made for the two of you.',
                                            style: AppText.body()),
                                        const SizedBox(height: 12),
                                        Text('Planned for Premium',
                                            style: AppText.label()),
                                        const SizedBox(height: 8),
                                        Text(
                                            'Rare & seasonal flowers\nFull garden view\nUnlimited photo strips\nFlower recognition\nStreak repair',
                                            style: AppText.body()),
                                        const SizedBox(height: 16),
                                        Text(
                                            'Subscriptions are not available yet. Nothing will be charged.',
                                            style: AppText.caption()),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Got it')),
                                      ]))))),
                  child: const Text('View subscription')),
              Text('Coming soon',
                  style: AppText.caption(AppColors.onDarkMuted)),
            ])
      ]));
}

/// The product picture: the one shipped in the APK, or one fetched for a
/// product that was added after this build.
class _GiftImage extends StatelessWidget {
  const _GiftImage({required this.product});
  final GiftProduct product;

  static const _fallback = Center(child: Icon(CupertinoIcons.gift, size: 40));

  @override
  Widget build(BuildContext context) {
    final url = product.imageUrl;
    if (url == null) {
      return Image.asset(product.asset,
          fit: BoxFit.contain,
          semanticLabel: product.name,
          errorBuilder: (_, __, ___) => _fallback);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      // No spinner: a grid of them is worse than a grid of quiet gaps.
      placeholder: (_, __) => const SizedBox(),
      // ⚠️ Falls back to the bundled asset before the icon — a row can carry
      // an image_url that is merely broken while the APK still has a good
      // picture for that id.
      errorWidget: (_, __, ___) => Image.asset(product.asset,
          fit: BoxFit.contain,
          semanticLabel: product.name,
          errorBuilder: (_, __, ___) => _fallback),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard(
      {required this.product,
      required this.saved,
      required this.onSave,
      required this.onView});
  final GiftProduct product;
  final bool saved;
  final VoidCallback onSave, onView;
  @override
  Widget build(BuildContext context) {
    final p = product;
    return Container(
        decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
              aspectRatio: 1,
              child: Stack(children: [
                // ⚠️ Bundled asset first, network only when the row carries
                // an image_url. A product added from the dashboard has no
                // place in the APK to keep a picture, and without this it
                // would show the placeholder icon forever.
                Positioned.fill(child: _GiftImage(product: p)),
                Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton.filledTonal(
                        tooltip: saved ? 'Unsave ${p.name}' : 'Save ${p.name}',
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.secondary),
                        onPressed: onSave,
                        icon: Icon(
                            saved
                                ? CupertinoIcons.heart_fill
                                : CupertinoIcons.heart,
                            size: 20))),
              ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: AppText.subtitle()),
                    const SizedBox(height: 4),
                    Text(p.merchant, style: AppText.caption()),
                    Text(p.category,
                        style: AppText.caption(AppColors.secondary)),
                    const SizedBox(height: 6),
                    Text(p.priceLabel, style: AppText.subtitle()),
                    if (p.voucher)
                      Text('After voucher', style: AppText.caption()),
                  ])),
          TextButton(onPressed: onView, child: const Text('Open Shopee')),
        ]));
  }
}
