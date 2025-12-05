import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';
import '../models/user_review.dart';
import 'supabase_service.dart';

class RestaurantService {
  final SupabaseClient _client = SupabaseService().client;

  Future<List<Restaurant>> searchRestaurants({
    String? keyword,
    String? regionId,
    int limit = 1000,
    int offset = 0,
  }) async {
    var query = _client.from('restaurants').select();

    // 활성화된 식당만 조회
    query = query.eq('is_active', true);

    if (keyword != null && keyword.isNotEmpty) {
      query = query.ilike('name', '%$keyword%');
    }

    // region_id 파싱: "시도|시군구" 형식
    if (regionId != null && regionId.isNotEmpty) {
      if (regionId.contains('|')) {
        final parts = regionId.split('|');
        if (parts.length >= 2) {
          query = query.eq('sub_add1', parts[0]).eq('sub_add2', parts[1]);
          print('🔍 Searching: sub_add1=${parts[0]}, sub_add2=${parts[1]}');
        }
      } else {
        // 구분자가 없으면 sub_add2만 검색
        query = query.eq('sub_add2', regionId);
      }
    }

    // 정렬 및 페이지네이션을 한 번에 처리
    final response = await query
        .order('total_count', ascending: false)
        .range(offset, offset + limit - 1);
    
    final data = (response ?? []) as List;
    final restaurants = data.map((json) => Restaurant.fromJson(json)).toList();
    print('✅ Found ${restaurants.length} restaurants');
    
    return restaurants;
  }

