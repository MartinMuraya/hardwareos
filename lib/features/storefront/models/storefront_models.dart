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

class DeliveryZone {
  final String id;
  final String name;
  final double fee;

  DeliveryZone({required this.id, required this.name, required this.fee});

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    return DeliveryZone(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Local',
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'fee': fee,
  };
}

class StorefrontInfo {
  final String businessId;
  final String name;
  final String tenantSlug;
  final bool active;
  final String? logoUrl;
  final String? bannerUrl;
  final String? primaryColor; // Hex string e.g. "#FF0000"
  final String? whatsappNumber;
  final List<DeliveryZone> deliveryZones;

  StorefrontInfo({
    required this.businessId,
    required this.name,
    required this.tenantSlug,
    required this.active,
    this.logoUrl,
    this.bannerUrl,
    this.primaryColor,
    this.whatsappNumber,
    this.deliveryZones = const [],
  });

  factory StorefrontInfo.fromJson(Map<String, dynamic> json) {
    return StorefrontInfo(
      businessId: json['businessId'] as String,
      name: json['name'] as String,
      tenantSlug: json['tenantSlug'] as String,
      active: json['active'] as bool? ?? false,
      logoUrl: json['logoUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      primaryColor: json['primaryColor'] as String?,
      whatsappNumber: json['whatsappNumber'] as String?,
      deliveryZones: (json['deliveryZones'] as List<dynamic>?)?.map((e) => DeliveryZone.fromJson(Map<String, dynamic>.from(e as Map))).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'businessId': businessId,
    'name': name,
    'tenantSlug': tenantSlug,
    'active': active,
    'logoUrl': logoUrl,
    'bannerUrl': bannerUrl,
    'primaryColor': primaryColor,
    'whatsappNumber': whatsappNumber,
    'deliveryZones': deliveryZones.map((e) => e.toJson()).toList(),
  };
}
