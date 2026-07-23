class StorefrontProduct {
  final String id;
  final String name;
  final String category;
  final double sellingPrice;
  final List<String> images;
  final String description;
  final bool inStock;

  StorefrontProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.sellingPrice,
    required this.images,
    required this.description,
    required this.inStock,
  });

  factory StorefrontProduct.fromJson(Map<String, dynamic> json) {
    return StorefrontProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'General',
      sellingPrice: (json['sellingPrice'] as num).toDouble(),
      images: (json['images'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      description: json['description'] as String? ?? '',
      inStock: json['inStock'] as bool? ?? false,
    );
  }
}

class StorefrontCartItem {
  final StorefrontProduct product;
  int quantity;

  StorefrontCartItem({
    required this.product,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
    'product': {
      'id': product.id,
      'name': product.name,
      'category': product.category,
      'sellingPrice': product.sellingPrice,
      'images': product.images,
      'description': product.description,
      'inStock': product.inStock,
    },
    'quantity': quantity,
  };

  factory StorefrontCartItem.fromJson(Map<String, dynamic> json) {
    return StorefrontCartItem(
      product: StorefrontProduct.fromJson(Map<String, dynamic>.from(json['product'] as Map)),
      quantity: json['quantity'] as int,
    );
  }
}

class StorefrontInfo {
  final String businessId;
  final String name;
  final String tenantSlug;
  final bool active;

  StorefrontInfo({
    required this.businessId,
    required this.name,
    required this.tenantSlug,
    required this.active,
  });

  factory StorefrontInfo.fromJson(Map<String, dynamic> json) {
    return StorefrontInfo(
      businessId: json['businessId'] as String,
      name: json['name'] as String,
      tenantSlug: json['tenantSlug'] as String,
      active: json['active'] as bool,
    );
  }
}
