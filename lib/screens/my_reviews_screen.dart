import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_activity.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'restaurant_detail_screen.dart';

/// 작성한 리뷰 화면
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final _userService = UserService();
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
              
              // 저장 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'rating': selectedRating,
                      'content': contentController.text.trim(),
                    });
                  },
                  child: const Text('저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      await _updateReview(review.id, result['rating'], result['content']);
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
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