  Future<Restaurant?> getRestaurantById(String id) async {
    try {
      final response = await _client
          .from('restaurants')
          .select('*, images:restaurant_images(*)') // 이미지 조인
          .eq('id', id)
          .single();
      
      return Restaurant.fromJson(response);
    } catch (e) {
      print('Error fetching restaurant detail: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getRegions() async {
    try {
      // RPC 함수 시도
      try {
        final rpcResponse = await _client.rpc('get_distinct_regions');
        if (rpcResponse != null) {
          print('✅ Using RPC get_distinct_regions');
          return List<Map<String, dynamic>>.from(rpcResponse);
        }
      } catch (rpcError) {
        print('⚠️ RPC get_distinct_regions not found, using fallback');
      }
      
      // Fallback: restaurants 테이블에서 직접 가져오기
      final response = await _client
          .from('restaurants')
          .select('sub_add1, sub_add2')
          .not('sub_add1', 'is', null)
          .not('sub_add2', 'is', null)
          .order('sub_add1', ascending: true)
          .order('sub_add2', ascending: true);
      
      // 중복 제거
      final uniqueMap = <String, Map<String, dynamic>>{};
      for (var r in response as List) {
        final key = '${r['sub_add1']}__${r['sub_add2']}';
        if (!uniqueMap.containsKey(key)) {
          uniqueMap[key] = {
            'id': key, // 고유 ID로 사용
            'sub_add1': r['sub_add1'],
            'sub_add2': r['sub_add2'],
          };
        }
      }
      
      final result = uniqueMap.values.toList();
      print('✅ Loaded ${result.length} unique regions from restaurants table');
      return result;
    } catch (e) {
      print('Error fetching regions: $e');
      return [];
    }
  }

  /// 리뷰 등록 (사진 포함)
  /// [photoUrls]: 업로드된 사진 URL 목록
  Future<String> submitReview({
    required String restaurantId,
    required String userId,
    required double rating,
    String? content,
    List<String>? photoUrls,
  }) async {
    try {
      // 1. 리뷰 데이터 삽입
      final reviewResponse = await _client.from('reviews').insert({
        'restaurant_id': restaurantId,
        'user_id': userId,
        'rating': rating,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      }).select('id').single();
      
      final reviewId = reviewResponse['id'].toString();
      print('✅ Review created with ID: $reviewId');
      
      // 2. 사진이 있으면 review_photos 테이블에 저장
      if (photoUrls != null && photoUrls.isNotEmpty) {
        final photoInserts = photoUrls.asMap().entries.map((entry) => {
          'review_id': reviewId,
          'photo_url': entry.value,
          'display_order': entry.key,
          'uploaded_at': DateTime.now().toIso8601String(),
        }).toList();
        
        await _client.from('review_photos').insert(photoInserts);
        print('✅ ${photoUrls.length} photos saved for review $reviewId');
      }
      
      return reviewId;
    } catch (e) {
      print('❌ Error submitting review: $e');
      rethrow;
    }
  }
  
  /// 음식점 리뷰 목록 조회
  Future<List<UserReview>> getRestaurantReviews(
    String restaurantId, {
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final offset = (page - 1) * limit;
      
      // v_reviews_detailed 뷰 사용 시도
      try {
        final response = await _client
            .from('v_reviews_detailed')
            .select()
            .eq('restaurant_id', restaurantId)
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);
        
        final reviews = (response as List).map((json) {
          // 뷰에서 user 정보 매핑
          final userJson = {
            'id': json['user_id'],
            'username': json['username'],
            'nickname': json['nickname'] ?? json['username'],
            'profile_image_url': json['avatar_url'],
          };
          json['user'] = userJson;
          return UserReview.fromJson(json);
        }).toList();
        
        // 각 리뷰의 사진 로드
        for (var i = 0; i < reviews.length; i++) {
          final photos = await getReviewPhotos(reviews[i].id);
          reviews[i] = UserReview(
            id: reviews[i].id,
            restaurantId: reviews[i].restaurantId,
            userId: reviews[i].userId,
            rating: reviews[i].rating,
            content: reviews[i].content,
            isActive: reviews[i].isActive,
            createdAt: reviews[i].createdAt,
            updatedAt: reviews[i].updatedAt,
            user: reviews[i].user,
            photos: photos,
            likeCount: reviews[i].likeCount,
            dislikeCount: reviews[i].dislikeCount,
          );
        }
        
        print('✅ Loaded ${reviews.length} reviews for restaurant $restaurantId');
        return reviews;
      } catch (viewError) {
        print('⚠️ v_reviews_detailed not available, using fallback: $viewError');
      }
      
      // Fallback: reviews 테이블 직접 조회
      final response = await _client
          .from('reviews')
          .select()
          .eq('restaurant_id', restaurantId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      
      final reviews = <UserReview>[];
      for (var json in response as List) {
        // 사용자 정보 조회
        try {
          final profileResponse = await _client
              .from('profiles')
              .select('user_id, nickname, avatar_url')
              .eq('user_id', json['user_id'])
              .maybeSingle();
          
          if (profileResponse != null) {
            json['user'] = {
              'id': profileResponse['user_id'],
              'nickname': profileResponse['nickname'],
              'profile_image_url': profileResponse['avatar_url'],
            };
          }
        } catch (_) {}
        
        // 사진 조회
        final photos = await getReviewPhotos(json['id'].toString());
        json['photos'] = photos.map((p) => p.toJson()).toList();
        
        reviews.add(UserReview.fromJson(json));
      }
      
      print('✅ Loaded ${reviews.length} reviews (fallback)');
      return reviews;
    } catch (e) {
      print('❌ Error fetching reviews: $e');
      return [];
    }
  }
  
  /// 리뷰 사진 조회
  Future<List<ReviewPhoto>> getReviewPhotos(String reviewId) async {
    try {
      final response = await _client
          .from('review_photos')
          .select()
          .eq('review_id', reviewId)
          .order('display_order', ascending: true);
      
      return (response as List)
          .map((json) => ReviewPhoto.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching review photos: $e');
      return [];
    }
  }
  
  /// 리뷰 요약 정보 조회
  Future<ReviewSummary> getRestaurantReviewSummary(String restaurantId) async {
    try {
      // 리뷰 통계 조회
      final response = await _client
          .from('reviews')
          .select('rating')
          .eq('restaurant_id', restaurantId);
      
      final ratings = (response as List).map((e) => e['rating'] as int).toList();
      
      if (ratings.isEmpty) {
        return ReviewSummary(totalReviews: 0);
      }
      
      // 평균 계산
      final average = ratings.reduce((a, b) => a + b) / ratings.length;
      
      // 분포 계산
      final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (var rating in ratings) {
        distribution[rating] = (distribution[rating] ?? 0) + 1;
      }
      
      return ReviewSummary(
        totalReviews: ratings.length,
        averageRating: average,
        ratingDistribution: distribution,
      );
    } catch (e) {
      print('Error fetching review summary: $e');
      return ReviewSummary(totalReviews: 0);
    }
  }
  
  /// 이미지 압축 (500KB 미만으로)
  /// 원본이 500KB 미만이면 그대로 반환
  Future<Uint8List> compressImage(File file) async {
    const int maxSizeBytes = 500 * 1024; // 500KB
    
    final originalBytes = await file.readAsBytes();
    
    // 이미 500KB 미만이면 그대로 반환
    if (originalBytes.length < maxSizeBytes) {
      print('📸 Image already under 500KB: ${(originalBytes.length / 1024).toStringAsFixed(1)}KB');
      return originalBytes;
    }
    
    print('📸 Original image size: ${(originalBytes.length / 1024).toStringAsFixed(1)}KB');
    
    // 품질을 단계적으로 낮추며 압축
    int quality = 85;
    Uint8List? compressedBytes;
    
    while (quality >= 20) {
      compressedBytes = await FlutterImageCompress.compressWithFile(
        file.path,
        quality: quality,
        minWidth: 1920,
        minHeight: 1920,
      );
      
      if (compressedBytes != null && compressedBytes.length < maxSizeBytes) {
        print('📸 Compressed to ${(compressedBytes.length / 1024).toStringAsFixed(1)}KB (quality: $quality)');
        return compressedBytes;
      }
      
      quality -= 10;
    }
    
    // 최종 압축 결과 반환 (500KB를 초과하더라도)
    if (compressedBytes != null) {
      print('📸 Final compressed size: ${(compressedBytes.length / 1024).toStringAsFixed(1)}KB');
      return compressedBytes;
    }
    
    return originalBytes;
  }
  
  /// 리뷰 사진 업로드 (Supabase Storage)
  /// 자동으로 500KB 미만으로 압축 후 업로드
  Future<List<String>> uploadReviewPhotos({
    required String restaurantId,
    required String userId,
    required List<File> photos,
  }) async {
    final uploadedUrls = <String>[];
    
    for (var i = 0; i < photos.length; i++) {
      try {
        final file = photos[i];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${userId}_${restaurantId}_${timestamp}_$i.jpg';
        final storagePath = 'review_photos/$restaurantId/$fileName';
        
        // 이미지 압축
        final compressedBytes = await compressImage(file);
        
        // Supabase Storage에 업로드
        await _client.storage
            .from('review-photos')
            .uploadBinary(storagePath, compressedBytes);
        
        // Public URL 가져오기
        final publicUrl = _client.storage
            .from('review-photos')
            .getPublicUrl(storagePath);
        
        uploadedUrls.add(publicUrl);
        print('✅ Uploaded photo ${i + 1}/${photos.length}: $publicUrl');
      } catch (e) {
        print('❌ Error uploading photo ${i + 1}: $e');
      }
    }
    
    return uploadedUrls;
  }

  /// 음식점 이미지 목록 조회 (restaurant_photos 테이블에서 photo_url 가져오기)
  Future<List<String>> getRestaurantPhotos(String restaurantId) async {
    try {
      final response = await _client
          .from('restaurant_photos')
          .select('photo_url')
          .eq('restaurant_id', restaurantId)
          .order('display_order', ascending: true);
      
      return (response as List).map((e) => e['photo_url'] as String).toList();
    } catch (e) {
      print('Error fetching restaurant photos: $e');
      return [];
    }
  }

  /// 내 주변 음식점 검색 (거리 기반) - Web과 동일한 Bounding Box 방식
  /// [latitude], [longitude]: 현재 위치
  /// [radiusKm]: 검색 반경 (km)
  Future<List<Restaurant>> getNearbyRestaurants({
    required double latitude,
    required double longitude,
    required double radiusKm,
    int limit = 2000,
  }) async {
    try {
      // Web과 동일한 Bounding Box 계산
      const double earthRadiusKm = 6371;
      final double deltaLat = (radiusKm / earthRadiusKm) * (180 / pi);
      final double cosLat = cos(latitude * pi / 180);
      final double deltaLon = cosLat != 0
          ? (radiusKm / earthRadiusKm) * (180 / pi) / cosLat
          : 180;

      final double minLat = latitude - deltaLat;
      final double maxLat = latitude + deltaLat;
      final double minLon = longitude - deltaLon;
      final double maxLon = longitude + deltaLon;

      print('🔍 Bounding box: lat($minLat ~ $maxLat), lon($minLon ~ $maxLon)');

      // Bounding Box로 직접 쿼리 (Web과 동일한 방식)
      final response = await _client
          .from('restaurants')
          .select()
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .gte('latitude', minLat)
          .lte('latitude', maxLat)
          .gte('longitude', minLon)
          .lte('longitude', maxLon)
          .order('total_count', ascending: false)
          .limit(limit);

      final allRestaurants = (response as List)
          .map((json) => Restaurant.fromJson(json))
          .toList();

      print('✅ Found ${allRestaurants.length} restaurants in bounding box');

      // 정확한 거리 계산으로 반경 내 필터링
      final nearbyRestaurants = <Restaurant>[];
      for (var restaurant in allRestaurants) {
        if (restaurant.latitude != null && restaurant.longitude != null) {
          final distance = _calculateDistance(
            latitude,
            longitude,
            restaurant.latitude!,
            restaurant.longitude!,
          );
          
          if (distance <= radiusKm) {
            nearbyRestaurants.add(restaurant);
          }
        }
      }

      // 거리순으로 정렬
      nearbyRestaurants.sort((a, b) {
        final distA = _calculateDistance(latitude, longitude, a.latitude!, a.longitude!);
        final distB = _calculateDistance(latitude, longitude, b.latitude!, b.longitude!);
        return distA.compareTo(distB);
      });

      print('✅ Found ${nearbyRestaurants.length} nearby restaurants within ${radiusKm}km');
      return nearbyRestaurants;
    } catch (e) {
      print('❌ Error fetching nearby restaurants: $e');
      return [];
    }
  }

  /// Haversine 공식을 사용한 두 지점 간 거리 계산 (km)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // 지구 반지름 (km)
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = 
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;
}

