import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/gift_catalog.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/ios_back_button.dart';

const _products = giftProducts;

class GiftsScreen extends StatefulWidget {
  const GiftsScreen({super.key, this.occasion, this.openLink});
  final String? occasion;
  final Future<bool> Function(Uri)? openLink;
  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> {
  final _search = TextEditingController();
  final _saved = <int>{};
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
    final products = [
      for (var i = 0; i < _products.length; i++)
        if (_products[i].matches(
                query: query,
                recipient: _recipient,
                category: _category,
                budget: _budget) &&
            (!_savedOnly || _saved.contains(i)))
          i
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
                ..._products.map((p) => p.category).toSet()
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
                                    photo: products[j],
                                    saved: _saved.contains(products[j]),
                                    onView: () =>
                                        _openProduct(_products[products[j]]),
                                    onSave: () => setState(() {
                                          final id = products[j];
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

class _ProductCard extends StatelessWidget {
  const _ProductCard(
      {required this.photo,
      required this.saved,
      required this.onSave,
      required this.onView});
  final int photo;
  final bool saved;
  final VoidCallback onSave, onView;
  @override
  Widget build(BuildContext context) {
    final p = _products[photo];
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
                Positioned.fill(
                    child: Image.asset(p.asset,
                        fit: BoxFit.contain,
                        semanticLabel: p.name,
                        errorBuilder: (_, __, ___) => const Center(
                            child: Icon(CupertinoIcons.gift, size: 40)))),
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
