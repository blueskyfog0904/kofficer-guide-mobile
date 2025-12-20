import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/restaurant.dart';
import '../models/region.dart';
import '../services/restaurant_service.dart';
import '../services/map_height_service.dart';
import 'restaurant_detail_screen.dart';

class RegionSearchScreen extends StatefulWidget {
  const RegionSearchScreen({super.key});

  @override
  State<RegionSearchScreen> createState() => _RegionSearchScreenState();
}

class _RegionSearchScreenState extends State<RegionSearchScreen> {
  List<Restaurant> _restaurants = [];
  List<Region> _regions = [];
  String? _selectedProvince;
  String? _selectedDistrict;
  bool _isLoading = false;
  bool _searchPerformed = false;
  bool _isExpanded = true;
  String? _lastClickedRestaurantId;
  List<Map<String, dynamic>> _restaurantMarkers = [];
  
  // 음식점 첫 번째 사진 캐시 (primary_photo_url이 없는 음식점용)
  final Map<String, String> _restaurantPhotos = {};
  
  InAppWebViewController? _webViewController;
  bool _isMapReady = false;
  String? _mapHtmlContent;

  List<String> _provinces = [];
  List<Region> _districts = [];
  
  final ScrollController _listScrollController = ScrollController();
  
  // 리스트 영역 높이 옵션 (0: 작게, 1: 중간, 2: 크게, 3: 전체)
  int _listSizeIndex = 1;
  final List<double> _listHeightFactors = [0.25, 0.4, 0.6, 1.0];

  @override
  void initState() {
    super.initState();
    _fetchRegions();
    _loadMapHtml();
    _loadSavedListSize();
  }
  
  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedListSize() async {
    final savedIndex = await MapHeightService.loadRegionSearchSnapIndex();
    setState(() {
      _listSizeIndex = savedIndex.clamp(0, 3);
    });
  }

