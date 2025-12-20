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
    try {
      // restaurants 테이블에서 조회 (웹과 동일한 방식)
      var query = _client.from('restaurants').select();

      // 활성화된 식당만 조회
      query = query.eq('is_active', true);

      if (keyword != null && keyword.isNotEmpty) {
        query = query.ilike('name', '%$keyword%');
      }

      // region_id 파싱: "시도|시군구" 형식
      String? parsedSubAdd1;
      String? parsedSubAdd2;
      if (regionId != null && regionId.isNotEmpty) {
        if (regionId.contains('|')) {
          final parts = regionId.split('|');
          if (parts.length >= 2) {
            parsedSubAdd1 = parts[0];
            parsedSubAdd2 = parts[1];
            query = query.eq('sub_add1', parsedSubAdd1).eq('sub_add2', parsedSubAdd2);
            print('🔍 Searching: sub_add1=${parsedSubAdd1}, sub_add2=${parsedSubAdd2}');
          }
        } else {
          // 구분자가 없으면 sub_add2만 검색
          parsedSubAdd2 = regionId;
          query = query.eq('sub_add2', parsedSubAdd2);
        }
      }

      // rank_value 기준으로 정렬 (웹 앱과 동일)
      final response = await query
          .order('rank_value', ascending: false) // rank_value 내림차순 (높은 값이 1위)
          .range(offset, offset + limit - 1);
      
      final data = (response ?? []) as List;
      print('✅ Found ${data.length} restaurants from DB');
      
      // 음식점 ID 목록 추출
      final restaurantIds = data.map((row) => row['id'] as String).toList();
      
      // reviews 테이블에서 리뷰 통계 조회 (웹과 동일한 방식)
      final reviewStats = await _getReviewStatsForRestaurants(restaurantIds);
      
      // rank_value를 기반으로 Dense Rank 계산 (웹 앱과 동일한 로직)
      final dataWithRankValue = data.map((row) {
        final json = row as Map<String, dynamic>;
        final Map<String, dynamic> result = Map<String, dynamic>.from(json);
        // rank_value를 num으로 받아서 int로 변환 (타입 안전성)
        final rawRankValue = json['rank_value'];
        result['rank_value'] = rawRankValue is num ? rawRankValue.toInt() : 0;
        
        // 리뷰 통계 추가
        final restaurantId = json['id'] as String;
        if (reviewStats.containsKey(restaurantId)) {
          result['avg_rating'] = reviewStats[restaurantId]!['avg_rating'];
          result['review_count'] = reviewStats[restaurantId]!['review_count'];
        }
        
        return result;
      }).toList();
      
      int currentRank = 1;
      int? prevRankValue;
      final itemsWithRank = <Map<String, dynamic>>[];
      
      for (final row in dataWithRankValue) {
        final rankValue = row['rank_value'] as int;
        
        if (prevRankValue != null && rankValue != prevRankValue) {
          currentRank++;
        }
        
        prevRankValue = rankValue;
        final Map<String, dynamic> rankedRow = Map<String, dynamic>.from(row);
        rankedRow['region_rank'] = currentRank; // 계산된 순위를 region_rank로 추가
        itemsWithRank.add(rankedRow);
      }
      
      final restaurants = itemsWithRank.map((json) {
        return Restaurant.fromJson(json);
      }).toList();
      
      print('✅ Found ${restaurants.length} restaurants with review stats');
      
      return restaurants;
    } catch (e, stackTrace) {
      print('❌ Error in searchRestaurants: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// 음식점별 리뷰 통계 조회 (웹과 동일한 방식)
  /// reviews 테이블에서 rating을 조회하여 클라이언트에서 평균/개수 계산
  /// ID가 많을 경우 배치로 나누어 쿼리 (URL 길이 제한 방지)
  Future<Map<String, Map<String, dynamic>>> _getReviewStatsForRestaurants(
    List<String> restaurantIds,
  ) async {
    final stats = <String, Map<String, dynamic>>{};
    
    if (restaurantIds.isEmpty) return stats;
    
    try {
      // 음식점별로 rating 모으기
      final ratingsMap = <String, List<int>>{};
      
      // 100개씩 배치로 나누어 쿼리 (URL 길이 제한 방지)
      const batchSize = 100;
      for (var i = 0; i < restaurantIds.length; i += batchSize) {
        final batch = restaurantIds.skip(i).take(batchSize).toList();
        
        try {
          final response = await _client
              .from('reviews')
              .select('restaurant_id, rating')
              .inFilter('restaurant_id', batch);
          
          final reviewData = response as List;
          
          for (final row in reviewData) {
            final restaurantId = row['restaurant_id'] as String;
            final rating = row['rating'] as int;
            
            if (!ratingsMap.containsKey(restaurantId)) {
              ratingsMap[restaurantId] = [];
            }
            ratingsMap[restaurantId]!.add(rating);
          }
        } catch (batchError) {
          print('⚠️ Error fetching review stats batch ${i ~/ batchSize + 1}: $batchError');
        }
      }
      
      // 평균과 개수 계산
      ratingsMap.forEach((restaurantId, ratings) {
        final avgRating = ratings.reduce((a, b) => a + b) / ratings.length;
        stats[restaurantId] = {
          'avg_rating': avgRating,
          'review_count': ratings.length,
        };
      });
      
      print('✅ Loaded review stats for ${stats.length} restaurants (${restaurantIds.length} IDs in ${(restaurantIds.length / batchSize).ceil()} batches)');
      return stats;
    } catch (e) {
      print('⚠️ Error fetching review stats: $e');
      return stats;
    }
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

  /// 리뷰 등록 (사진 파일 포함 - 새로운 통합 방식)
  /// [photos]: 업로드할 사진 파일 목록
  /// [onProgress]: 업로드 진행률 콜백 (currentIndex, totalCount, progress 0.0~1.0)
  /// 사진이 있으면 자동으로 음식점 사진으로 연동됨
  Future<SubmitReviewResult> submitReviewWithPhotos({
    required String restaurantId,
    required String userId,
    required double rating,
    String? content,
    List<File>? photos,
    void Function(int currentIndex, int totalCount, double progress)? onProgress,
  }) async {
    try {
      // 1. 리뷰 데이터 삽입 (rating을 int로 변환 - DB가 integer 타입)
      final insertData = {
        'restaurant_id': restaurantId,
        'user_id': userId,
        'rating': rating.toInt(),
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      final reviewResponse = await _client.from('reviews').insert(insertData).select('id').single();
      
      final reviewId = reviewResponse['id'].toString();
      print('✅ Review created with ID: $reviewId');
      
      // 2. 사진이 있으면 업로드 및 연동
      UploadReviewPhotosResult? photoResult;
      if (photos != null && photos.isNotEmpty) {
        photoResult = await uploadAndLinkReviewPhotos(
          restaurantId: restaurantId,
          userId: userId,
          reviewId: reviewId,
          photos: photos,
          onProgress: onProgress,
        );
        print('✅ ${photoResult.uploadedUrls.length} photos uploaded and linked for review $reviewId');
      }
      
      return SubmitReviewResult(
        reviewId: reviewId,
        photoUrls: photoResult?.uploadedUrls ?? [],
        primaryPhotoSet: photoResult?.primaryPhotoSet ?? false,
      );
    } catch (e) {
      print('❌ Error submitting review: $e');
      rethrow;
    }
  }

  /// 리뷰 등록 (레거시 - URL 방식, 기존 호환용)
  /// [photoUrls]: 업로드된 사진 URL 목록
  @Deprecated('Use submitReviewWithPhotos instead for auto-linking to restaurant photos')
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
          'created_at': DateTime.now().toIso8601String(),
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
  
  /// 개별 리뷰 사진 삭제
  Future<void> deleteReviewPhoto({
    required String photoId,
    required String restaurantId,
  }) async {
    try {
      // 1. 사진 정보 조회
      final photoResponse = await _client
          .from('review_photos')
          .select('photo_url, storage_path')
          .eq('id', photoId)
          .maybeSingle();
      
      if (photoResponse == null) {
        throw Exception('사진을 찾을 수 없습니다.');
      }
      
      final photoUrl = photoResponse['photo_url'] as String?;
      final storagePath = photoResponse['storage_path'] as String?;
      
      // 2. Storage에서 파일 삭제
      if (storagePath != null) {
        try {
          await _client.storage.from('review-photos').remove([storagePath]);
          print('✅ Deleted file from Storage: $storagePath');
        } catch (e) {
          print('⚠️ Failed to delete file from Storage: $e');
        }
      }
      
      // 3. 대표 이미지가 삭제된 사진인지 확인
      if (photoUrl != null) {
        try {
          final restaurantResponse = await _client
              .from('restaurants')
              .select('primary_photo_url')
              .eq('id', restaurantId)
              .maybeSingle();
          
          if (restaurantResponse != null) {
            final primaryPhotoUrl = restaurantResponse['primary_photo_url'] as String?;
            if (primaryPhotoUrl != null && primaryPhotoUrl == photoUrl) {
              await _client
                  .from('restaurants')
                  .update({'primary_photo_url': null})
                  .eq('id', restaurantId);
              print('✅ Cleared primary_photo_url');
            }
          }
        } catch (e) {
          print('⚠️ Failed to clear primary photo: $e');
        }
      }
      
      // 4. restaurant_photos에서 삭제
      await _client
          .from('restaurant_photos')
          .delete()
          .eq('review_photo_id', photoId);
      
      // 5. review_photos에서 삭제
      await _client
          .from('review_photos')
          .delete()
          .eq('id', photoId);
      
      print('✅ Review photo deleted: $photoId');
    } catch (e) {
      print('❌ Error deleting review photo: $e');
      rethrow;
    }
  }
  
  /// 리뷰 수정
  Future<void> updateReview({
    required String reviewId,
    required String userId,
    int? rating,
    String? content,
  }) async {
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
          .eq('id', reviewId)
          .eq('user_id', userId); // 본인 리뷰만 수정 가능
      
      print('✅ Review updated: $reviewId');
    } catch (e) {
      print('❌ Error updating review: $e');
      rethrow;
    }
  }
  
  /// 리뷰 삭제 (hard delete) - Storage 파일 및 대표 이미지도 정리
  Future<void> deleteReview({
    required String reviewId,
    required String userId,
    required String restaurantId,
  }) async {
    try {
      // 1. 리뷰 사진 정보 조회 (Storage 삭제용)
      final photoResponse = await _client
          .from('review_photos')
          .select('photo_url, storage_path')
          .eq('review_id', reviewId);
      
      final photoUrls = <String>[];
      final storagePaths = <String>[];
      for (var photo in (photoResponse as List)) {
        if (photo['photo_url'] != null) {
          photoUrls.add(photo['photo_url']);
        }
        if (photo['storage_path'] != null) {
          storagePaths.add(photo['storage_path']);
        }
      }
      
      // 2. Storage에서 파일 삭제
      if (storagePaths.isNotEmpty) {
        try {
          await _client.storage.from('review-photos').remove(storagePaths);
          print('✅ Deleted ${storagePaths.length} files from Storage');
        } catch (e) {
          print('⚠️ Failed to delete files from Storage: $e');
        }
      }
      
      // 3. 대표 이미지가 삭제된 사진인지 확인하고 null로 설정
      if (photoUrls.isNotEmpty) {
        try {
          final restaurantResponse = await _client
              .from('restaurants')
              .select('primary_photo_url')
              .eq('id', restaurantId)
              .maybeSingle();
          
          if (restaurantResponse != null) {
            final primaryPhotoUrl = restaurantResponse['primary_photo_url'] as String?;
            if (primaryPhotoUrl != null && photoUrls.contains(primaryPhotoUrl)) {
              await _client
                  .from('restaurants')
                  .update({'primary_photo_url': null})
                  .eq('id', restaurantId);
              print('✅ Cleared primary_photo_url for restaurant: $restaurantId');
            }
          }
        } catch (e) {
          print('⚠️ Failed to clear primary photo: $e');
        }
      }
      
      // 4. review_photos 테이블에서 삭제
      await _client
          .from('review_photos')
          .delete()
          .eq('review_id', reviewId);
      
      // 5. restaurant_photos에서 연동된 사진 삭제
      await _client
          .from('restaurant_photos')
          .delete()
          .eq('review_id', reviewId);
      
      // 6. 리뷰 삭제
      await _client
          .from('reviews')
          .delete()
          .eq('id', reviewId)
          .eq('user_id', userId); // 본인 리뷰만 삭제 가능
      
      print('✅ Review deleted with photos: $reviewId');
    } catch (e) {
      print('❌ Error deleting review: $e');
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
        
        // 뷰에는 mob_nickname이 없으므로 profiles에서 직접 조회
        final reviews = <UserReview>[];
        for (var json in response as List) {
          // profiles 테이블에서 mob_nickname 조회
          String? displayName;
          try {
            final profileResponse = await _client
                .from('profiles')
                .select('mob_nickname, nickname')
                .eq('user_id', json['user_id'])
                .maybeSingle();
            
            if (profileResponse != null) {
              displayName = profileResponse['mob_nickname'] ?? profileResponse['nickname'];
            }
          } catch (_) {}
          
          // fallback: 뷰의 nickname 사용
          displayName ??= json['nickname'] ?? json['username'];
          
          final userJson = {
            'id': json['user_id'],
            'username': json['username'],
            'nickname': displayName,
            'profile_image_url': json['avatar_url'],
          };
          json['user'] = userJson;
          
          // 사진 조회
          final photos = await getReviewPhotos(json['id'].toString());
          json['photos'] = photos.map((p) => p.toJson()).toList();
          
          reviews.add(UserReview.fromJson(json));
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
        // 사용자 정보 조회 (mob_nickname 우선, 없으면 nickname 사용)
        try {
          final profileResponse = await _client
              .from('profiles')
              .select('user_id, mob_nickname, nickname, avatar_url')
              .eq('user_id', json['user_id'])
              .maybeSingle();
          
          if (profileResponse != null) {
            final displayName = profileResponse['mob_nickname'] ?? profileResponse['nickname'];
            json['user'] = {
              'id': profileResponse['user_id'],
              'nickname': displayName,
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

      // restaurants 테이블에서 조회 (웹과 동일한 방식)
      // Bounding Box로 직접 쿼리
      final response = await _client
          .from('restaurants')
          .select()
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .gte('latitude', minLat)
          .lte('latitude', maxLat)
          .gte('longitude', minLon)
          .lte('longitude', maxLon)
          .order('rank_value', ascending: false) // rank_value 내림차순
          .limit(limit);

      final data = (response as List);
      print('✅ Found ${data.length} restaurants in bounding box');

      // 정확한 거리 계산으로 반경 내 필터링 + 거리 정보 저장
      final nearbyData = <Map<String, dynamic>>[];
      for (var json in data) {
        final lat = json['latitude'];
        final lon = json['longitude'];
        if (lat != null && lon != null) {
          final distance = _calculateDistance(
            latitude,
            longitude,
            (lat as num).toDouble(),
            (lon as num).toDouble(),
          );
          
          if (distance <= radiusKm) {
            final Map<String, dynamic> item = Map<String, dynamic>.from(json);
            item['_distance'] = distance; // 임시 거리 저장
            nearbyData.add(item);
          }
        }
      }

      // 거리순으로 정렬
      nearbyData.sort((a, b) {
        final distA = a['_distance'] as double;
        final distB = b['_distance'] as double;
        return distA.compareTo(distB);
      });

      // 음식점 ID 목록 추출하여 리뷰 통계 조회
      final restaurantIds = nearbyData.map((row) => row['id'] as String).toList();
      final reviewStats = await _getReviewStatsForRestaurants(restaurantIds);

      // rank_value 기준으로 Dense Rank 계산 (지역 검색과 동일한 로직)
      // 먼저 rank_value 기준으로 정렬된 복사본 생성
      final sortedByRank = List<Map<String, dynamic>>.from(nearbyData);
      sortedByRank.sort((a, b) {
        final rankA = (a['rank_value'] as num?)?.toInt() ?? 0;
        final rankB = (b['rank_value'] as num?)?.toInt() ?? 0;
        return rankB.compareTo(rankA); // 내림차순
      });

      // Dense Rank 계산
      int currentRank = 1;
      int? prevRankValue;
      final rankMap = <String, int>{}; // id -> region_rank
      
      for (final item in sortedByRank) {
        final rankValue = (item['rank_value'] as num?)?.toInt() ?? 0;
        
        if (prevRankValue != null && rankValue != prevRankValue) {
          currentRank++;
        }
        
        prevRankValue = rankValue;
        rankMap[item['id'].toString()] = currentRank;
      }

      // 거리순 정렬된 데이터에 region_rank와 리뷰 통계 추가하여 Restaurant 객체 생성
      final nearbyRestaurants = nearbyData.map((json) {
        final id = json['id'].toString();
        json['region_rank'] = rankMap[id];
        json.remove('_distance'); // 임시 필드 제거
        
        // 리뷰 통계 추가
        if (reviewStats.containsKey(id)) {
          json['avg_rating'] = reviewStats[id]!['avg_rating'];
          json['review_count'] = reviewStats[id]!['review_count'];
        }
        
        return Restaurant.fromJson(json);
      }).toList();

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

  // ===================================
  // 음식점 썸네일 (첫 번째 사진) 조회
  // ===================================

  /// 음식점의 첫 번째 사진 URL 조회 (캐싱 적용)
  /// primary_photo_url이 없는 음식점의 썸네일을 표시할 때 사용
  Future<String?> getFirstPhotoUrl(String restaurantId) async {
    // 캐시 확인
    if (_RestaurantPhotoCache.hasKey(restaurantId)) {
      return _RestaurantPhotoCache.get(restaurantId);
    }
    
    try {
      // 1. restaurant_photos 테이블에서 첫 번째 사진 조회
      final restaurantPhotosResponse = await _client
          .from('restaurant_photos')
          .select('photo_url')
          .eq('restaurant_id', restaurantId)
          .eq('is_active', true)
          .order('display_order', ascending: true)
          .limit(1);
      
      if ((restaurantPhotosResponse as List).isNotEmpty) {
        final photoUrl = restaurantPhotosResponse[0]['photo_url'] as String;
        _RestaurantPhotoCache.set(restaurantId, photoUrl);
        return photoUrl;
      }
      
      // 2. restaurant_photos에 없으면 review_photos에서 조회
      final reviewPhotosResponse = await _client
          .from('reviews')
          .select('review_photos(photo_url)')
          .eq('restaurant_id', restaurantId)
          .order('created_at', ascending: false)
          .limit(1);
      
      if ((reviewPhotosResponse as List).isNotEmpty) {
        final reviewPhotos = reviewPhotosResponse[0]['review_photos'] as List?;
        if (reviewPhotos != null && reviewPhotos.isNotEmpty) {
          final photoUrl = reviewPhotos[0]['photo_url'] as String;
          _RestaurantPhotoCache.set(restaurantId, photoUrl);
          return photoUrl;
        }
      }
      
      // 사진이 없는 경우
      _RestaurantPhotoCache.set(restaurantId, null);
      return null;
    } catch (e) {
      print('Error fetching first photo for restaurant $restaurantId: $e');
      return null;
    }
  }

  /// 여러 음식점의 첫 번째 사진을 일괄 조회 (성능 최적화)
  /// 음식점 목록 조회 후 primary_photo_url이 없는 음식점들의 사진을 한 번에 조회
  Future<Map<String, String>> getFirstPhotosForRestaurants(List<String> restaurantIds) async {
    final result = <String, String>{};
    final idsToFetch = <String>[];
    
    // 캐시에서 먼저 확인
    for (final id in restaurantIds) {
      if (_RestaurantPhotoCache.hasKey(id)) {
        final cached = _RestaurantPhotoCache.get(id);
        if (cached != null) {
          result[id] = cached;
        }
      } else {
        idsToFetch.add(id);
      }
    }
    
    if (idsToFetch.isEmpty) {
      return result;
    }
    
    try {
      // restaurant_photos 테이블에서 일괄 조회
      final response = await _client
          .from('restaurant_photos')
          .select('restaurant_id, photo_url, display_order')
          .inFilter('restaurant_id', idsToFetch)
          .eq('is_active', true)
          .order('display_order', ascending: true);
      
      // 음식점별로 첫 번째 사진만 저장
      final foundIds = <String>{};
      for (final row in (response as List)) {
        final restaurantId = row['restaurant_id'] as String;
        if (!foundIds.contains(restaurantId)) {
          foundIds.add(restaurantId);
          final photoUrl = row['photo_url'] as String;
          result[restaurantId] = photoUrl;
          _RestaurantPhotoCache.set(restaurantId, photoUrl);
        }
      }
      
      // restaurant_photos에서 찾지 못한 음식점은 review_photos에서 조회
      final remainingIds = idsToFetch.where((id) => !foundIds.contains(id)).toList();
      if (remainingIds.isNotEmpty) {
        final reviewResponse = await _client
            .from('reviews')
            .select('restaurant_id, review_photos(photo_url)')
            .inFilter('restaurant_id', remainingIds)
            .order('created_at', ascending: false);
        
        final reviewFoundIds = <String>{};
        for (final row in (reviewResponse as List)) {
          final restaurantId = row['restaurant_id'] as String;
          if (!reviewFoundIds.contains(restaurantId)) {
            final reviewPhotos = row['review_photos'] as List?;
            if (reviewPhotos != null && reviewPhotos.isNotEmpty) {
              reviewFoundIds.add(restaurantId);
              final photoUrl = reviewPhotos[0]['photo_url'] as String;
              result[restaurantId] = photoUrl;
              _RestaurantPhotoCache.set(restaurantId, photoUrl);
            }
          }
        }
        
        // 사진이 없는 음식점은 null로 캐시
        for (final id in remainingIds) {
          if (!reviewFoundIds.contains(id)) {
            _RestaurantPhotoCache.set(id, null);
          }
        }
      }
      
      return result;
    } catch (e) {
      print('Error fetching first photos for restaurants: $e');
      return result;
    }
  }

  // ===================================
  // 리뷰 사진 → 음식점 사진 연동 시스템
  // ===================================

  /// 리뷰 사진을 음식점 사진으로 연동
  /// [reviewId]: 리뷰 ID
  /// [restaurantId]: 음식점 ID
  /// [reviewPhotoId]: 리뷰 사진 ID
  /// [photoUrl]: 사진 URL
  /// [displayOrder]: 원본 리뷰 사진 순서
  Future<bool> linkReviewPhotoToRestaurant({
    required String reviewId,
    required String restaurantId,
    required String reviewPhotoId,
    required String photoUrl,
    required int displayOrder,
  }) async {
    try {
      // 1. 해당 음식점의 리뷰 기반 사진 개수 확인 (최대 20개 제한)
      final existingCount = await _getRestaurantReviewPhotoCount(restaurantId);
      if (existingCount >= 20) {
        print('⚠️ Restaurant $restaurantId already has 20 review-based photos, skipping');
        return false;
      }

      // 2. restaurant_photos 테이블에 INSERT
      // display_order: 1000 + 원본_순서 (관리자 사진보다 뒤에 표시)
      await _client.from('restaurant_photos').insert({
        'restaurant_id': restaurantId,
        'review_id': reviewId,
        'review_photo_id': reviewPhotoId,
        'photo_url': photoUrl,
        'source_type': 'review',
        'display_order': 1000 + displayOrder,
        'is_active': true,
      });

      print('✅ Linked review photo to restaurant: $restaurantId');
      return true;
    } catch (e) {
      // 연동 실패해도 리뷰 사진 업로드는 성공 처리 (연동은 부가 기능)
      print('⚠️ Failed to link review photo to restaurant: $e');
      return false;
    }
  }

  /// 음식점의 리뷰 기반 사진 개수 조회
  Future<int> _getRestaurantReviewPhotoCount(String restaurantId) async {
    try {
      final response = await _client
          .from('restaurant_photos')
          .select('id')
          .eq('restaurant_id', restaurantId)
          .eq('source_type', 'review')
          .eq('is_active', true);
      
      return (response as List).length;
    } catch (e) {
      print('Error counting restaurant review photos: $e');
      return 0;
    }
  }

  /// 대표 이미지 자동 설정
  /// 음식점에 대표 이미지가 없거나 외부 API URL인 경우 새 사진으로 설정
  Future<bool> autoSetPrimaryPhotoIfNeeded({
    required String restaurantId,
    required String photoUrl,
  }) async {
    try {
      // 1. 현재 음식점의 대표 이미지 확인
      final response = await _client
          .from('restaurants')
          .select('primary_photo_url')
          .eq('id', restaurantId)
          .single();
      
      final currentPrimaryUrl = response['primary_photo_url'] as String?;
      
      // 2. 대표 이미지 설정 조건 확인
      // - primary_photo_url이 NULL인 경우
      // - 또는 외부 API URL인 경우 (googleapis.com 포함)
      final shouldSetPrimary = currentPrimaryUrl == null || 
          currentPrimaryUrl.isEmpty ||
          currentPrimaryUrl.contains('googleapis.com');
      
      if (!shouldSetPrimary) {
        print('ℹ️ Restaurant $restaurantId already has a valid primary photo');
        return false;
      }

      // 3. 대표 이미지 업데이트
      await _client
          .from('restaurants')
          .update({'primary_photo_url': photoUrl})
          .eq('id', restaurantId);
      
      print('✅ Auto-set primary photo for restaurant: $restaurantId');
      return true;
    } catch (e) {
      print('⚠️ Failed to auto-set primary photo: $e');
      return false;
    }
  }

  /// 리뷰 사진 업로드 및 음식점 사진 연동 (통합 함수)
  /// 1. 이미지 압축 → 2. 스토리지 업로드 → 3. review_photos 저장 
  /// → 4. restaurant_photos 연동 → 5. 대표 이미지 자동 설정
  /// [onProgress]: 업로드 진행률 콜백 (currentIndex, totalCount, progress 0.0~1.0)
  Future<UploadReviewPhotosResult> uploadAndLinkReviewPhotos({
    required String restaurantId,
    required String userId,
    required String reviewId,
    required List<File> photos,
    void Function(int currentIndex, int totalCount, double progress)? onProgress,
  }) async {
    final uploadedUrls = <String>[];
    final uploadedPhotoIds = <String>[];
    bool primaryPhotoSet = false;
    final totalCount = photos.length;
    
    for (var i = 0; i < photos.length; i++) {
      try {
        // 진행률 콜백: 시작 (각 사진당 압축 25%, 업로드 50%, DB저장 25%)
        onProgress?.call(i + 1, totalCount, (i / totalCount));
        
        final file = photos[i];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final random = DateTime.now().microsecond;
        final fileName = '${userId}_${reviewId}_${timestamp}_${random}_$i.jpg';
        final storagePath = '$userId/$reviewId/$fileName';
        
        // 1. 이미지 압축
        final compressedBytes = await compressImage(file);
        // 진행률 콜백: 압축 완료 (25%)
        onProgress?.call(i + 1, totalCount, (i + 0.25) / totalCount);
        
        // 2. Supabase Storage에 업로드
        await _client.storage
            .from('review-photos')
            .uploadBinary(storagePath, compressedBytes);
        // 진행률 콜백: 업로드 완료 (75%)
        onProgress?.call(i + 1, totalCount, (i + 0.75) / totalCount);
        
        // Public URL 가져오기
        final publicUrl = _client.storage
            .from('review-photos')
            .getPublicUrl(storagePath);
        
        uploadedUrls.add(publicUrl);
        print('✅ Uploaded photo ${i + 1}/${photos.length}: $publicUrl');
        
        // 3. review_photos 테이블에 저장
        final photoResponse = await _client.from('review_photos').insert({
          'review_id': reviewId,
          'user_id': userId,
          'photo_url': publicUrl,
          'storage_path': storagePath,
          'file_size': compressedBytes.length,
          'display_order': i,
          'created_at': DateTime.now().toIso8601String(),
        }).select('id').single();
        
        final photoId = photoResponse['id'].toString();
        uploadedPhotoIds.add(photoId);
        print('✅ Saved review photo to DB with ID: $photoId');
        
        // 4. 음식점 사진으로 연동
        await linkReviewPhotoToRestaurant(
          reviewId: reviewId,
          restaurantId: restaurantId,
          reviewPhotoId: photoId,
          photoUrl: publicUrl,
          displayOrder: i,
        );
        
        // 5. 첫 번째 사진이면 대표 이미지 자동 설정 시도
        if (i == 0 && !primaryPhotoSet) {
          final result = await autoSetPrimaryPhotoIfNeeded(
            restaurantId: restaurantId,
            photoUrl: publicUrl,
          );
          primaryPhotoSet = result;
        }
        
        // 진행률 콜백: 이 사진 완료 (100%)
        onProgress?.call(i + 1, totalCount, (i + 1) / totalCount);
      } catch (e) {
        print('❌ Error uploading photo ${i + 1}: $e');
        // 에러가 나도 진행률은 업데이트
        onProgress?.call(i + 1, totalCount, (i + 1) / totalCount);
      }
    }
    
    return UploadReviewPhotosResult(
      uploadedUrls: uploadedUrls,
      photoIds: uploadedPhotoIds,
      primaryPhotoSet: primaryPhotoSet,
    );
  }

  /// 음식점 사진 목록 조회 (restaurant_photos + 레거시 review_photos 통합)
  /// [includeReviewPhotos]: 리뷰 사진도 포함할지 여부
  Future<List<RestaurantPhotoInfo>> getRestaurantPhotosWithInfo(
    String restaurantId, {
    bool includeReviewPhotos = true,
    int maxPhotos = 20,
  }) async {
    final photos = <RestaurantPhotoInfo>[];
    final addedPhotoUrls = <String>{}; // 중복 제거용
    
    try {
      // 1. restaurant_photos 테이블 조회
      final restaurantPhotosResponse = await _client
          .from('restaurant_photos')
          .select('id, photo_url, source_type, display_order, review_id')
          .eq('restaurant_id', restaurantId)
          .eq('is_active', true)
          .order('display_order', ascending: true);
      
      for (var row in (restaurantPhotosResponse as List)) {
        final photoUrl = row['photo_url'] as String;
        if (!addedPhotoUrls.contains(photoUrl)) {
          addedPhotoUrls.add(photoUrl);
          photos.add(RestaurantPhotoInfo(
            id: row['id'].toString(),
            photoUrl: photoUrl,
            sourceType: row['source_type'] ?? 'admin',
            displayOrder: row['display_order'] ?? 0,
            reviewId: row['review_id']?.toString(),
          ));
        }
      }
      
      // 2. 레거시 리뷰 사진 조회 (restaurant_photos에 연동되지 않은 것들)
      if (includeReviewPhotos && photos.length < maxPhotos) {
        final linkedPhotoIds = photos
            .where((p) => p.sourceType == 'review')
            .map((p) => p.id)
            .toSet();
        
        // reviews → review_photos 조인하여 조회
        final reviewPhotosResponse = await _client
            .from('reviews')
            .select('id, review_photos(id, photo_url, display_order)')
            .eq('restaurant_id', restaurantId)
            .order('created_at', ascending: false);
        
        for (var review in (reviewPhotosResponse as List)) {
          final reviewPhotos = review['review_photos'] as List? ?? [];
          for (var photo in reviewPhotos) {
            final photoUrl = photo['photo_url'] as String;
            final photoId = photo['id'].toString();
            
            // 이미 restaurant_photos에 연동된 사진이면 제외
            if (linkedPhotoIds.contains(photoId)) continue;
            if (addedPhotoUrls.contains(photoUrl)) continue;
            if (photos.length >= maxPhotos) break;
            
            addedPhotoUrls.add(photoUrl);
            photos.add(RestaurantPhotoInfo(
              id: photoId,
              photoUrl: photoUrl,
              sourceType: 'legacy_review',
              displayOrder: 2000 + ((photo['display_order'] as num?)?.toInt() ?? 0), // 레거시 리뷰 사진
              reviewId: review['id'].toString(),
            ));
          }
          if (photos.length >= maxPhotos) break;
        }
      }
      
      // 3. display_order 기준 정렬
      photos.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      
      print('✅ Loaded ${photos.length} photos for restaurant $restaurantId');
      return photos.take(maxPhotos).toList();
    } catch (e) {
      print('Error fetching restaurant photos with info: $e');
      return [];
    }
  }

  /// 리뷰 삭제 시 연관된 restaurant_photos 비활성화
  Future<void> deactivateRestaurantPhotosForReview(String reviewId) async {
    try {
      await _client
          .from('restaurant_photos')
          .update({'is_active': false})
          .eq('review_id', reviewId);
      
      print('✅ Deactivated restaurant photos for review: $reviewId');
    } catch (e) {
      print('⚠️ Failed to deactivate restaurant photos: $e');
    }
  }

  /// 대표 이미지 재설정 (기존 대표 이미지가 삭제된 경우)
  /// 다음 사진으로 자동 재설정하거나 NULL 처리
  Future<void> resetPrimaryPhotoIfNeeded({
    required String restaurantId,
    required String deletedPhotoUrl,
  }) async {
    try {
      // 1. 현재 대표 이미지 확인
      final response = await _client
          .from('restaurants')
          .select('primary_photo_url')
          .eq('id', restaurantId)
          .single();
      
      final currentPrimaryUrl = response['primary_photo_url'] as String?;
      
      // 삭제된 사진이 대표 이미지가 아니면 무시
      if (currentPrimaryUrl != deletedPhotoUrl) {
        return;
      }
      
      // 2. 다음 사용 가능한 사진 찾기
      final photos = await getRestaurantPhotosWithInfo(restaurantId, maxPhotos: 1);
      
      String? newPrimaryUrl;
      if (photos.isNotEmpty) {
        newPrimaryUrl = photos.first.photoUrl;
      }
      
      // 3. 대표 이미지 업데이트
      await _client
          .from('restaurants')
          .update({'primary_photo_url': newPrimaryUrl})
          .eq('id', restaurantId);
      
      print('✅ Reset primary photo for restaurant: $restaurantId → ${newPrimaryUrl ?? 'NULL'}');
    } catch (e) {
      print('⚠️ Failed to reset primary photo: $e');
    }
  }
}

/// 리뷰 사진 업로드 결과
class UploadReviewPhotosResult {
  final List<String> uploadedUrls;
  final List<String> photoIds;
  final bool primaryPhotoSet;
  
  UploadReviewPhotosResult({
    required this.uploadedUrls,
    required this.photoIds,
    required this.primaryPhotoSet,
  });
}

/// 음식점 사진 정보 (source_type 포함)
class RestaurantPhotoInfo {
  final String id;
  final String photoUrl;
  final String sourceType; // 'admin', 'review', 'legacy_review'
  final int displayOrder;
  final String? reviewId;
  
  RestaurantPhotoInfo({
    required this.id,
    required this.photoUrl,
    required this.sourceType,
    required this.displayOrder,
    this.reviewId,
  });
}

/// 리뷰 등록 결과
class SubmitReviewResult {
  final String reviewId;
  final List<String> photoUrls;
  final bool primaryPhotoSet;
  
  SubmitReviewResult({
    required this.reviewId,
    required this.photoUrls,
    required this.primaryPhotoSet,
  });
}

/// 음식점 첫 번째 사진 캐시 (성능 최적화)
class _RestaurantPhotoCache {
  static final Map<String, String?> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  static String? get(String restaurantId) {
    final time = _cacheTime[restaurantId];
    if (time != null && DateTime.now().difference(time) < _cacheDuration) {
      return _cache[restaurantId];
    }
    return null;
  }
  
  static void set(String restaurantId, String? photoUrl) {
    _cache[restaurantId] = photoUrl;
    _cacheTime[restaurantId] = DateTime.now();
  }
  
  static bool hasKey(String restaurantId) {
    final time = _cacheTime[restaurantId];
    return time != null && DateTime.now().difference(time) < _cacheDuration;
  }
}

