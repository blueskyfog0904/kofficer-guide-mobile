import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/restaurant.dart';
import '../services/restaurant_service.dart';
import 'restaurant_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final RestaurantService _restaurantService = RestaurantService();
  
  // 위치 관련
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String? _locationError;
  
  // 거리 선택 (기본 5km)
  double _selectedRadius = 5.0;
  
  // 음식점 데이터
  List<Restaurant> _restaurants = [];
  bool _isLoadingRestaurants = false;
  
  // WebView 관련
  InAppWebViewController? _webViewController;
  bool _isMapReady = false;
  bool _isWebViewLoaded = false; // WebView 로드 완료 여부
  String? _mapHtmlContent;
  
  // 마커 데이터
  List<Map<String, dynamic>> _restaurantMarkers = [];
  
  // 지도 초기화 대기 플래그
  bool _pendingMapInit = false;
  
  // 마지막으로 클릭한 음식점 ID (더블클릭 감지용)
  String? _lastClickedRestaurantId;
  
  // 음식점별 거리 정보
  Map<String, double> _restaurantDistances = {};
  
  // 하단 리스트 스크롤 컨트롤러
  final ScrollController _listScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMapHtml();
    _getCurrentLocation();
  }
  
  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMapHtml() async {
    try {
      String htmlContent = await rootBundle.loadString('assets/kakao_map.html');
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

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      // 위치 서비스 활성화 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = '위치 서비스가 비활성화되어 있습니다.\n기기 설정에서 위치 서비스를 켜주세요.';
          _isLoadingLocation = false;
        });
        return;
      }

      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = '위치 권한이 거부되었습니다.\n주변 맛집을 찾으려면 위치 권한이 필요합니다.';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = '위치 권한이 영구적으로 거부되었습니다.\n설정에서 위치 권한을 허용해주세요.';
          _isLoadingLocation = false;
        });
        return;
      }

      // 현재 위치 가져오기
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('✅ Current location: ${position.latitude}, ${position.longitude}');

      // 한국 좌표 범위 확인 (위도 33~43, 경도 124~132)
      // 범위 밖이면 에뮬레이터나 해외로 간주하여 서울 기본 좌표 사용
      final bool isInKorea = _isLocationInKorea(position.latitude, position.longitude);
      
      if (isInKorea) {
        // 실제 한국 내 위치 - 그대로 사용
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
        print('📍 Using actual location (Korea)');
      } else {
        // 에뮬레이터나 해외 위치 - 테스트용 서울 기본 좌표 사용
        setState(() {
          _currentPosition = Position(
            latitude: 37.5665,
            longitude: 126.9780,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
          _isLoadingLocation = false;
        });
        print('⚠️ Location outside Korea (${position.latitude}, ${position.longitude}) - Using default Seoul location for testing');
      }

      // 위치를 가져온 후 주변 음식점 검색
      _searchNearbyRestaurants();
    } catch (e) {
      print('❌ Error getting location: $e');
      setState(() {
        _locationError = '위치를 가져오는 중 오류가 발생했습니다.\n다시 시도해주세요.';
        _isLoadingLocation = false;
      });
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
  
  /// 좌표가 한국 범위 내에 있는지 확인
  /// 한국 범위: 위도 33~43, 경도 124~132
  bool _isLocationInKorea(double latitude, double longitude) {
    const double minLat = 33.0;  // 제주도 남쪽
    const double maxLat = 43.0;  // 북한 북쪽
    const double minLng = 124.0; // 서해
    const double maxLng = 132.0; // 동해 (독도 포함)
    
    return latitude >= minLat && 
           latitude <= maxLat && 
           longitude >= minLng && 
           longitude <= maxLng;
  }
  
  /// 거리를 보기 좋게 포맷팅
  String _formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m';
    } else {
      return '${distanceKm.toStringAsFixed(1)}km';
    }
  }

  Future<void> _searchNearbyRestaurants() async {
    if (_currentPosition == null) return;

    setState(() {
      _isLoadingRestaurants = true;
      _isMapReady = false;
      _lastClickedRestaurantId = null; // 클릭 상태 초기화
    });

    try {
      // 선택된 반경으로 주변 음식점 검색 (Web과 동일한 Bounding Box 방식)
      final restaurants = await _restaurantService.getNearbyRestaurants(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radiusKm: _selectedRadius,
        limit: 2000, // 충분히 많이 가져오기
      );

      // 마커 데이터 생성 (거리 정보 포함)
      final markers = <Map<String, dynamic>>[];
      final distances = <String, double>{};
      
      for (int i = 0; i < restaurants.length; i++) {
        final r = restaurants[i];
        if (r.latitude != null && r.longitude != null) {
          // 거리 계산
          final distance = _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            r.latitude!,
            r.longitude!,
          );
          distances[r.id] = distance;
          
          markers.add({
            'id': r.id,
            'name': r.name,
            'lat': r.latitude,
            'lng': r.longitude,
            'rank': i + 1,
            'distance': _formatDistance(distance), // 거리 정보 추가
          });
        }
      }

      setState(() {
        _restaurants = restaurants;
        _restaurantMarkers = markers;
        _restaurantDistances = distances;
        _isLoadingRestaurants = false;
      });

      print('✅ Found ${restaurants.length} nearby restaurants');

      // 지도 초기화 - WebView가 로드된 경우에만
      if (_webViewController != null && _isWebViewLoaded) {
        await _initializeMap();
      } else {
        // WebView가 아직 로드되지 않았으면 대기 플래그 설정
        _pendingMapInit = true;
      }
    } catch (e) {
      print('❌ Error searching nearby restaurants: $e');
      setState(() {
        _isLoadingRestaurants = false;
      });
    }
  }

  Future<void> _initializeMap() async {
    if (_webViewController == null || _currentPosition == null || !_isWebViewLoaded) {
      print('⚠️ WebView or position not ready (webView: ${_webViewController != null}, position: ${_currentPosition != null}, loaded: $_isWebViewLoaded)');
      return;
    }

    final centerLat = _currentPosition!.latitude;
    final centerLng = _currentPosition!.longitude;
    final markersJson = jsonEncode(_restaurantMarkers);
    
    // JSON 문자열 이스케이프 처리
    final escapedJson = markersJson
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');

    try {
      // JavaScript 함수가 정의될 때까지 잠시 대기 (SDK 로딩 시간 포함)
      await Future.delayed(const Duration(milliseconds: 500));
      
      print('🗺️ Calling initializeMap JS function...');
      final result = await _webViewController!.evaluateJavascript(
        source: '''
          (function() {
            try {
              if (typeof initializeMap === 'function') {
                initializeMap($centerLat, $centerLng, '$escapedJson', true);
                return 'success';
              } else {
                return 'error: initializeMap not defined';
              }
            } catch (e) {
              return 'error: ' + e.message;
            }
          })();
        ''',
      );
      print('✅ Map initialized: $result');
      
      setState(() {
        _isMapReady = true;
        _pendingMapInit = false;
      });
      
      // 지도가 초기화된 후 내 위치 중심으로 이동 (마커가 없는 경우에만)
      if (_currentPosition != null && _restaurantMarkers.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _webViewController!.evaluateJavascript(
          source: 'moveCamera($_currentPosition!.latitude, $_currentPosition!.longitude);',
        );
      }
    } catch (e) {
      print('❌ Error initializing map: $e');
      // 재시도
      if (!_isMapReady && mounted) {
        print('🔄 Retrying map initialization in 1 second...');
        await Future.delayed(const Duration(seconds: 1));
        await _initializeMap();
      }
    }
  }

  void _onRadiusChanged(double? value) {
    if (value != null && value != _selectedRadius) {
      setState(() {
        _selectedRadius = value;
      });
      _searchNearbyRestaurants();
    }
  }

  void _selectMarker(String restaurantId) async {
    if (_webViewController == null || !_isMapReady) return;

    try {
      await _webViewController!.evaluateJavascript(
        source: 'selectMarker("$restaurantId");',
      );
    } catch (e) {
      print('❌ Error selecting marker: $e');
    }
  }
  
  void _scrollToRestaurant(int index) {
    // 하단 리스트에서 해당 음식점 카드로 스크롤
    if (_listScrollController.hasClients) {
      // 카드 높이 + 마진을 고려한 스크롤 위치 계산
      const cardHeight = 100.0; // 카드 높이
      const cardMargin = 12.0; // 카드 마진
      const headerHeight = 50.0; // 헤더 높이
      final scrollPosition = (cardHeight + cardMargin) * index + headerHeight;
      
      _listScrollController.animateTo(
        scrollPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildRadiusSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '검색 반경: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
          _buildRadioOption(1.0, '1km'),
          _buildRadioOption(5.0, '5km'),
          _buildRadioOption(10.0, '10km'),
        ],
      ),
    );
  }

  Widget _buildRadioOption(double value, String label) {
    final isSelected = _selectedRadius == value;
    return GestureDetector(
      onTap: () => _onRadiusChanged(value),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFD1D5DB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? Colors.white : const Color(0xFF374151),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    if (_mapHtmlContent == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isLoadingLocation) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('현재 위치를 가져오는 중...'),
          ],
        ),
      );
    }

    if (_locationError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 64, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 16),
              Text(
                _locationError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                },
                child: const Text('위치 설정 열기'),
              ),
            ],
          ),
        ),
      );
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

            // 마커 클릭 핸들러 등록
            controller.addJavaScriptHandler(
              handlerName: 'onMarkerClick',
              callback: (args) {
                if (args.length >= 3) {
                  final restaurantId = args[0] as String;
                  final restaurantName = args[1] as String;
                  final isDoubleClick = args[2] as bool? ?? false;
                  print('📍 Marker clicked: $restaurantName ($restaurantId), doubleClick: $isDoubleClick');

                  final restaurantIndex = _restaurants.indexWhere((r) => r.id == restaurantId);
                  if (restaurantIndex == -1) return null;
                  
                  final restaurant = _restaurants[restaurantIndex];

                  if (isDoubleClick) {
                    // 더블클릭: 상세 페이지로 이동
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RestaurantDetailScreen(restaurant: restaurant),
                      ),
                    );
                  } else {
                    // 첫 클릭: 지도 중심 이동, 하단 카드 선택 및 스크롤
                    setState(() {
                      _lastClickedRestaurantId = restaurant.id;
                    });
                    _selectMarker(restaurant.id);
                    _scrollToRestaurant(restaurantIndex);
                  }
                }
                return null;
              },
            );
          },
          onLoadStop: (controller, url) async {
            print('✅ WebView loaded, waiting for Kakao SDK...');
            setState(() {
              _isWebViewLoaded = true;
            });
            
            // 카카오 SDK 로딩을 위한 충분한 시간 대기
            // SDK 스크립트가 네트워크에서 로드되어야 하므로 더 긴 시간 필요
            await Future.delayed(const Duration(milliseconds: 1500));
            
            print('✅ Starting map initialization...');
            
            // 대기 중인 초기화가 있거나, 현재 위치가 있으면 초기화
            if (_pendingMapInit || _currentPosition != null) {
              await _initializeMap();
            }
          },
          onConsoleMessage: (controller, consoleMessage) {
            print('🌐 WebView Console: ${consoleMessage.message}');
          },
        ),
        // 로딩 인디케이터 (WebView 로드 전에만 표시)
        if (!_isWebViewLoaded)
          Container(
            color: Colors.white,
            child: const Center(child: CircularProgressIndicator()),
          ),
        // 현재 위치 버튼
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: _getCurrentLocation,
            child: const Icon(Icons.my_location, color: Color(0xFF3B82F6)),
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantCard(Restaurant restaurant, int index) {
    final isSelected = _lastClickedRestaurantId == restaurant.id;
    final distance = _restaurantDistances[restaurant.id];
    final distanceText = distance != null ? _formatDistance(distance) : '';
    
    return GestureDetector(
      onTap: () {
        if (_lastClickedRestaurantId == restaurant.id) {
          // 두 번째 클릭: 상세 페이지로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RestaurantDetailScreen(restaurant: restaurant),
            ),
          );
        } else {
          // 첫 번째 클릭: 지도에서 해당 위치로 이동, 하단 카드 선택 및 스크롤
          setState(() {
            _lastClickedRestaurantId = restaurant.id;
          });
          _selectMarker(restaurant.id);
          _scrollToRestaurant(index);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${restaurant.name} 위치로 이동했습니다. 다시 탭하면 상세 페이지로 이동합니다.'),
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
            // 이미지
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: restaurant.primaryPhotoUrl ?? '',
                    height: 100,
                    width: 100,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 100,
                      width: 100,
                      color: const Color(0xFFF3F4F6),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 100,
                      width: 100,
                      color: const Color(0xFFF3F4F6),
                      child: const Icon(Icons.restaurant, size: 40, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                  // 순위 배지
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
            // 정보
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 음식점 이름 + 거리
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            restaurant.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (distanceText.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            distanceText,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (restaurant.category != null)
                      Text(
                        restaurant.category!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.comment_outlined, size: 16, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text(
                          '${restaurant.reviewCount ?? 0}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 화살표 아이콘
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantList() {
    if (_isLoadingRestaurants) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_restaurants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(
              '${_selectedRadius.toInt()}km 내에 음식점이 없습니다.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '주변 맛집 (${_restaurants.length}개)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                '${_selectedRadius.toInt()}km 이내',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        // 세로 스크롤 리스트
        Expanded(
          child: ListView.builder(
            controller: _listScrollController,
            padding: const EdgeInsets.all(16),
            scrollDirection: Axis.vertical,
            itemCount: _restaurants.length,
            itemBuilder: (context, index) {
              return _buildRestaurantCard(_restaurants[index], index);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('내 주변 맛집'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _getCurrentLocation();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 거리 선택 라디오 버튼
          _buildRadiusSelector(),
          
          // 지도 영역 (확장)
          Expanded(
            child: _buildMap(),
          ),
          
          // 음식점 카드 리스트 (고정 높이 - 카드 1개 정도)
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: _buildRestaurantList(),
          ),
        ],
      ),
    );
  }
}
