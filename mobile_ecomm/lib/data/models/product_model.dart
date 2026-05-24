class Product {
  final String id;
  final String slug;
  final String name;
  final String category;
  final String? subcategory;
  final List<String> categories;
  final String description;
  final List<String> images;
  final List<ProductVariation> variations;
  final double price;
  final double? salePrice;
  final String? brand;
  final String? productCondition;
  final double? weightKg;
  final String? material;
  final String? careInstructions;
  final List<String>? tags;
  final double rating;
  final int reviewCount;
  final int itemsSold;
  final String sellerId;
  final String sellerName;
  final String? sellerLogo;
  final bool visibility;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.slug,
    required this.name,
    required this.category,
    this.subcategory,
    required this.categories,
    required this.description,
    required this.images,
    required this.variations,
    required this.price,
    this.salePrice,
    this.brand,
    this.productCondition,
    this.weightKg,
    this.material,
    this.careInstructions,
    this.tags,
    this.rating = 0,
    this.reviewCount = 0,
    this.itemsSold = 0,
    required this.sellerId,
    required this.sellerName,
    this.sellerLogo,
    this.visibility = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Merge all image sources (images[], image_url, media[]) for gallery support
    final images = <String>[];
    void addImage(String? path) {
      final value = path?.trim() ?? '';
      if (value.isNotEmpty && !images.contains(value)) {
        images.add(value);
      }
    }

    if (json['images'] != null) {
      for (final img in json['images'] as List) {
        addImage(img?.toString());
      }
    }
    addImage(json['image_url']?.toString());
    addImage(json['imageUrl']?.toString());

    if (json['media'] != null) {
      for (final item in json['media'] as List) {
        if (item is! Map) continue;
        final type = item['media_type']?.toString() ?? '';
        if (type.isNotEmpty && type != 'image') continue;
        addImage(item['path']?.toString());
        addImage(item['url']?.toString());
        addImage(item['image_url']?.toString());
      }
    }

    return Product(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      subcategory: json['subcategory']?.toString(),
      categories: List<String>.from(json['categories'] ?? []),
      description: json['description']?.toString() ?? '',
      images: images,
      variations: (json['variations'] as List?)
              ?.map((v) => ProductVariation.fromJson(v))
              .toList() ??
          [],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      salePrice: (json['salePrice'] as num?)?.toDouble() ??
          (json['sale_price'] as num?)?.toDouble(),
      brand: json['brand']?.toString(),
      productCondition: json['productCondition']?.toString() ??
          json['product_condition']?.toString(),
      weightKg: (json['weightKg'] as num?)?.toDouble() ??
          (json['weight_kg'] as num?)?.toDouble(),
      material: json['material']?.toString(),
      careInstructions: json['careInstructions']?.toString() ??
          json['care_instructions']?.toString(),
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ??
          (json['review_count'] as num?)?.toInt() ??
          0,
      itemsSold: _parseItemsSold(json),
      sellerId: json['sellerId']?.toString() ?? json['store_id']?.toString() ?? '',
      sellerName: json['sellerName']?.toString() ?? json['seller_name']?.toString() ?? '',
      sellerLogo: json['sellerLogo']?.toString() ?? json['seller_logo']?.toString(),
      visibility: json['visibility'] ?? json['is_live'] ?? true,
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDateTime(json['updatedAt'] ?? json['updated_at']),
    );
  }

  double get currentPrice => salePrice ?? price;
  int get discountPercent => salePrice != null && salePrice! < price
      ? ((1 - salePrice! / price) * 100).round()
      : 0;
  int get totalStock => variations.fold(0, (sum, v) => sum + v.inventory);
}

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  try {
    return DateTime.parse(value.toString());
  } catch (_) {
    return DateTime.now();
  }
}

int _parseItemsSold(Map<String, dynamic> json) {
  const keys = [
    'itemsSold',
    'items_sold',
    'sold',
    'total_sold',
    'sales_count',
    'units_sold',
    'order_count',
  ];
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  return 0;
}

class ProductVariation {
  final String id;
  final String size;
  final String color;
  final String? colorHex;
  final String sku;
  final int inventory;
  final double? price;

  ProductVariation({
    required this.id,
    required this.size,
    required this.color,
    this.colorHex,
    required this.sku,
    required this.inventory,
    this.price,
  });

  factory ProductVariation.fromJson(Map<String, dynamic> json) {
    return ProductVariation(
      id: json['id']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      colorHex: json['colorHex']?.toString() ?? json['color_hex']?.toString(),
      sku: json['sku']?.toString() ?? '',
      inventory: json['inventory'] ?? 0,
      price: (json['price'] as num?)?.toDouble(),
    );
  }
}

class CarouselSlide {
  final int id;
  final String title;
  final String subtitle;
  final String description;
  final String image;
  final String cta;
  final String href;

  CarouselSlide({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.image,
    required this.cta,
    required this.href,
  });

  static List<CarouselSlide> get mockSlides => [
    CarouselSlide(
      id: 1,
      title: 'Summer Collection',
      subtitle: 'New Arrivals',
      description: 'Discover the latest trends for the season',
      image: 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=800',
      cta: 'Shop Now',
      href: '/search?category=dress-skirts',
    ),
    CarouselSlide(
      id: 2,
      title: 'Elegant Evening Wear',
      subtitle: 'Special Occasion',
      description: 'Make a statement at your next event',
      image: 'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=800',
      cta: 'Explore',
      href: '/search?category=dress-skirts',
    ),
    CarouselSlide(
      id: 3,
      title: 'Casual Comfort',
      subtitle: 'Everyday Style',
      description: 'Comfortable fashion for daily wear',
      image: 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=800',
      cta: 'Browse',
      href: '/search?category=tops-blouses',
    ),
  ];
}
