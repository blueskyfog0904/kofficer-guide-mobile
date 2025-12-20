import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/restaurant.dart';
import '../models/user_review.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/restaurant_service.dart';
import 'main_screen.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  bool _isFavorite = false;
  bool _isLoadingFavorite = false;
  final UserService _userService = UserService();
  final RestaurantService _restaurantService = RestaurantService();
  
  // 이미지 슬라이더 관련
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  List<String> _imageUrls = [];
  bool _isLoadingImages = true;
  final Set<String> _failedImageUrls = {}; // 로딩 실패한 이미지 URL 추적
  
  // 리뷰 작성 관련
  final TextEditingController _reviewController = TextEditingController();
  double _userRating = 0;
  bool _isSubmittingReview = false;
  
  // 리뷰 목록 관련
  List<UserReview> _reviews = [];
  ReviewSummary? _reviewSummary;
  bool _isLoadingReviews = true;
  
  // 내 리뷰 관련
  bool _hasUserReview = false;
  String? _userReviewId;
  
  // 리뷰 사진 업로드 관련
  final ImagePicker _imagePicker = ImagePicker();
  List<File> _selectedPhotos = [];
  bool _isUploadingPhotos = false;
  static const int _maxPhotos = 6;
  
  // 업로드 진행률 관련
  double _uploadProgress = 0.0;
  int _currentUploadIndex = 0;
  int _totalUploadCount = 0;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
    _loadImages();
    _loadReviews();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadImages() async {
    setState(() => _isLoadingImages = true);
    
    try {
      // 새로운 통합 조회 함수 사용: restaurant_photos + 레거시 review_photos
      final photos = await _restaurantService.getRestaurantPhotosWithInfo(
        widget.restaurant.id,
        includeReviewPhotos: true,
        maxPhotos: 20,
      );
      
      final images = <String>[];
      final addedUrls = <String>{};
      
      // 1. 대표 사진 (primary_photo_url) 먼저 추가
      if (widget.restaurant.primaryPhotoUrl != null && 
          widget.restaurant.primaryPhotoUrl!.isNotEmpty) {
        images.add(widget.restaurant.primaryPhotoUrl!);
        addedUrls.add(widget.restaurant.primaryPhotoUrl!);
      }
      
      // 2. 조회된 사진들 추가 (중복 제거)
      for (var photo in photos) {
        if (!addedUrls.contains(photo.photoUrl)) {
          images.add(photo.photoUrl);
          addedUrls.add(photo.photoUrl);
        }
      }
      
      print('✅ Loaded ${images.length} images for restaurant ${widget.restaurant.id}');
      
      if (mounted) {
        setState(() {
          _imageUrls = images;
          _isLoadingImages = false;
        });
      }
    } catch (e) {
      print('❌ Error loading images: $e');
      if (mounted) {
        setState(() => _isLoadingImages = false);
      }
    }
  }

  Future<void> _checkFavoriteStatus() async {
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      final isFav = await _userService.isFavorite(user.id, widget.restaurant.id);
      if (mounted) setState(() => _isFavorite = isFav);
    }
  }
  
  /// 리뷰 목록 로드
  Future<void> _loadReviews() async {
    setState(() => _isLoadingReviews = true);
    
    try {
      final reviews = await _restaurantService.getRestaurantReviews(widget.restaurant.id);
      final summary = await _restaurantService.getRestaurantReviewSummary(widget.restaurant.id);
      
      // 현재 유저의 리뷰가 있는지 확인
      final currentUser = context.read<AuthService>().currentUser;
      bool hasUserReview = false;
      String? userReviewId;
      
      if (currentUser != null) {
        for (var review in reviews) {
          if (review.userId == currentUser.id) {
            hasUserReview = true;
            userReviewId = review.id;
            break;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _reviewSummary = summary;
          _hasUserReview = hasUserReview;
          _userReviewId = userReviewId;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      print('❌ Error loading reviews: $e');
      if (mounted) {
        setState(() => _isLoadingReviews = false);
      }
    }
  }
  
  /// 내 리뷰인지 확인
  bool _isMyReview(UserReview review) {
    final currentUser = context.read<AuthService>().currentUser;
    return currentUser != null && review.userId == currentUser.id;
  }
  
  /// 리뷰 수정 다이얼로그
  void _showEditReviewDialog(UserReview review) {
    final editController = TextEditingController(text: review.content ?? '');
    double editRating = review.rating.toDouble();
    List<ReviewPhoto> existingPhotos = List.from(review.photos);
    List<File> newPhotos = [];
    List<String> photosToDelete = []; // 삭제할 사진 ID 목록
    bool isUpdating = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('리뷰 수정'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 평점
                  const Text('평점', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () => setDialogState(() => editRating = index + 1.0),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            index < editRating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  
                  // 내용
                  const Text('내용', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: editController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: '리뷰 내용을 입력해주세요...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 기존 사진
                  const Text('사진', style: TextStyle(fontWeight: FontWeight.w600)),
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
                                        setDialogState(() {
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
                                        setDialogState(() {
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
                      final pickedFiles = await _imagePicker.pickMultiImage(
                        maxWidth: 1920,
                        maxHeight: 1920,
                      );
                      if (pickedFiles.isNotEmpty) {
                        final remainingSlots = _maxPhotos - (existingPhotos.length - photosToDelete.length + newPhotos.length);
                        final filesToAdd = pickedFiles.take(remainingSlots).map((f) => File(f.path)).toList();
                        setDialogState(() {
                          newPhotos.addAll(filesToAdd);
                        });
                      }
                    },
                    icon: const Icon(Icons.add_photo_alternate, size: 18),
                    label: Text('사진 추가 (${existingPhotos.length - photosToDelete.length + newPhotos.length}/$_maxPhotos)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: isUpdating ? null : () async {
                setDialogState(() => isUpdating = true);
                Navigator.pop(context);
                await _updateReviewWithPhotos(
                  review.id,
                  editRating.toInt(),
                  editController.text,
                  photosToDelete,
                  newPhotos,
                );
              },
              child: isUpdating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('수정'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 리뷰 삭제 확인 다이얼로그
  void _showDeleteReviewConfirmDialog(UserReview review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('리뷰 삭제'),
        content: const Text('정말 이 리뷰를 삭제하시겠습니까?\n삭제된 리뷰는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteReview(review.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  /// 리뷰 수정 실행 (사진 포함)
  Future<void> _updateReviewWithPhotos(
    String reviewId,
    int rating,
    String content,
    List<String> photosToDelete,
    List<File> newPhotos,
  ) async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    
    try {
      // 1. 리뷰 내용 수정
      await _restaurantService.updateReview(
        reviewId: reviewId,
        userId: user.id,
        rating: rating,
        content: content,
      );
      
      // 2. 삭제할 사진 처리
      for (var photoId in photosToDelete) {
        try {
          await _restaurantService.deleteReviewPhoto(
            photoId: photoId,
            restaurantId: widget.restaurant.id,
          );
        } catch (e) {
          print('⚠️ Failed to delete photo $photoId: $e');
        }
      }
      
      // 3. 새 사진 추가
      if (newPhotos.isNotEmpty) {
        await _restaurantService.uploadAndLinkReviewPhotos(
          restaurantId: widget.restaurant.id,
          userId: user.id,
          reviewId: reviewId,
          photos: newPhotos,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰가 수정되었습니다.')),
        );
        _loadReviews();
        _loadImages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('리뷰 수정 실패: $e')),
        );
      }
    }
  }
  
  /// 리뷰 수정 실행 (레거시 - 사진 없이)
  Future<void> _updateReview(String reviewId, int rating, String content) async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    
    try {
      await _restaurantService.updateReview(
        reviewId: reviewId,
        userId: user.id,
        rating: rating,
        content: content,
      );
      
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
  
  /// 리뷰 삭제 실행
  Future<void> _deleteReview(String reviewId) async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    
    try {
      await _restaurantService.deleteReview(
        reviewId: reviewId,
        userId: user.id,
        restaurantId: widget.restaurant.id,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰가 삭제되었습니다.')),
        );
        _loadReviews();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('리뷰 삭제 실패: $e')),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() => _isLoadingFavorite = true);
    try {
      final newStatus = await _userService.toggleFavorite(user.id, widget.restaurant.id);
      setState(() => _isFavorite = newStatus);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newStatus ? '즐겨찾기에 추가되었습니다.' : '즐겨찾기가 해제되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('작업 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label이(가) 복사되었습니다.'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// 공유하기 기능
  Future<void> _shareRestaurant() async {
    final restaurant = widget.restaurant;
    
    // 딥링크 또는 웹 URL 생성 (실제 서비스 URL로 변경 필요)
    final shareUrl = 'https://kofficer-guide.com/restaurant/${restaurant.id}';
    
    // 공유 템플릿 생성
    final shareText = '''[공무원맛집 가이드]

${restaurant.name}

${restaurant.address ?? restaurant.roadAddress ?? '주소 정보 없음'}

$shareUrl''';

    try {
      await Share.share(
        shareText,
        subject: '[공무원맛집 가이드] ${restaurant.name}',
      );
    } catch (e) {
      print('❌ Error sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공유하기에 실패했습니다.')),
        );
      }
    }
  }

  void _openNaverSearch(BuildContext context) {
    final query = Uri.encodeComponent(widget.restaurant.name);
    final url = 'https://m.search.naver.com/search.naver?query=$query';
    
    final mainState = MainScreen.globalKey.currentState;
    if (mainState != null) {
      mainState.navigateToTab(3, browserUrl: url);
    }
  }

  // 네이버 블로그 리뷰 버튼 클릭 - 하단 탭 '네이버'에서 검색
  void _openNaverBlogReview(BuildContext context) {
    // 검색어 조합: sub_add1 sub_add2 title
    final parts = <String>[];
    
    if (widget.restaurant.subAdd1 != null && widget.restaurant.subAdd1!.isNotEmpty) {
      parts.add(widget.restaurant.subAdd1!);
    }
    if (widget.restaurant.subAdd2 != null && widget.restaurant.subAdd2!.isNotEmpty) {
      parts.add(widget.restaurant.subAdd2!);
    }
    if (widget.restaurant.title != null && widget.restaurant.title!.isNotEmpty) {
      parts.add(widget.restaurant.title!);
    }
    
    // 검색어가 없으면 음식점 이름 사용
    final searchQuery = parts.isNotEmpty ? parts.join(' ') : widget.restaurant.name;
    final query = Uri.encodeComponent(searchQuery);
    final url = 'https://m.search.naver.com/search.naver?where=blog&query=$query';
    
    print('🔍 Naver blog search query: $searchQuery');
    
    final mainState = MainScreen.globalKey.currentState;
    if (mainState != null) {
      mainState.navigateToTab(3, browserUrl: url);
    }
  }

  /// 사진 선택 (갤러리/카메라)
  Future<void> _pickPhotos() async {
    if (_selectedPhotos.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('최대 $_maxPhotos장까지 선택할 수 있습니다.')),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () async {
                Navigator.pop(context);
                final remaining = _maxPhotos - _selectedPhotos.length;
                final pickedFiles = await _imagePicker.pickMultiImage(
                  imageQuality: 85,
                  maxWidth: 1920,
                  maxHeight: 1920,
                );
                
                if (pickedFiles.isNotEmpty) {
                  final files = pickedFiles
                      .take(remaining)
                      .map((xfile) => File(xfile.path))
                      .toList();
                  setState(() {
                    _selectedPhotos.addAll(files);
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () async {
                Navigator.pop(context);
                final pickedFile = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                  maxWidth: 1920,
                  maxHeight: 1920,
                );
                
                if (pickedFile != null) {
                  setState(() {
                    _selectedPhotos.add(File(pickedFile.path));
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  
  /// 선택한 사진 제거
  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  Future<void> _submitReview() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    if (_userRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('평점을 선택해주세요.')),
      );
      return;
    }

    setState(() => _isSubmittingReview = true);
    
    try {
      // 사진이 있으면 업로드 중 표시 및 진행률 초기화
      if (_selectedPhotos.isNotEmpty) {
        setState(() {
          _isUploadingPhotos = true;
          _uploadProgress = 0.0;
          _currentUploadIndex = 0;
          _totalUploadCount = _selectedPhotos.length;
        });
      }
      
      // 새로운 통합 함수 사용: 리뷰 등록 + 사진 업로드 + 음식점 사진 연동
      final result = await _restaurantService.submitReviewWithPhotos(
        restaurantId: widget.restaurant.id,
        userId: user.id,
        rating: _userRating,
        content: _reviewController.text.trim(),
        photos: _selectedPhotos.isNotEmpty ? _selectedPhotos : null,
        onProgress: (currentIndex, totalCount, progress) {
          if (mounted) {
            setState(() {
              _currentUploadIndex = currentIndex;
              _totalUploadCount = totalCount;
              _uploadProgress = progress;
            });
          }
        },
      );
      
      if (mounted) {
        // 성공 메시지 (대표 이미지 설정 여부에 따라 다른 메시지)
        String successMessage = '리뷰가 등록되었습니다.';
        if (result.primaryPhotoSet) {
          successMessage = '리뷰가 등록되었습니다. 사진이 음식점 대표 이미지로 설정되었습니다!';
        } else if (result.photoUrls.isNotEmpty) {
          successMessage = '리뷰가 등록되었습니다. 사진이 음식점 갤러리에 추가되었습니다!';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
        setState(() {
          _reviewController.clear();
          _userRating = 0;
          _selectedPhotos.clear();
        });
        // 리뷰 목록 및 이미지 새로고침
        _loadReviews();
        _loadImages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('리뷰 등록 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingReview = false;
          _isUploadingPhotos = false;
          _uploadProgress = 0.0;
          _currentUploadIndex = 0;
          _totalUploadCount = 0;
        });
      }
    }
  }

  // 이미지 로딩 실패 시 해당 URL 제거
  void _onImageLoadFailed(String url) {
    if (!_failedImageUrls.contains(url)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _failedImageUrls.add(url);
            _imageUrls.remove(url);
            // 현재 인덱스 조정
            if (_currentImageIndex >= _imageUrls.length && _imageUrls.isNotEmpty) {
              _currentImageIndex = _imageUrls.length - 1;
            }
          });
        }
      });
    }
  }

  // 사진 슬라이더 위젯 (맨 위에 표시)
  // 사진이 없거나 모든 사진 로딩에 실패하면 아무것도 표시하지 않음
  Widget _buildImageSlider() {
    if (_isLoadingImages) {
      return Container(
        height: 250,
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // 사진이 없으면 빈 위젯 반환 (사진 영역 숨김)
    if (_imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // 이미지 슬라이더
        SizedBox(
          height: 250,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _imageUrls.length,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              final imageUrl = _imageUrls[index];
              return Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  // 로딩 실패 시 해당 이미지 제거
                  _onImageLoadFailed(imageUrl);
                  // 임시로 빈 컨테이너 반환 (다음 빌드에서 제거됨)
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ),
        // 페이지 인디케이터 (하단)
        if (_imageUrls.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_imageUrls.length, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        // 사진 개수 표시 (우측 상단)
        if (_imageUrls.length > 1)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_currentImageIndex + 1} / ${_imageUrls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.restaurant.name,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        titleSpacing: 0,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖼️ 사진 슬라이더 (맨 위)
            _buildImageSlider(),
            
            // 사진 안내 문구
            if (_imageUrls.length > 1)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    '${_imageUrls.length}장의 사진이 있습니다. 좌우로 스크롤하여 모두 확인하세요.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280), // Gray 500 - 명도 대비 개선
                    ),
                  ),
                ),
              ),
            
            // 기본 정보 카드
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 음식점 이름
                  Text(
                    widget.restaurant.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // 평점
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        final rating = widget.restaurant.avgRating ?? 0;
                        return Icon(
                          index < rating.floor() 
                              ? Icons.star 
                              : (index < rating ? Icons.star_half : Icons.star_border),
                          color: Colors.amber,
                          size: 20,
                        );
                      }),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.restaurant.avgRating?.toStringAsFixed(1) ?? '0.0'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF374151),
                        ),
                      ),
                      Text(
                        ' (${widget.restaurant.reviewCount ?? 0}개 리뷰)',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // 카테고리
                  if (widget.restaurant.category != null) ...[
                    const Text(
                      '카테고리',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280), // Gray 500 - 명도 대비 개선
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.restaurant.category!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // 주소
                  if (widget.restaurant.address != null) ...[
                    _buildAddressRow(
                      label: '주소',
                      address: widget.restaurant.address!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // 도로명주소
                  if (widget.restaurant.roadAddress != null) ...[
                    _buildAddressRow(
                      label: '도로명주소',
                      address: widget.restaurant.roadAddress!,
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // 액션 버튼들
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingFavorite ? null : _toggleFavorite,
                      icon: _isLoadingFavorite 
                          ? const SizedBox(
                              width: 16, 
                              height: 16, 
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: _isFavorite ? Colors.red : const Color(0xFF6B7280),
                            ),
                      label: const Text('즐겨찾기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareRestaurant,
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('공유하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 네이버 블로그 리뷰 버튼
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: OutlinedButton.icon(
                onPressed: () => _openNaverBlogReview(context),
                icon: const Icon(Icons.edit_note, color: Color(0xFF03C75A)),
                label: const Text(
                  '네이버 블로그 리뷰',
                  style: TextStyle(color: Color(0xFF03C75A)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF03C75A)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // 통계 정보
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem('리뷰', '${widget.restaurant.reviewCount ?? 0}', Icons.rate_review),
                  Container(width: 1, height: 40, color: const Color(0xFFE5E7EB)),
                  _buildStatItem('평점', '${widget.restaurant.avgRating?.toStringAsFixed(1) ?? '0.0'}', Icons.star),
                  Container(width: 1, height: 40, color: const Color(0xFFE5E7EB)),
                  _buildStatItem('방문', '${widget.restaurant.visitCount ?? 0}', Icons.people),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // 사용자 리뷰 목록 섹션
            _buildUserReviewsSection(),
            
            const SizedBox(height: 8),
            
            // 리뷰 작성 섹션 (이미 리뷰를 작성한 경우 숨김)
            if (!_hasUserReview)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '리뷰 작성',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  // 별점 선택
                  const Text(
                    '평점을 선택해주세요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() => _userRating = index + 1.0);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              index < _userRating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 36,
                            ),
                          ),
                        );
                      }),
                      if (_userRating > 0)
                        Text(
                          '${_userRating.toInt()}점',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF374151),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 리뷰 텍스트 입력 (최소 4줄, 최대 8줄까지 확장, 이후 스크롤)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 200, // 최대 높이 제한 (약 8줄 정도)
                    ),
                    child: TextField(
                      controller: _reviewController,
                      minLines: 4,
                      maxLines: null, // 무제한으로 설정하되 ConstrainedBox가 제한
                      keyboardType: TextInputType.multiline,
                      scrollPhysics: const BouncingScrollPhysics(),
                      decoration: InputDecoration(
                        hintText: '이 음식점에 대한 리뷰를 작성해주세요...',
                        hintStyle: const TextStyle(color: Color(0xFF6B7280)), // Gray 500 - 명도 대비 개선
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 사진 추가 버튼
                  _buildPhotoPickerSection(),
                  const SizedBox(height: 16),
                  
                  // 리뷰 등록 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmittingReview ? null : _submitReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmittingReview
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              '리뷰 등록하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildAddressRow({required String label, required String address}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.location_on_outlined, color: Color(0xFF6B7280), size: 20), // Gray 500 - 명도 대비 개선
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280), // Gray 500 - 명도 대비 개선
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => _copyToClipboard(address, label),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.copy, size: 16, color: Color(0xFF6B7280)),
                SizedBox(width: 4),
                Text(
                  '복사',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF6B7280), size: 24), // Gray 500 - 명도 대비 개선
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
  
  /// 사용자 리뷰 목록 섹션
  Widget _buildUserReviewsSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '사용자 리뷰 (${_reviewSummary?.totalReviews ?? 0})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              if (_reviewSummary != null && _reviewSummary!.averageRating != null)
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      _reviewSummary!.averageRating!.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 리뷰 목록
          if (_isLoadingReviews)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_reviews.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.rate_review_outlined, size: 48, color: Color(0xFF6B7280)), // Gray 500 - 명도 대비 개선
                    SizedBox(height: 12),
                    Text(
                      '아직 리뷰가 없습니다',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '첫 번째 리뷰를 작성해보세요!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280), // Gray 500 - 명도 대비 개선
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reviews.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) => _buildReviewItem(_reviews[index]),
            ),
        ],
      ),
    );
  }
  
  /// 개별 리뷰 아이템
  Widget _buildReviewItem(UserReview review) {
    final dateFormat = DateFormat('yyyy년 M월 d일');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 사용자 정보 및 평점
        Row(
          children: [
            // 프로필 아바타
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF3B82F6),
              backgroundImage: review.user?.profileImageUrl != null
                  ? NetworkImage(review.user!.profileImageUrl!)
                  : null,
              child: review.user?.profileImageUrl == null
                  ? Text(
                      (review.user?.displayName ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            
            // 이름 및 평점
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.user?.displayName ?? '익명',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      // 별점
                      ...List.generate(5, (index) {
                        return Icon(
                          index < review.rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                      const SizedBox(width: 8),
                      Text(
                        '${review.rating}점',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 날짜
            Text(
              dateFormat.format(review.createdAt),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280), // Gray 500 - 명도 대비 개선
              ),
            ),
            
            // 내 리뷰인 경우 수정/삭제 버튼 표시
            if (_isMyReview(review))
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF6B7280)),
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditReviewDialog(review);
                  } else if (value == 'delete') {
                    _showDeleteReviewConfirmDialog(review);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18, color: Color(0xFF374151)),
                        SizedBox(width: 8),
                        Text('수정'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Color(0xFFEF4444)),
                        SizedBox(width: 8),
                        Text('삭제', style: TextStyle(color: Color(0xFFEF4444))),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        
        // 리뷰 내용
        if (review.content != null && review.content!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            review.content!,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF374151),
              height: 1.5,
            ),
          ),
        ],
        
        // 리뷰 사진
        if (review.photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: review.photos.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final photo = review.photos[index];
                return GestureDetector(
                  onTap: () => _showPhotoViewer(review.photos.map((p) => p.photoUrl).toList(), index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      photo.photoUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        
        // 좋아요/싫어요 버튼
        const SizedBox(height: 12),
        Row(
          children: [
            _buildReactionButton(
              icon: Icons.thumb_up_outlined,
              count: review.likeCount,
              onTap: () {
                // TODO: 좋아요 기능 구현
              },
            ),
            const SizedBox(width: 16),
            _buildReactionButton(
              icon: Icons.thumb_down_outlined,
              count: review.dislikeCount,
              onTap: () {
                // TODO: 싫어요 기능 구현
              },
            ),
          ],
        ),
      ],
    );
  }
  
  /// 좋아요/싫어요 버튼 - Apple HIG: 최소 44x44pt 터치 영역 확보
  Widget _buildReactionButton({
    required IconData icon,
    required int count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44), // Apple HIG 최소 터치 영역
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 사진 뷰어 표시
  void _showPhotoViewer(List<String> photos, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  child: Center(
                    child: Image.network(
                      photos[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 사진 선택 섹션
  Widget _buildPhotoPickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '사진 추가 (선택)',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            Text(
              '${_selectedPhotos.length}/$_maxPhotos',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280), // Gray 500 - 명도 대비 개선
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // 선택된 사진 미리보기 + 추가 버튼
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // 사진 추가 버튼
              if (_selectedPhotos.length < _maxPhotos)
                GestureDetector(
                  onTap: _pickPhotos,
                  child: Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFF9FAFB),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, color: Color(0xFF6B7280), size: 28), // Gray 500 - 명도 대비 개선
                        SizedBox(height: 4),
                        Text(
                          '사진 추가',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280), // Gray 500 - 명도 대비 개선
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // 선택된 사진들
              ..._selectedPhotos.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(file),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // Apple HIG: 최소 44x44pt 터치 영역 확보
                    Positioned(
                      top: -8,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _removePhoto(index),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
        
        // 안내 문구
        if (_selectedPhotos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '사진은 자동으로 500KB 미만으로 압축됩니다.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ),
        
        // 업로드 중 진행률 표시
        if (_isUploadingPhotos)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '사진 업로드 중... ($_currentUploadIndex/$_totalUploadCount)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(_uploadProgress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
