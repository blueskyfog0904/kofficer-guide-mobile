import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import '../models/user_activity.dart';
import 'supabase_service.dart';
import 'restaurant_service.dart';

/// 사용자 프로필 모델
class UserProfile {
  final String id;
  final String? email;
  final String? nickname;
  final String? mobNickname;  // 사용자가 앱에서 설정한 닉네임
  final String? avatarUrl;
  final String? provider;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    this.email,
    this.nickname,
    this.mobNickname,
    this.avatarUrl,
    this.provider,
    required this.createdAt,
  });

  /// 표시용 닉네임 (mob_nickname 우선, 없으면 nickname)
  String? get displayNickname => mobNickname ?? nickname;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['user_id'] ?? '',
      email: json['email'],
      nickname: json['nickname'],
      mobNickname: json['mob_nickname'],
      avatarUrl: json['avatar_url'],
      provider: json['provider'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class UserService {
  final SupabaseClient _client = SupabaseService().client;

  String _generateRandomNickname() {
    final random = Random();
    final suffix = random.nextInt(9000) + 1000;
    return '맛집탐험가_$suffix';
  }

  String _generateRandomEmail(String userId) {
    final shortId = userId.substring(0, 8);
    return 'apple_$shortId@kofficer.app';
  }

  Future<bool> createAppleProfile(String userId) async {
    try {
      final nickname = _generateRandomNickname();
      final email = _generateRandomEmail(userId);

      await _client.from('profiles').insert({
        'user_id': userId,
        'email': email,
        'nickname': nickname,
        'mob_nickname': nickname,
        'provider': 'apple',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ Apple 프로필 생성 완료: $nickname');
      return true;
    } catch (e) {
      print('Error creating Apple profile: $e');
      return false;
    }
  }

  Future<bool> saveTermsConsent(String userId) async {
    try {
      final termsResponse = await _client
          .from('terms_versions')
          .select('id, version')
          .eq('is_required', true);

      final terms = termsResponse as List;
      
      for (final term in terms) {
        await _client.from('user_terms_consents').insert({
          'user_id': userId,
          'terms_id': term['id'],
          'version': term['version'],
          'agreed': true,
          'agreed_at': DateTime.now().toIso8601String(),
        });
      }

      print('✅ 약관 동의 저장 완료');
      return true;
    } catch (e) {
      print('Error saving terms consent: $e');
      return false;
    }
  }

  // 사용자 프로필 조회 (user_id로)
  Future<UserProfile?> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return UserProfile.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }

  // 사용자 프로필 조회 (kakao_id로)
  Future<UserProfile?> getProfileByKakaoId(String kakaoId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('kakao_id', kakaoId)
          .maybeSingle();

      if (response != null) {
        return UserProfile.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error fetching profile by kakao_id: $e');
      return null;
    }
  }

  // 닉네임 업데이트 (kakao_id로) - nickname과 mob_nickname 모두 업데이트
  Future<bool> updateNicknameByKakaoId(String kakaoId, String nickname) async {
    try {
      await _client
          .from('profiles')
          .update({
            'nickname': nickname,
            'mob_nickname': nickname,  // 사용자가 변경한 닉네임도 저장
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('kakao_id', kakaoId);
      return true;
    } catch (e) {
      print('Error updating nickname by kakao_id: $e');
      return false;
    }
  }

  // 사용자명(닉네임) 업데이트 - nickname과 mob_nickname 모두 업데이트
  Future<bool> updateNickname(String userId, String nickname) async {
    try {
      await _client
          .from('profiles')
          .update({
            'nickname': nickname,
            'mob_nickname': nickname,  // 사용자가 변경한 닉네임도 저장
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      return true;
    } catch (e) {
      print('Error updating nickname: $e');
      return false;
    }
  }

  // 즐겨찾기 목록 조회
  Future<List<Favorite>> getFavorites(String userId) async {
    try {
      final response = await _client
          .from('favorites')
          .select('*, restaurant:restaurants(*)') // restaurant 정보 조인
          .eq('user_id', userId)
          .order('created_at', ascending: false);
          
      return (response as List).map((json) => Favorite.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching favorites: $e');
      return [];
    }
  }

  // 리뷰 목록 조회
  Future<List<Review>> getReviews(String userId) async {
    try {
      final response = await _client
          .from('reviews')
          .select('*, restaurant:restaurants(*), review_photos(*)') // restaurant와 사진 정보 조인
          .eq('user_id', userId)
          .order('created_at', ascending: false);
          
      return (response as List).map((json) => Review.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching reviews: $e');
      return [];
    }
  }

  // 즐겨찾기 여부 확인
  Future<bool> isFavorite(String userId, String restaurantId) async {
    try {
      final response = await _client
          .from('favorites')
          .select('id')
          .eq('user_id', userId)
          .eq('restaurant_id', restaurantId)
          .maybeSingle();
          
      return response != null;
    } catch (e) {
      return false;
    }
  }

  // 즐겨찾기 토글
  Future<bool> toggleFavorite(String userId, String restaurantId) async {
    try {
      final exists = await isFavorite(userId, restaurantId);
      
      if (exists) {
        await _client
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('restaurant_id', restaurantId);
        return false; // 삭제됨
      } else {
        await _client.from('favorites').insert({
          'user_id': userId,
          'restaurant_id': restaurantId,
        });
        return true; // 추가됨
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      rethrow;
    }
  }

  // 즐겨찾기 삭제
  Future<bool> deleteFavorite(String favoriteId) async {
    try {
      await _client
          .from('favorites')
          .delete()
          .eq('id', favoriteId);
      return true;
    } catch (e) {
      print('Error deleting favorite: $e');
      return false;
    }
  }

  // 댓글 목록 조회 (게시판 댓글)
  Future<List<Comment>> getComments(String userId) async {
    try {
      final response = await _client
          .from('comments')
          .select('*, post:posts(id, title, board_type)')
          .eq('user_id', userId)
          .neq('status', 'deleted')
          .order('created_at', ascending: false);

      return (response as List).map((json) => Comment.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching comments: $e');
      return [];
    }
  }

  // 리뷰 삭제 (완전 삭제: Storage, restaurant_photos, primary_photo_url 모두 정리)
  Future<bool> deleteReview(String reviewId) async {
    try {
      // 1. 리뷰 정보 조회 (restaurant_id, user_id 필요)
      final reviewResponse = await _client
          .from('reviews')
          .select('restaurant_id, user_id')
          .eq('id', reviewId)
          .maybeSingle();
      
      if (reviewResponse == null) {
        print('❌ Review not found: $reviewId');
        return false;
      }
      
      final restaurantId = reviewResponse['restaurant_id']?.toString() ?? '';
      final userId = reviewResponse['user_id']?.toString() ?? '';
      
      // 2. restaurant_service의 완전 삭제 함수 호출
      final restaurantService = RestaurantService();
      await restaurantService.deleteReview(
        reviewId: reviewId,
        userId: userId,
        restaurantId: restaurantId,
      );
      
      print('✅ Review $reviewId deleted completely (Storage, restaurant_photos, primary_photo_url all cleaned)');
      return true;
    } catch (e) {
      print('Error deleting review: $e');
      return false;
    }
  }

  // 리뷰 수정
  Future<bool> updateReview(String reviewId, {int? rating, String? content}) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (rating != null) {
        updateData['rating'] = rating;
      }
      if (content != null) {
        updateData['content'] = content;
      }
      await _client
          .from('reviews')
          .update(updateData)
          .eq('id', reviewId);
      return true;
    } catch (e) {
      print('Error updating review: $e');
      return false;
    }
  }

  // 댓글 삭제 (소프트 삭제)
  Future<bool> deleteComment(String commentId) async {
    try {
      await _client
          .from('comments')
          .update({
            'status': 'deleted',
            'deleted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', commentId);
      return true;
    } catch (e) {
      print('Error deleting comment: $e');
      return false;
    }
  }

  // 사용자 관련 데이터 모두 삭제 (계정 삭제 전 호출)
  Future<bool> deleteUserData(String userId) async {
    try {
      // 1. 즐겨찾기 삭제
      await _client.from('favorites').delete().eq('user_id', userId);
      
      // 2. 리뷰 삭제
      await _client.from('reviews').delete().eq('user_id', userId);
      
      // 3. 댓글 소프트 삭제
      await _client
          .from('comments')
          .update({
            'status': 'deleted',
            'deleted_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      
      // 4. 프로필 삭제
      await _client.from('profiles').delete().eq('user_id', userId);
      
      return true;
    } catch (e) {
      print('Error deleting user data: $e');
      return false;
    }
  }
}

