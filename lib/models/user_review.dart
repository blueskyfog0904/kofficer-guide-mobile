/// 사용자 리뷰 모델
class UserReview {
  final String id;
  final String restaurantId;
  final String userId;
  final int rating;
  final String? content;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final ReviewUser? user;
  final List<ReviewPhoto> photos;
  final int likeCount;
  final int dislikeCount;

  UserReview({
    required this.id,
    required this.restaurantId,
    required this.userId,
    required this.rating,
    this.content,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.user,
    this.photos = const [],
    this.likeCount = 0,
    this.dislikeCount = 0,
  });

  factory UserReview.fromJson(Map<String, dynamic> json) {
    return UserReview(
      id: json['id']?.toString() ?? '',
      restaurantId: json['restaurant_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      rating: json['rating'] ?? 0,
      content: json['content'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      user: json['user'] != null 
          ? ReviewUser.fromJson(json['user']) 
          : null,
      photos: (json['photos'] as List?)
          ?.map((e) => ReviewPhoto.fromJson(e))
          .toList() ?? [],
      likeCount: json['like_count'] ?? 0,
      dislikeCount: json['dislike_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'user_id': userId,
      'rating': rating,
      'content': content,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// 리뷰 작성자 정보
class ReviewUser {
  final String id;
  final String? username;
  final String? nickname;
  final String? profileImageUrl;

  ReviewUser({
    required this.id,
    this.username,
    this.nickname,
    this.profileImageUrl,
  });

  factory ReviewUser.fromJson(Map<String, dynamic> json) {
    return ReviewUser(
      id: json['id']?.toString() ?? '',
      username: json['username'],
      nickname: json['nickname'],
      profileImageUrl: json['profile_image_url'] ?? json['avatar_url'],
    );
  }

  /// 표시할 이름 (nickname > username > 익명)
  String get displayName => nickname ?? username ?? '익명';
}

/// 리뷰 사진
class ReviewPhoto {
  final String id;
  final String reviewId;
  final String photoUrl;
  final String? description;
  final int displayOrder;
  final DateTime? uploadedAt;

  ReviewPhoto({
    required this.id,
    required this.reviewId,
    required this.photoUrl,
    this.description,
    this.displayOrder = 0,
    this.uploadedAt,
  });

  factory ReviewPhoto.fromJson(Map<String, dynamic> json) {
    return ReviewPhoto(
      id: json['id']?.toString() ?? '',
      reviewId: json['review_id']?.toString() ?? '',
      photoUrl: json['photo_url'] ?? '',
      description: json['description'],
      displayOrder: json['display_order'] ?? 0,
      uploadedAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'review_id': reviewId,
      'photo_url': photoUrl,
      'description': description,
      'display_order': displayOrder,
      'created_at': uploadedAt?.toIso8601String(),
    };
  }
}

/// 리뷰 요약 정보
class ReviewSummary {
  final int totalReviews;
  final double? averageRating;
  final Map<int, int> ratingDistribution;

  ReviewSummary({
    required this.totalReviews,
    this.averageRating,
    this.ratingDistribution = const {},
  });

  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    // rating_distribution 파싱
    final Map<int, int> distribution = {};
    if (json['rating_distribution'] != null) {
      final dist = json['rating_distribution'] as Map<String, dynamic>;
      dist.forEach((key, value) {
        distribution[int.tryParse(key) ?? 0] = value ?? 0;
      });
    }

    return ReviewSummary(
      totalReviews: json['total_reviews'] ?? 0,
      averageRating: json['average_rating']?.toDouble(),
      ratingDistribution: distribution,
    );
  }
}