  void _onListSizeChanged(int index) {
    if (_listSizeIndex != index) {
      setState(() {
        _listSizeIndex = index;
      });
      MapHeightService.saveRegionSearchSnapIndex(index);
      
      // 지도 크기 변경 후 relayout 트리거
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_webViewController != null && _isMapReady) {
          _webViewController!.evaluateJavascript(source: 'if(map) map.relayout();');
        }
      });
    }
  }

  Future<void> _loadMapHtml() async {
    try {
      String htmlContent = await rootBundle.loadString('assets/kakao_map.html');
      final jsKey = dotenv.env['KAKAO_JAVASCRIPT_KEY'] ?? '';
      htmlContent = htmlContent.replaceAll('KAKAO_JS_KEY_PLACEHOLDER', jsKey);
      setState(() {
        _mapHtmlContent = htmlContent;
      });
    } catch (e) {
      print('❌ Error loading map HTML: $e');
    }
  }

  Future<void> _fetchRegions() async {
    setState(() => _isLoading = true);
    try {
      final regionsData = await RestaurantService().getRegions();
      final fetchedRegions = regionsData.map((e) => Region.fromJson(e)).toList();
      setState(() {
        _regions = fetchedRegions;
        _provinces = fetchedRegions.map((r) => r.name).toSet().toList()..sort();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지역 정보를 불러오는 데 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onProvinceChanged(String? province) {
    setState(() {
      _selectedProvince = province;
      _selectedDistrict = null;
      _searchPerformed = false;
      _restaurants = [];
      if (province != null) {
        _districts = _regions
            .where((r) => r.name == province && r.subName.isNotEmpty)
            .toList()
          ..sort((a, b) => a.subName.compareTo(b.subName));
      } else {
        _districts = [];
      }
    });
  }

  Future<void> _handleSearch() async {
    if (_selectedProvince == null || _selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시/도와 시/군/구를 모두 선택해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _searchPerformed = true;
      _isExpanded = false;
      _lastClickedRestaurantId = null;
      _isMapReady = false;
    });

    try {
      final results = await RestaurantService().searchRestaurants(
        regionId: '$_selectedProvince|$_selectedDistrict',
      );
      
      final markers = <Map<String, dynamic>>[];
      for (var i = 0; i < results.length; i++) {
        final restaurant = results[i];
        if (restaurant.latitude != null && restaurant.longitude != null) {
          final rank = restaurant.regionRank ?? (i + 1);
          markers.add({
            'id': restaurant.id,
            'lat': restaurant.latitude!,
            'lng': restaurant.longitude!,
            'rank': rank,
            'name': restaurant.title ?? restaurant.name,
          });
        }
      }
      
      setState(() {
        _restaurants = results;
        _restaurantMarkers = markers;
      });
      
      // primary_photo_url이 없는 음식점들의 첫 번째 사진 일괄 조회
      _fetchMissingPhotos(results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('검색 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// primary_photo_url이 없는 음식점들의 첫 번째 사진을 일괄 조회
  Future<void> _fetchMissingPhotos(List<Restaurant> restaurants) async {
    final idsWithoutPhoto = restaurants
        .where((r) => r.primaryPhotoUrl == null || r.primaryPhotoUrl!.isEmpty)
        .map((r) => r.id)
        .toList();
    
    if (idsWithoutPhoto.isEmpty) return;
    
    try {
      final photos = await RestaurantService().getFirstPhotosForRestaurants(idsWithoutPhoto);
      if (mounted && photos.isNotEmpty) {
        setState(() {
          _restaurantPhotos.addAll(photos);
        });
      }
    } catch (e) {
      print('Error fetching missing photos: $e');
    }
  }

  Future<void> _initializeMap() async {
    if (_webViewController == null || _restaurantMarkers.isEmpty) {
      return;
    }

    double centerLat = 37.5665;
    double centerLng = 126.9780;
    
    if (_restaurantMarkers.isNotEmpty) {
      centerLat = _restaurantMarkers[0]['lat'];
      centerLng = _restaurantMarkers[0]['lng'];
    }

    final markersJson = jsonEncode(_restaurantMarkers);
    
    try {
      await _webViewController!.evaluateJavascript(
        source: 'initializeMap($centerLat, $centerLng, \'${markersJson.replaceAll("'", "\\'")}\');',
      );
      setState(() {
        _isMapReady = true;
      });
    } catch (e) {
      print('❌ Error initializing map: $e');
    }
  }

  void _selectMarkerAndMoveCamera(String restaurantId) async {
    if (_webViewController == null || !_isMapReady) return;
    
    try {
      await _webViewController!.evaluateJavascript(
        source: '''
          (function() {
            if(map) {
              map.relayout();
              setTimeout(function() {
                selectMarker("$restaurantId");
              }, 100);
            }
          })();
        ''',
      );
    } catch (e) {
      print('❌ Error selecting marker: $e');
    }
  }
  
  void _scrollToRestaurant(int index) {
    if (_listScrollController.hasClients) {
      const cardTotalHeight = 112.0; // 이미지 높이(100) + 마진(12)
      final scrollPosition = cardTotalHeight * index;
      
      _listScrollController.animateTo(
        scrollPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _zoomIn() async {
    if (_webViewController == null || !_isMapReady) return;
    try {
      await _webViewController!.evaluateJavascript(source: 'zoomIn();');
    } catch (e) {}
  }

  void _zoomOut() async {
    if (_webViewController == null || !_isMapReady) return;
    try {
      await _webViewController!.evaluateJavascript(source: 'zoomOut();');
    } catch (e) {}
  }

  void _handleReset() {
    setState(() {
      _selectedProvince = null;
      _selectedDistrict = null;
      _districts = [];
      _restaurants = [];
      _searchPerformed = false;
      _isExpanded = true;
      _webViewController = null;
      _isMapReady = false;
      _restaurantMarkers = [];
      _lastClickedRestaurantId = null;
    });
  }

  Widget _buildRegionSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
                if (_isExpanded) {
                  _searchPerformed = false;
                  _restaurants = [];
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _searchPerformed && _selectedProvince != null && _selectedDistrict != null
                          ? '$_selectedProvince $_selectedDistrict'
                          : '지역 선택',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('시도', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedProvince,
                    hint: const Text('시도를 선택하세요'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2)),
                    ),
                    onChanged: _onProvinceChanged,
                    items: _provinces.map((province) => DropdownMenuItem<String>(value: province, child: Text(province))).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('시군구', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedDistrict,
                    hint: const Text('시군구를 선택하세요'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: _selectedProvince == null,
                      fillColor: _selectedProvince == null ? const Color(0xFFF3F4F6) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _selectedProvince == null ? const Color(0xFFE5E7EB) : const Color(0xFFD1D5DB))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2)),
                    ),
                    onChanged: _selectedProvince == null ? null : (String? newValue) {
                      setState(() {
                        _selectedDistrict = newValue;
                        _searchPerformed = false;
                        _restaurants = [];
                      });
                    },
                    items: _districts.map((region) => DropdownMenuItem<String>(value: region.subName, child: Text(region.subName))).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          onPressed: (_selectedProvince != null && _selectedDistrict != null && !_isLoading) ? _handleSearch : null,
                          icon: const Icon(Icons.search),
                          label: Text(_isLoading ? '검색 중...' : '검색'),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: _handleReset,
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                          child: const Text('초기화'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKakaoMap() {
    if (_mapHtmlContent == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InAppWebView(
            initialData: InAppWebViewInitialData(
              data: _mapHtmlContent!,
              mimeType: 'text/html',
              encoding: 'utf-8',
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              useHybridComposition: true,
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              
              controller.addJavaScriptHandler(
                handlerName: 'onMarkerClick',
                callback: (args) {
                  if (args.length >= 2) {
                    final restaurantId = args[0] as String;
                    final isDoubleClick = args.length >= 3 ? (args[2] as bool? ?? false) : false;
                    
                    final restaurantIndex = _restaurants.indexWhere((r) => r.id == restaurantId);
                    if (restaurantIndex == -1) return null;
                    
                    final restaurant = _restaurants[restaurantIndex];
                    
                    // 더블클릭 시 상세 페이지로 이동
                    if (isDoubleClick) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RestaurantDetailScreen(restaurant: restaurant),
                        ),
                      );
                    } else {
                      // 싱글 클릭 시 선택 효과만 적용
                      setState(() {
                        _lastClickedRestaurantId = restaurant.id;
                      });
                      _scrollToRestaurant(restaurantIndex);
                    }
                  }
                  return null;
                },
              );
              
              // 클러스터 클릭 핸들러
              controller.addJavaScriptHandler(
                handlerName: 'onClusterClick',
                callback: (args) {
                  if (args.length >= 3) {
                    final count = args[0] as int;
                    final lat = args[1] as double;
                    final lng = args[2] as double;
                    print('🔍 Cluster clicked: $count restaurants at ($lat, $lng)');
                  }
                  return null;
                },
              );
            },
            onLoadStop: (controller, url) async {
              await Future.delayed(const Duration(milliseconds: 500));
              await _initializeMap();
            },
          ),
        ),
        Positioned(
          right: 16,
          top: 16,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: IconButton(icon: const Icon(Icons.add, color: Color(0xFF1F2937)), onPressed: _zoomIn),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: IconButton(icon: const Icon(Icons.remove, color: Color(0xFF1F2937)), onPressed: _zoomOut),
              ),
            ],
          ),
        ),
        if (!_isMapReady)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  // 이미지가 없을 때 표시할 플레이스홀더 위젯
  Widget _buildImagePlaceholder() {
    return Container(
      height: 100,
      width: 100,
      color: const Color(0xFFF3F4F6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/images/project_logo.png',
              height: 50,
              width: 50,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.restaurant,
                size: 40,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '이미지 준비 중',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(Restaurant restaurant, int index, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (_lastClickedRestaurantId == restaurant.id) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RestaurantDetailScreen(restaurant: restaurant),
            ),
          );
        } else {
          setState(() {
            _lastClickedRestaurantId = restaurant.id;
          });
          _selectMarkerAndMoveCamera(restaurant.id);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${restaurant.title ?? restaurant.name} - 다시 탭하면 상세 페이지로 이동'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isSelected 
              ? Border.all(color: const Color(0xFF3B82F6), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: Stack(
                children: [
                  // 이미지 또는 플레이스홀더
                  // 1. primaryPhotoUrl 확인, 2. _restaurantPhotos 캐시 확인
                  Builder(
                    builder: (context) {
                      final photoUrl = restaurant.primaryPhotoUrl?.isNotEmpty == true
                          ? restaurant.primaryPhotoUrl!
                          : _restaurantPhotos[restaurant.id];
                      
                      if (photoUrl != null && photoUrl.isNotEmpty) {
                        return CachedNetworkImage(
                          imageUrl: photoUrl,
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 100,
                            width: 100,
                            color: const Color(0xFFF3F4F6),
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => _buildImagePlaceholder(),
                        );
                      } else {
                        return _buildImagePlaceholder();
                      }
                    },
                  ),
                  // 인덱스 배지 (1, 2, 3...)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 음식점 이름 (title 사용)
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            restaurant.title ?? restaurant.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (restaurant.category != null)
                      Text(
                        restaurant.category!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${restaurant.avgRating?.toStringAsFixed(1) ?? '0.0'}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.comment_outlined, size: 16, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text('${restaurant.reviewCount ?? 0}', style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                        // 순위 배지 (공무원 N위) - 별점/리뷰 옆에 배치
                        if (restaurant.regionRank != null) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '공무원 ${restaurant.regionRank}위',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListSizeButton(int index, String label) {
    final isSelected = _listSizeIndex == index;
    return GestureDetector(
      onTap: () => _onListSizeChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantList(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더 + 크기 조절 버튼
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
            ),
            child: Row(
              children: [
                Text(
                  '검색 결과 (${_restaurants.length}개)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                _buildListSizeButton(0, '작게'),
                const SizedBox(width: 6),
                _buildListSizeButton(1, '중간'),
                const SizedBox(width: 6),
                _buildListSizeButton(2, '크게'),
                const SizedBox(width: 6),
                _buildListSizeButton(3, '전체'),
              ],
            ),
          ),
          // 리스트 (독립적인 스크롤 영역)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _restaurants.isEmpty
                    ? const Center(child: Text('검색 결과가 없습니다.'))
                    : GestureDetector(
                        onVerticalDragStart: (_) {},
                        onVerticalDragUpdate: (_) {},
                        onVerticalDragEnd: (_) {},
                        child: ListView.builder(
                          controller: _listScrollController,
                          padding: const EdgeInsets.all(16),
                          physics: const ClampingScrollPhysics(),
                          itemCount: _restaurants.length,
                          itemBuilder: (context, index) {
                            final restaurant = _restaurants[index];
                            final isSelected = _lastClickedRestaurantId == restaurant.id;
                            
                            return _buildRestaurantCard(restaurant, index, isSelected);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildRegionSelector(),

            if (_isLoading && !_searchPerformed)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_searchPerformed && _restaurants.isEmpty && !_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('검색 결과가 없습니다', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        '선택하신 $_selectedProvince $_selectedDistrict 지역에서\n등록된 맛집을 찾을 수 없습니다.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else if (_searchPerformed && _restaurants.isNotEmpty)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final listHeight = constraints.maxHeight * _listHeightFactors[_listSizeIndex];
                    final mapHeight = constraints.maxHeight - listHeight;
                    
                    return Column(
                      children: [
                        // 지도 영역
                        SizedBox(
                          height: mapHeight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildKakaoMap(),
                          ),
                        ),
                        // 리스트 영역 (완전히 분리된 영역)
                        _buildRestaurantList(listHeight),
                      ],
                    );
                  },
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('지역을 선택해주세요', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        '상단의 시도와 시군구를 선택한 후\n검색 버튼을 눌러주세요.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
