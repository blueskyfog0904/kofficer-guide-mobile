import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/restaurant.dart';
import '../models/region.dart';
import '../services/restaurant_service.dart';
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
  bool _isExpanded = true; // 지역 선택 영역 확장 상태
  String? _lastClickedRestaurantId; // 마지막으로 클릭한 음식점 ID
  List<Map<String, dynamic>> _restaurantMarkers = []; // 마커 데이터 저장
  
  // WebView 관련
  InAppWebViewController? _webViewController;
  bool _isMapReady = false;
  String? _mapHtmlContent;

  // 시/도 목록 (고유값)
  List<String> _provinces = [];
  // 선택된 시/도의 시/군/구 목록
  List<Region> _districts = [];

  @override
  void initState() {
    super.initState();
    _fetchRegions();
    _loadMapHtml();
  }

  Future<void> _loadMapHtml() async {
    try {
      String htmlContent = await rootBundle.loadString('assets/kakao_map.html');
      // JavaScript 키를 동적으로 주입
      final jsKey = dotenv.env['KAKAO_JAVASCRIPT_KEY'] ?? '';
      htmlContent = htmlContent.replaceAll('KAKAO_JS_KEY_PLACEHOLDER', jsKey);
      setState(() {
        _mapHtmlContent = htmlContent;
      });
      print('✅ Map HTML loaded with JS Key');
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
        // 시/도 목록 추출 (중복 제거 및 정렬)
        _provinces = fetchedRegions
            .map((r) => r.name)
            .toSet()
            .toList()
          ..sort();
      });
      print('✅ Loaded ${fetchedRegions.length} regions, ${_provinces.length} provinces');
    } catch (e) {
      print('Error fetching regions: $e');
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
      _searchPerformed = false; // 지역 변경 시 검색 결과 및 맵 숨기기
      _restaurants = []; // 기존 검색 결과 초기화
      // 선택된 시/도에 해당하는 시/군/구 필터링 및 정렬
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
      _isExpanded = false; // 검색 시 지역 선택 영역 접기
      _lastClickedRestaurantId = null; // 클릭 상태 초기화
      _isMapReady = false; // 지도 재초기화
    });

    try {
      final results = await RestaurantService().searchRestaurants(
        regionId: '$_selectedProvince|$_selectedDistrict',
      );
      
      // 좌표가 있는 음식점 개수 확인
      final validRestaurants = results.where((r) => 
        r.latitude != null && r.longitude != null
      ).toList();
      print('📍 Restaurants with coordinates: ${validRestaurants.length} / ${results.length}');
      
      // 마커 데이터 저장
      final markers = <Map<String, dynamic>>[];
      for (var i = 0; i < results.length; i++) {
        final restaurant = results[i];
        if (restaurant.latitude != null && restaurant.longitude != null) {
          final rank = restaurant.rankPosition ?? (i + 1);
          markers.add({
            'id': restaurant.id,
            'lat': restaurant.latitude!,
            'lng': restaurant.longitude!,
            'rank': rank,
            'name': restaurant.name,
          });
        }
      }
      
      setState(() {
        _restaurants = results;
        _restaurantMarkers = markers; // 마커 데이터 저장
      });
      
      print('✅ Created ${markers.length} markers for map');
      print('✅ Found ${results.length} restaurants for map display');
    } catch (e) {
      print('Search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('검색 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 지도 초기화 (WebView 로드 완료 후 호출)
  Future<void> _initializeMap() async {
    if (_webViewController == null || _restaurantMarkers.isEmpty) {
      print('⚠️ WebView not ready or no markers');
      return;
    }

    // 중심 좌표 계산
    double centerLat = 37.5665;
    double centerLng = 126.9780;
    
    if (_restaurantMarkers.isNotEmpty) {
      centerLat = _restaurantMarkers[0]['lat'];
      centerLng = _restaurantMarkers[0]['lng'];
    }

    final markersJson = jsonEncode(_restaurantMarkers);
    
    try {
      final result = await _webViewController!.evaluateJavascript(
        source: 'initializeMap($centerLat, $centerLng, \'${markersJson.replaceAll("'", "\\'")}\');',
      );
      print('✅ Map initialized: $result');
      setState(() {
        _isMapReady = true;
      });
    } catch (e) {
      print('❌ Error initializing map: $e');
    }
  }

  // 카메라 이동
  Future<void> _moveCamera(double lat, double lng) async {
    if (_webViewController == null || !_isMapReady) return;
    
    try {
      await _webViewController!.evaluateJavascript(
        source: 'moveCamera($lat, $lng);',
      );
      print('✅ Camera moved to: $lat, $lng');
    } catch (e) {
      print('❌ Error moving camera: $e');
    }
  }

  // 마커 선택 (하이라이트)
  Future<void> _selectMarker(String restaurantId) async {
    if (_webViewController == null || !_isMapReady) return;
    
    try {
      await _webViewController!.evaluateJavascript(
        source: 'selectMarker("$restaurantId");',
      );
      print('✅ Marker selected: $restaurantId');
    } catch (e) {
      print('❌ Error selecting marker: $e');
    }
  }

  Widget _buildKakaoMap() {
    if (_mapHtmlContent == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        InAppWebView(
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
            
            // Flutter에서 JavaScript 호출 핸들러 등록
            controller.addJavaScriptHandler(
              handlerName: 'onMarkerClick',
              callback: (args) {
                if (args.length >= 2) {
                  final restaurantId = args[0] as String;
                  final restaurantName = args[1] as String;
                  print('📍 Marker clicked: $restaurantName ($restaurantId)');
                  
                  // 해당 음식점 찾기
                  final restaurant = _restaurants.firstWhere(
                    (r) => r.id == restaurantId,
                    orElse: () => _restaurants.first,
                  );
                  
                  // 상세 페이지로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RestaurantDetailScreen(restaurant: restaurant),
                    ),
                  );
                }
                return null;
              },
            );
          },
          onLoadStop: (controller, url) async {
            print('✅ WebView loaded');
            // 약간의 지연 후 지도 초기화
            await Future.delayed(const Duration(milliseconds: 500));
            await _initializeMap();
          },
          onConsoleMessage: (controller, consoleMessage) {
            print('🌐 WebView Console: ${consoleMessage.message}');
          },
        ),
        // 지도 컨트롤 버튼들
        Positioned(
          right: 16,
          top: 16,
          child: Column(
            children: [
              // 확대 버튼
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFF1F2937)),
                  onPressed: _zoomIn,
                  tooltip: '확대',
                ),
              ),
              const SizedBox(height: 8),
              // 축소 버튼
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.remove, color: Color(0xFF1F2937)),
                  onPressed: _zoomOut,
                  tooltip: '축소',
                ),
              ),
            ],
          ),
        ),
        // 로딩 인디케이터
        if (!_isMapReady)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  // 지도 확대
  void _zoomIn() async {
    if (_webViewController == null || !_isMapReady) return;
    
    try {
      await _webViewController!.evaluateJavascript(source: 'zoomIn();');
    } catch (e) {
      print('❌ Error zooming in: $e');
    }
  }

  // 지도 축소
  void _zoomOut() async {
    if (_webViewController == null || !_isMapReady) return;
    
    try {
      await _webViewController!.evaluateJavascript(source: 'zoomOut();');
    } catch (e) {
      print('❌ Error zooming out: $e');
    }
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
      _restaurantMarkers = []; // 마커 데이터 초기화
      _lastClickedRestaurantId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
        children: [
          // 지역 선택 영역 (접을 수 있음)
          Container(
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
                // 헤더 (클릭 시 접기/펼치기)
                InkWell(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                      // 지역 선택 영역을 다시 펼칠 때 지도와 검색 결과 숨김
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
                // 펼쳐진 내용
                if (_isExpanded) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 시/도 선택
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '시도',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedProvince,
                              hint: const Text('시도를 선택하세요'),
                              isExpanded: true,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                                ),
                              ),
                              onChanged: _onProvinceChanged,
                              items: _provinces.map((province) {
                                return DropdownMenuItem<String>(
                                  value: province,
                                  child: Text(province),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // 시/군/구 선택
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '시군구',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedDistrict,
                              hint: const Text('시군구를 선택하세요'),
                              isExpanded: true,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                filled: _selectedProvince == null,
                                fillColor: _selectedProvince == null ? const Color(0xFFF3F4F6) : Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: _selectedProvince == null ? const Color(0xFFE5E7EB) : const Color(0xFFD1D5DB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: _selectedProvince == null ? const Color(0xFFE5E7EB) : const Color(0xFFD1D5DB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                              ),
                              onChanged: _selectedProvince == null
                                  ? null
                                  : (String? newValue) {
                                      setState(() {
                                        _selectedDistrict = newValue;
                                        _searchPerformed = false; // 지역 변경 시 검색 결과 및 맵 숨기기
                                        _restaurants = []; // 기존 검색 결과 초기화
                                      });
                                    },
                              items: _districts.map((region) {
                                return DropdownMenuItem<String>(
                                  value: region.subName,
                                  child: Text(region.subName),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // 검색 & 초기화 버튼
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                onPressed: (_selectedProvince != null &&
                                        _selectedDistrict != null &&
                                        !_isLoading)
                                    ? _handleSearch
                                    : null,
                                icon: const Icon(Icons.search),
                                label: Text(_isLoading ? '검색 중...' : '검색'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                onPressed: _handleReset,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
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
          ),

          // 카카오 지도 (검색 완료 후 표시) - 높이 확대
          if (_searchPerformed && _restaurants.isNotEmpty)
            Container(
              height: 350, // 300 -> 350으로 높이 확대 (AppBar 제거로 확보된 공간 활용)
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildKakaoMap(),
              ),
            ),

          const SizedBox(height: 12),

          // 검색 결과
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_searchPerformed && _restaurants.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      '검색 결과가 없습니다',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '선택하신 $_selectedProvince $_selectedDistrict 지역에서\n등록된 맛집을 찾을 수 없습니다.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
            )
          else if (_searchPerformed && _restaurants.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '검색 결과 (${_restaurants.length}개 음식점)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _restaurants.length,
                      itemBuilder: (context, index) {
                        final restaurant = _restaurants[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              // 첫 번째 클릭: 지도 이동
                              if (_lastClickedRestaurantId != restaurant.id) {
                                if (restaurant.latitude != null && restaurant.longitude != null) {
                                  setState(() {
                                    _lastClickedRestaurantId = restaurant.id;
                                  });
                                  
                                  // 지도 카메라 이동 및 마커 선택
                                  _selectMarker(restaurant.id);
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${restaurant.name} 위치로 이동했습니다. 다시 클릭하면 상세 페이지로 이동합니다.'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                              // 두 번째 클릭: 상세 페이지 이동
                              else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        RestaurantDetailScreen(restaurant: restaurant),
                                  ),
                                );
                                setState(() {
                                  _lastClickedRestaurantId = null; // 초기화
                                });
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // 순위 배지
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // 음식점 이미지
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: restaurant.primaryPhotoUrl != null
                                        ? Image.network(
                                            restaurant.primaryPhotoUrl!,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                width: 80,
                                                height: 80,
                                                color: Colors.grey[200],
                                                child: const Icon(
                                                  Icons.restaurant,
                                                  size: 40,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                          )
                                        : Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.restaurant,
                                              size: 40,
                                              color: Colors.grey,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  // 음식점 정보
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                restaurant.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF3B82F6).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '${index + 1}위',
                                                style: const TextStyle(
                                                  color: Color(0xFF3B82F6),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          restaurant.address ??
                                              restaurant.roadAddress ??
                                              '주소 정보 없음',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: Colors.grey),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (restaurant.avgRating != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                color: Colors.amber,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${restaurant.avgRating!.toStringAsFixed(1)} (${restaurant.reviewCount ?? 0})',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          else
            // 초기 상태
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.map, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      '지역을 선택해주세요',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '상단의 시도와 시군구를 선택한 후\n검색 버튼을 눌러주세요.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
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
