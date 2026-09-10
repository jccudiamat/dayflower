# Static gift catalog

Collected from public Shopee Philippines product pages on 10 September 2026.
`gift_catalog.dart` stores each original listing URL, seller, observed PHP price,
and source image URL. Short display titles and recipient categories are editorial.
Seller photos are bundled under `assets/images/gifts/` and retain their branding.

This collection has no runtime scraper, inventory sync, affiliate parameters,
checkout, or payment processing. The app opens the original HTTPS listing in an
external application. Purchases, personalization, stock and shipping are handled
by the seller on Shopee. Prices are dated observations, not live offers; the
necklace price is explicitly marked as conditional on a voucher. Budget filters
use the upper end of observed variant ranges.

To refresh, revisit each listing, replace unavailable products, update its price
and photo, and change `giftCatalogChecked`. Keep the collection varied. Do not
substitute generated photos or invented prices for inaccessible product details.

Verification: `flutter test test/gift_catalog_test.dart test/gifts_navigation_test.dart`.
The widget tests cover narrow screens, search, saving, navigation, and failed
external links. The catalog test checks source destinations, assets and filters.
