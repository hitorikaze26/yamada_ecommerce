import 'package:flutter/material.dart';

/// Boutique-wide product categories (seller registration + buyer discovery).
class Category {
  final String id;
  final String name;
  final IconData icon;
  final String? imageUrl;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    this.imageUrl,
  });

  static const List<Category> categories = [
    Category(
      id: 'dress-skirts',
      name: 'Dresses & Skirts',
      icon: Icons.checkroom_outlined,
    ),
    Category(
      id: 'tops-blouses',
      name: 'Tops & Blouses',
      icon: Icons.woman_outlined,
    ),
    Category(
      id: 'activewear',
      name: 'Activewear & Yoga Pants',
      icon: Icons.fitness_center_outlined,
    ),
    Category(
      id: 'lingerie-sleepwear',
      name: 'Lingerie & Sleepwear',
      icon: Icons.nightlight_outlined,
    ),
    Category(
      id: 'jackets-coats',
      name: 'Jackets & Coats',
      icon: Icons.layers_outlined,
    ),
    Category(
      id: 'accessories-shoes',
      name: 'Shoes & Accessories',
      icon: Icons.shopping_bag_outlined,
    ),
  ];

  /// Maps legacy single-category ids to the combined taxonomy.
  static const Map<String, String> _legacyIdToId = {
    'dresses': 'dress-skirts',
    'dress': 'dress-skirts',
    'skirts': 'dress-skirts',
    'skirt': 'dress-skirts',
    'tops': 'tops-blouses',
    'top': 'tops-blouses',
    'blouses': 'tops-blouses',
    'blouse': 'tops-blouses',
    'bottoms': 'dress-skirts',
    'bottom': 'dress-skirts',
    'pants': 'activewear',
    'activewear-yoga': 'activewear',
    'lingerie': 'lingerie-sleepwear',
    'sleepwear': 'lingerie-sleepwear',
    'outerwear': 'jackets-coats',
    'jackets': 'jackets-coats',
    'coats': 'jackets-coats',
    'jacket': 'jackets-coats',
    'coat': 'jackets-coats',
    'accessories': 'accessories-shoes',
    'accessory': 'accessories-shoes',
    'shoes': 'accessories-shoes',
    'shoe': 'accessories-shoes',
  };

  static Category? findById(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final key = trimmed.toLowerCase();
    for (final c in categories) {
      if (c.id.toLowerCase() == key || c.name.toLowerCase() == key) {
        return c;
      }
    }

    final legacy = _legacyIdToId[key];
    if (legacy != null) {
      return categories.firstWhere((c) => c.id == legacy);
    }

    final slug = key.replaceAll(RegExp(r'[\s_]+'), '-');
    for (final c in categories) {
      if (c.id == slug) return c;
    }

    return null;
  }

  static String displayName(String raw) {
    final found = findById(raw);
    if (found != null) return found.name;

    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    return trimmed
        .split(RegExp(r'[\s_-]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  /// Subcategories per combined category (seller product form).
  static const Map<String, List<String>> subcategoriesById = {
    'dress-skirts': [
      'Maxi dresses', 'Midi dresses', 'Mini dresses', 'Bodycon dresses', 'A-line dresses',
      'Fit & flare dresses', 'Wrap dresses', 'Shift dresses', 'Shirt dresses', 'Slip dresses',
      'Halter dresses', 'Off-shoulder dresses', 'One-shoulder dresses', 'Cocktail dresses',
      'Evening gowns', 'Knit dresses', 'Sweater dresses', 'Denim dresses', 'Floral dresses',
      'Boho dresses', 'Sundresses', 'Skater dresses', 'Ruffle dresses', 'Tiered dresses',
      'Pleated dresses', 'Sequin dresses', 'Lace dresses', 'Satin/silk dresses',
      'Formal event dresses', 'Work/office dresses', 'Maternity dresses',
      'Maxi skirts', 'Midi skirts', 'Mini skirts', 'A-line skirts', 'Pencil skirts',
      'Pleated skirts', 'Skater skirts', 'Wrap skirts', 'Asymmetrical skirts',
      'Cargo skirts', 'Denim skirts', 'Satin skirts', 'Tulle skirts', 'Leather skirts',
    ],
    'tops-blouses': [
      'Crop tops', 'Tank tops / sleeveless tops', 'Tube tops', 'Camisoles', 'Basic tees',
      'Fitted tees', 'Oversized tees', 'Blouses (general)', 'Button-down blouses',
      'Ruffle blouses', 'Peplum tops', 'Off-shoulder tops', 'One-shoulder tops',
      'Halter tops', 'Square-neck tops', 'V-neck tops', 'Collared tops', 'Graphic tees',
      'Knit tops', 'Sweaters', 'Cardigans (thin/lightweight)', 'Wrap tops',
      'Satin/silk tops', 'Lace tops', 'Mesh tops', 'Sheer tops', 'Bodysuits',
      'Corset tops', 'Tube corsets', 'Tunics', 'Long-sleeve tops',
      'Puff-sleeve tops', 'Balloon-sleeve tops',
    ],
    'activewear': [
      'Sports bras', 'High-impact sports bras', 'Medium-impact sports bras',
      'Low-impact sports bras', 'Compression tops', 'Dry-fit tops', 'Workout tank tops',
      'Long-sleeve active tops', 'Yoga tees', 'Lightweight hoodies', 'Zip-up active jackets',
      'Yoga pants (general)', 'High-waisted yoga pants', 'Flare yoga pants',
      'Compression leggings', 'Seamless leggings', 'Printed leggings', 'Running leggings',
      'Biker shorts', 'Running shorts', 'Skort activewear', 'Joggers', 'Sweatpants',
      'Gym sets / co-ords', 'Yoga & Athleisure Sets',
    ],
    'lingerie-sleepwear': [
      'Bras', 'Everyday bras', 'Push-up bras', 'T-shirt bras', 'Bandeau bras',
      'Strapless bras', 'Bralettes', 'Lace bras', 'Sports bras (lingerie)',
      'Wire-free bras', 'Underwire bras', 'Panties', 'Bikini panties', 'Hipster panties',
      'High-waisted panties', 'Thongs', 'Seamless panties', 'Lace panties',
      'Cotton basic panties', 'Shapewear bodysuits', 'Shapewear shorts', 'Waist cinchers',
      'Camisole lingerie', 'Babydolls', 'Chemise', 'Corset lingerie', 'Robes',
      'Satin robes', 'Silk robes', 'Pajama sets (shorts)', 'Pajama sets (pants)',
      'Nightgowns', 'Sleep shirts', 'Satin sleepwear', 'Fluffy sleepwear', 'Thermal sleepwear',
    ],
    'jackets-coats': [
      'Denim jackets', 'Cropped denim jackets', 'Oversized denim jackets',
      'Leather jackets', 'Faux-leather jackets', 'Bomber jackets', 'Windbreakers',
      'Hooded jackets', 'Zip-up hoodies', 'Pullover hoodies', 'Knit cardigans',
      'Long cardigans', 'Blazers', 'Oversized blazers', 'Fitted blazers',
      'Trench coats', 'Wool coats', 'Puffer jackets', 'Light puffer coats',
      'Parkas', 'Raincoats', 'Varsity jackets', 'Quilted jackets',
      'Sherpa jackets', 'Faux fur coats',
    ],
    'accessories-shoes': [
      'Sneakers', 'Running shoes', 'Slip-on sneakers', 'Sandals', 'Flat sandals',
      'Strappy sandals', 'Slides', 'Wedge sandals', 'Heels', 'Stilettos', 'Block heels',
      'Wedge heels', 'Kitten heels', 'Platform heels', 'Boots', 'Ankle boots',
      'Knee-high boots', 'Chelsea boots', 'Combat boots', 'Loafers', 'Ballet flats',
      'Mules', 'Accessories', 'Handbags', 'Shoulder bags', 'Tote bags', 'Crossbody bags',
      'Mini bags', 'Wallets', 'Belts', 'Sunglasses', 'Scarves',
      'Hair accessories (clips, scrunchies)', 'Hats (bucket, baseball cap, sun hat)',
      'Jewelry', 'Earrings', 'Necklaces', 'Bracelets', 'Rings',
    ],
  };
}
