import '../models/restaurant.dart';

class Favorite {
  final String id;
  final String userId;
  final String restaurantId;
  final DateTime createdAt;
  final Restaurant? restaurant;

  Favorite({
    required this.id,
    required this.userId,
    required this.restaurantId,
    required this.createdAt,
    this.restaurant,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      restaurantId: json['restaurant_id'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      restaurant: json['restaurant'] != null
          ? Restaurant.fromJson(json['restaurant'])
          : null,
    );
  }
}

class Review {
  final String id;
  final String userId;
  final String restaurantId;
  final int rating;
  final String? content;
  final DateTime createdAt;
  final Restaurant? restaurant;
  final List<ReviewPhotoSimple> photos;

  Review({
    required this.id,
    required this.userId,
    required this.restaurantId,
    required this.rating,
    this.content,
    required this.createdAt,
    this.restaurant,
    this.photos = const [],
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      restaurantId: json['restaurant_id'] ?? '',
      rating: json['rating'] ?? 0,
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      restaurant: json['restaurant'] != null
          ? Restaurant.fromJson(json['restaurant'])
          : null,
      photos: (json['review_photos'] as List?)
          ?.map((e) => ReviewPhotoSimple.fromJson(e))
          .toList() ?? [],
    );
  }
}

/// 간단한 리뷰 사진 모델 (user_activity용)
class ReviewPhotoSimple {
  final String id;
  final String photoUrl;
  final int displayOrder;

  ReviewPhotoSimple({
    required this.id,
    required this.photoUrl,
    this.displayOrder = 0,
  });

  factory ReviewPhotoSimple.fromJson(Map<String, dynamic> json) {
    return ReviewPhotoSimple(
      id: json['id']?.toString() ?? '',
      photoUrl: json['photo_url'] ?? '',
      displayOrder: json['display_order'] ?? 0,
    );
  }
}

/// 게시판 댓글 모델
class Comment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final String status;
  final DateTime createdAt;
  final Post? post;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.status,
    required this.createdAt,
    this.post,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? '',
      postId: json['post_id'] ?? '',
      userId: json['user_id'] ?? '',
      content: json['content'] ?? '',
      status: json['status'] ?? 'published',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      post: json['post'] != null ? Post.fromJson(json['post']) : null,
    );
  }
}

/// 게시글 모델 (댓글 목록에서 사용)
class Post {
  final String id;
  final String title;
  final String boardType;

  Post({
    required this.id,
    required this.title,
    required this.boardType,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      boardType: json['board_type'] ?? 'free',
    );
  }

  String get boardTypeLabel {
    switch (boardType) {
      case 'notice':
        return '공지사항';
      case 'free':
        return '자유게시판';
      case 'suggestion':
        return '건의사항';
      default:
        return boardType;
    }
  }
}

