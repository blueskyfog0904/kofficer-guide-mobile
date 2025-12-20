import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/user_activity.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/restaurant_service.dart';
import 'restaurant_detail_screen.dart';

/// 작성한 리뷰 화면
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final _userService = UserService();
  final _restaurantService = RestaurantService();
  final _imagePicker = ImagePicker();
  static const int _maxPhotos = 5;
  List<Review> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final authService = context.read<AuthService>();
    final userId = authService.userId;
    
    if (userId != null) {
      final reviews = await _userService.getReviews(userId);
      
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEditReviewDialog(Review review) async {
    final contentController = TextEditingController(text: review.content);
    int selectedRating = review.rating;
    List<ReviewPhotoSimple> existingPhotos = List.from(review.photos);
    List<File> newPhotos = [];
    List<String> photosToDelete = [];
    bool isUpdating = false;
    
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '리뷰 수정',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 별점 선택
                const Text('별점', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () {
                        setModalState(() => selectedRating = index + 1);
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                
                // 내용 입력
                const Text('내용', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '리뷰 내용을 입력하세요',
                  ),
                ),
                const SizedBox(height: 16),
                
                // 사진 섹션
                const Text('사진', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                if (existingPhotos.isNotEmpty || newPhotos.isNotEmpty)
                  SizedBox(
                    height: 80,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // 기존 사진
                        ...existingPhotos.where((p) => !photosToDelete.contains(p.id)).map((photo) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    photo.photoUrl,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.image_not_supported),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        photosToDelete.add(photo.id);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        // 새 사진
                        ...newPhotos.asMap().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    entry.value,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        newPhotos.removeAt(entry.key);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                
                // 사진 추가 버튼
                OutlinedButton.icon(
                  onPressed: () async {
                    final currentPhotoCount = existingPhotos.length - photosToDelete.length + newPhotos.length;
                    if (currentPhotoCount >= _maxPhotos) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('사진은 최대 $_maxPhotos장까지 추가할 수 있습니다.')),
                      );
                      return;
                    }
                    
                    final pickedFiles = await _imagePicker.pickMultiImage(
                      maxWidth: 1920,
                      maxHeight: 1920,
                    );
                    if (pickedFiles.isNotEmpty) {
                      final remainingSlots = _maxPhotos - currentPhotoCount;
                      final filesToAdd = pickedFiles.take(remainingSlots).map((f) => File(f.path)).toList();
                      setModalState(() {
                        newPhotos.addAll(filesToAdd);
                      });
                    }
                  },
                  icon: const Icon(Icons.add_photo_alternate, size: 18),
                  label: Text('사진 추가 (${existingPhotos.length - photosToDelete.length + newPhotos.length}/$_maxPhotos)'),
                ),
                const SizedBox(height: 16),
                
                // 저장 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isUpdating ? null : () {
                      Navigator.pop(context, {
                        'rating': selectedRating,
                        'content': contentController.text.trim(),
                        'photosToDelete': photosToDelete,
                        'newPhotos': newPhotos,
                      });
                    },
                    child: isUpdating
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('저장'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null) {
      await _updateReviewWithPhotos(
        review,
        result['rating'],
        result['content'],
        result['photosToDelete'] as List<String>,
        result['newPhotos'] as List<File>,
      );
    }
  }

  /// 리뷰 수정 (사진 포함)
  Future<void> _updateReviewWithPhotos(
    Review review,
    int rating,
    String content,
    List<String> photosToDelete,
    List<File> newPhotos,
  ) async {
    final authService = context.read<AuthService>();
    final userId = authService.userId;
    
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
      }
      return;
    }
    
    try {
      // 1. 리뷰 내용 수정
      await _restaurantService.updateReview(
        reviewId: review.id,
        userId: userId,
        rating: rating,
        content: content,
      );
      
      // 2. 삭제할 사진 처리
      for (var photoId in photosToDelete) {
        try {
          await _restaurantService.deleteReviewPhoto(
            photoId: photoId,
            restaurantId: review.restaurantId,
          );
        } catch (e) {
          print('사진 삭제 실패: $e');
        }
      }
      
      // 3. 새 사진 업로드 및 DB 연결
      if (newPhotos.isNotEmpty) {
        await _restaurantService.uploadAndLinkReviewPhotos(
          restaurantId: review.restaurantId,
          userId: userId,
          reviewId: review.id,
          photos: newPhotos,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰가 수정되었습니다.')),
        );
        _loadReviews();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('리뷰 수정 실패: $e')),
        );
      }
    }
  }

  Future<void> _updateReview(String reviewId, int rating, String content) async {
    final success = await _userService.updateReview(
      reviewId,
      rating: rating,
      content: content,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰가 수정되었습니다.')),
        );
        _loadReviews(); // 새로고침
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰 수정에 실패했습니다.')),
        );
      }
    }
  }

  Future<void> _deleteReview(Review review) async {
    // 삭제 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('리뷰 삭제'),
        content: Text(
          '\'${review.restaurant?.name ?? '음식점'}\' 리뷰를 삭제하시겠습니까?\n\n삭제된 리뷰와 관련 사진은 복구할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _userService.deleteReview(review.id);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰가 삭제되었습니다.')),
        );
        _loadReviews(); // 새로고침
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰 삭제에 실패했습니다.')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('작성한 리뷰'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadReviews,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _reviews.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('작성한 리뷰가 없습니다.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reviews.length,
                    separatorBuilder: (context, index) => const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final review = _reviews[index];
                      return InkWell(
                        onTap: () {
                          // 음식점 상세 페이지로 이동
                          if (review.restaurant != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RestaurantDetailScreen(
                                  restaurant: review.restaurant!,
                                ),
                              ),
                            );
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 음식점 정보
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    review.restaurant?.name ?? '음식점',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _showEditReviewDialog(review),
                                  child: const Text('수정'),
                                ),
                                TextButton(
                                  onPressed: () => _deleteReview(review),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('삭제'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            
                            // 별점
                            Row(
                              children: [
                                ...List.generate(5, (i) => Icon(
                                  i < review.rating ? Icons.star : Icons.star_border,
                                  size: 16,
                                  color: Colors.amber,
                                )),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDate(review.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // 리뷰 내용
                            if (review.content != null && review.content!.isNotEmpty)
                              Text(
                                review.content!,
                                style: const TextStyle(fontSize: 14),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            
                            // 사진 미리보기
                            if (review.photos.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 60,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: review.photos.length,
                                  itemBuilder: (context, photoIndex) {
                                    final photo = review.photos[photoIndex];
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          photo.photoUrl,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.image_not_supported, size: 24),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

