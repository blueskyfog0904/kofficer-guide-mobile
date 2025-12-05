class Restaurant {
  final String id;
  final String name;
  final String? title;
  final String? address;
  final String? roadAddress;
  final double? latitude;
  final double? longitude;
  final String? category;
  final String? subCategory;
  final String regionId;
  final String? subAdd1;
  final String? subAdd2;
  final String? primaryPhotoUrl;
  final bool isActive;

  // 확장 필드 (RestaurantWithStats)
  final int? reviewCount;
  final double? avgRating;
  final int? visitCount;
  final int? rankPosition;
  final List<RestaurantImage>? images;

  Restaurant({
    required this.id,
    required this.name,
    this.title,
    this.address,
    this.roadAddress,
    this.latitude,
    this.longitude,
    this.category,
    this.subCategory,
    required this.regionId,
    this.subAdd1,
    this.subAdd2,
    this.primaryPhotoUrl,
    required this.isActive,
    this.reviewCount,
    this.avgRating,
    this.visitCount,
    this.rankPosition,
    this.images,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      title: json['title'],
      address: json['address'],
      roadAddress: json['road_address'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      category: json['category'],
      subCategory: json['sub_category'],
      regionId: json['region_id'] ?? '',
      subAdd1: json['sub_add1'],
      subAdd2: json['sub_add2'],
      primaryPhotoUrl: json['primary_photo_url'],
      isActive: json['is_active'] ?? false,
      reviewCount: json['review_count'],
      avgRating: json['avg_rating']?.toDouble(),
      visitCount: json['visit_count'],
      rankPosition: json['rank_position'],
      images: (json['images'] as List?)
          ?.map((e) => RestaurantImage.fromJson(e))
          .toList(),
    );
  }
}

class RestaurantImage {
  final String id;
  final String imageUrl;
  final String imageType;
  final String? altText;
  final int displayOrder;

  RestaurantImage({
    required this.id,
    required this.imageUrl,
    required this.imageType,
    this.altText,
    required this.displayOrder,
  });

  factory RestaurantImage.fromJson(Map<String, dynamic> json) {
    return RestaurantImage(
      id: json['id'] ?? '',
      imageUrl: json['image_url'] ?? '',
      imageType: json['image_type'] ?? 'main',
      altText: json['alt_text'],
      displayOrder: json['display_order'] ?? 0,
    );
  }
}
