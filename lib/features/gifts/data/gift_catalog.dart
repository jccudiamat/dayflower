/// Static Shopee Philippines snapshot collected on 10 September 2026.
/// Prices are observations, not live quotes. URLs link to the original sellers.
class GiftProduct {
  const GiftProduct(
      {required this.id,
      required this.name,
      required this.merchant,
      required this.category,
      required this.price,
      this.priceMax,
      this.voucher = false,
      required this.recipients,
      required this.url,
      required this.imageSource});
  final String id, name, merchant, category, url, imageSource;
  final int price;
  final int? priceMax;
  final bool voucher;
  final List<String> recipients;
  String get asset => 'assets/images/gifts/$id.jpg';
  String get priceLabel => priceMax == null ? '₱$price' : '₱$price–₱$priceMax';
  bool matches(
          {String query = '',
          String recipient = 'All',
          String category = 'All types',
          int? budget}) =>
      '$name $merchant ${this.category}'
          .toLowerCase()
          .contains(query.trim().toLowerCase()) &&
      (recipient == 'All' || recipients.contains(recipient)) &&
      (category == 'All types' || category == this.category) &&
      (budget == null || (priceMax ?? price) <= budget);
}

const giftCatalogChecked = '10 Sep 2026';
const giftProducts = <GiftProduct>[
  GiftProduct(
      id: "crochet-bouquet",
      name: "Crochet flower bouquet",
      merchant: "BETTER LIFE",
      category: "Flowers",
      price: 86,
      priceMax: 116,
      recipients: ["Partner", "Family", "Friends"],
      url:
          "https://shopee.ph/Handmade-Knitted-Crochet-Flowers-Home-Ornaments-PVC-LED-Light-Bouquet-Wedding-Valentine's-Day-Gift-i.975503035.42025448680",
      imageSource:
          "https://down-ph.img.susercontent.com/file/sg-11134201-825aq-mg4t1ucgxxjd60"),
  GiftProduct(
      id: "couple-mugs",
      name: "Personalized couple mugs",
      merchant: "KST Merchandising",
      category: "Home",
      price: 990,
      recipients: ["Partner", "Family"],
      url:
          "https://shopee.ph/Personalized-Couple-Mug-with-Lid-Stirrer-Spoon-Gift-Box-i.380284623.28921400102",
      imageSource:
          "https://down-ph.img.susercontent.com/file/ph-11134207-7rash-m4429yrgsiy338"),
  GiftProduct(
      id: "bar-necklace",
      name: "Engraved bar necklace",
      merchant: "Vnox Global Store",
      category: "Jewelry",
      price: 160,
      voucher: true,
      recipients: ["Partner", "Family", "Friends"],
      url:
          "https://shopee.ph/Vnox-Personalized-Vertical-Bar-Pendant-Necklace-4-Sides-Customized-Name-Box-Chain-Necklace-Jewelry-Gift-for-Women-Men-i.235558693.17642847769",
      imageSource:
          "https://down-ph.img.susercontent.com/file/sg-11134201-7raui-mb50pth4x3tc9a"),
  GiftProduct(
      id: "coffee-set",
      name: "French press coffee set",
      merchant: "Kapeakita",
      category: "Coffee",
      price: 376,
      priceMax: 401,
      recipients: ["Partner", "Family", "Friends"],
      url:
          "https://shopee.ph/COFFEE-GIFT-SET-(French-Press-350ml-Coffee-Ground)-KAPEAKITA-i.45615137.26738387885",
      imageSource:
          "https://down-ph.img.susercontent.com/file/ph-11134207-7ra0j-mbtvzhryrgipfc"),
  GiftProduct(
      id: "mini-album",
      name: "Mini photo album keychain",
      merchant: "mianhae.ph",
      category: "Photo keepsakes",
      price: 85,
      recipients: ["Partner", "Family", "Friends"],
      url:
          "https://shopee.ph/Customizable-Mini-Photo-Album-Keychain-Valentines-Gift-with-Box-(16-photos)-i.517192411.42578518616",
      imageSource:
          "https://down-ph.img.susercontent.com/file/ph-11134207-81ztg-mktd47sp9p1g9d"),
  GiftProduct(
      id: "soy-candle",
      name: "Scented soy tin candle",
      merchant: "papeldesarapen",
      category: "Self-care",
      price: 165,
      recipients: ["Partner", "Family", "Friends"],
      url:
          "https://shopee.ph/Witty-Tin-Candle-Premium-Soy-Scented-Candle-in-Tin-Can-for-Gift-Souvenir-Wedding-Giveaway-i.378827485.40407253901",
      imageSource:
          "https://down-ph.img.susercontent.com/file/ph-11134207-81zth-mfszfg577xfy8f"),
  GiftProduct(
      id: "flower-blocks",
      name: "Build-your-own flower bouquet",
      merchant: "SHL-AB",
      category: "Activities",
      price: 30,
      priceMax: 129,
      recipients: ["Partner", "Friends"],
      url:
          "https://shopee.ph/Eternal-Mini-Flower-Building-Blocks-Bouquet-Assembling-Room-Decor-Educational-Toys-For-Gifts-i.1469223094.28589623849",
      imageSource:
          "https://down-ph.img.susercontent.com/file/sg-11134201-7rdvd-md5y1igntflofd"),
  GiftProduct(
      id: "anniversary-card",
      name: "Anniversary greeting card",
      merchant: "papeldesarapen",
      category: "Cards",
      price: 79,
      recipients: ["Partner"],
      url:
          "https://shopee.ph/Papeldesarapen-Happy-Anniversary-Card-Sweet-7-Designs-Love-Card-Valentine-Greeting-Card-Partner-i.378827485.13775300723",
      imageSource:
          "https://down-ph.img.susercontent.com/file/ph-11134207-7r98r-loi1mjmuk5z9b1"),
  GiftProduct(
      id: "photostrip-keychain",
      name: "Photo strip acrylic keychain",
      merchant: "mianhae.ph",
      category: "Photo keepsakes",
      price: 69,
      recipients: ["Partner", "Friends"],
      url:
          "https://shopee.ph/-1PC-PHOTOSTRIP-PHOTOBOOTH-ACRYLIC-KEYCHAINS-VALENTINES-GIFTS-i.517192411.26136149353",
      imageSource:
          "https://down-ph.img.susercontent.com/file/ph-11134207-7rasg-m9fih63c43a636"),
];
