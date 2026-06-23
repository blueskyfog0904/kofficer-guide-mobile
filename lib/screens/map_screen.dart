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
import '../services/map_height_service.dart';
import '../utils/inline_ad_list_placement.dart';
import '../widgets/inline_admob_banner.dart';
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
  bool _isWebViewLoaded = false;
  String? _mapHtmlContent;
  
  // 마커 데이터
  List<Map<String, dynamic>> _restaurantMarkers = [];
  
  // 지도 초기화 대기 플래그
  bool _pendingMapInit = false;
  
  // 마지막으로 클릭한 음식점 ID
  String? _lastClickedRestaurantId;
  
  // 음식점별 거리 정보
  Map<String, double> _restaurantDistances = {};
  
  // 음식점 첫 번째 사진 캐시 (primary_photo_url이 없는 음식점용)
  final Map<String, String> _restaurantPhotos = {};
  
  // 하단 리스트 스크롤 컨트롤러
  final ScrollController _listScrollController = ScrollController();
  
  // 리스트 영역 높이 옵션 (0: 작게, 1: 중간, 2: 크게, 3: 전체)
  int _listSizeIndex = 1;
  
  // 리스트 영역 높이 비율
  final List<double> _listHeightFactors = [0.25, 0.4, 0.6, 1.0];
  
  // 음식점 카드의 GlobalKey 맵 (정확한 스크롤 위치 계산용)
  final Map<String, GlobalKey> _restaurantCardKeys = {};
  
  GlobalKey _getCardKey(String restaurantId) {
    return _restaurantCardKeys.putIfAbsent(restaurantId, () => GlobalKey());
  }

  @override
  void initState() {
    super.initState();
    _loadMapHtml();
    _getCurrentLocation();
    _loadSavedListSize();
  }
  
  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedListSize() async {
    final savedIndex = await MapHeightService.loadMapScreenSnapIndex();
    setState(() {
      _listSizeIndex = savedIndex.clamp(0, 3);
    });
  }

  void _onListSizeChanged(int index) {
    if (_listSizeIndex != index) {
      setState(() {
        _listSizeIndex = index;
      });
      MapHeightService.saveMapScreenSnapIndex(index);
      
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

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = '위치 서비스가 비활성화되어 있습니다.\n기기 설정에서 위치 서비스를 켜주세요.';
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = '위치 권한이 거부되었습니다.';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = '위치 권한이 영구적으로 거부되었습니다.';
          _isLoadingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final bool isInKorea = _isLocationInKorea(position.latitude, position.longitude);
      
      if (isInKorea) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
      } else {
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
      }

      _searchNearbyRestaurants();
    } catch (e) {
      setState(() {
        _locationError = '위치를 가져오는 중 오류가 발생했습니다.';
        _isLoadingLocation = false;
      });
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;
  
  bool _isLocationInKorea(double latitude, double longitude) {
    return latitude >= 33.0 && latitude <= 43.0 && 
           longitude >= 124.0 && longitude <= 132.0;
  }
  
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
      _lastClickedRestaurantId = null;
    });

    try {
      final restaurants = await _restaurantService.getNearbyRestaurants(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radiusKm: _selectedRadius,
        limit: 2000,
      );

      final markers = <Map<String, dynamic>>[];
      final distances = <String, double>{};
      
      for (int i = 0; i < restaurants.length; i++) {
        final r = restaurants[i];
        if (r.latitude != null && r.longitude != null) {
          final distance = _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            r.latitude!,
            r.longitude!,
          );
          distances[r.id] = distance;
          
          markers.add({
            'id': r.id,
            'name': r.title ?? r.name,
            'lat': r.latitude,
            'lng': r.longitude,
            'rank': i + 1,
            'distance': _formatDistance(distance),
          });
        }
      }

      setState(() {
        _restaurants = restaurants;
        _restaurantMarkers = markers;
        _restaurantDistances = distances;
        _isLoadingRestaurants = false;
      });

      // primary_photo_url이 없는 음식점들의 첫 번째 사진 일괄 조회
      _fetchMissingPhotos(restaurants);

      if (_webViewController != null && _isWebViewLoaded) {
        await _initializeMap();
      } else {
        _pendingMapInit = true;
      }
    } catch (e) {
      setState(() {
        _isLoadingRestaurants = false;
      });
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
      final photos = await _restaurantService.getFirstPhotosForRestaurants(idsWithoutPhoto);
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
    if (_webViewController == null || _currentPosition == null || !_isWebViewLoaded) {
      return;
    }

    final centerLat = _currentPosition!.latitude;
    final centerLng = _currentPosition!.longitude;
    final markersJson = jsonEncode(_restaurantMarkers);
    
    final escapedJson = markersJson
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      
      await _webViewController!.evaluateJavascript(
        source: '''
          (function() {
            try {
              if (typeof initializeMap === 'function') {
                initializeMap($centerLat, $centerLng, '$escapedJson', true);
                return 'success';
              }
            } catch (e) {}
          })();
        ''',
      );
      
      setState(() {
        _isMapReady = true;
        _pendingMapInit = false;
      });
    } catch (e) {
      if (!_isMapReady && mounted) {
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

  void _selectMarkerAndMoveCamera(String restaurantId) async {
    if (_webViewController == null || !_isMapReady) return;

    try {
      // 마커 선택 및 지도 중심 이동 (relayout 포함)
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
    if (index < 0 || index >= _restaurants.length) return;
    
    final restaurant = _restaurants[index];
    final key = _restaurantCardKeys[restaurant.id];
    
    if (key?.currentContext != null) {
      // GlobalKey context가 있으면 바로 ensureVisible 사용
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    } else {
      // GlobalKey context가 없으면 (카드가 화면에 없음)
      // 1단계: 대략적인 위치로 먼저 스크롤하여 카드를 화면에 가져옴
      if (_listScrollController.hasClients) {
        const cardTotalHeight = 112.0;
        final renderedIndex =
            InlineAdListPlacement.renderedIndexForContentIndex(index);
        final scrollPosition = cardTotalHeight * renderedIndex;
        
        // jumpTo로 빠르게 대략적 위치로 이동 (카드가 빌드되도록)
        _listScrollController.jumpTo(
          scrollPosition.clamp(0.0, _listScrollController.position.maxScrollExtent),
        );
        
        // 2단계: 프레임 빌드 후 ensureVisible로 정확한 위치 조정
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final newKey = _restaurantCardKeys[restaurant.id];
          if (newKey?.currentContext != null) {
            Scrollable.ensureVisible(
              newKey!.currentContext!,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: 0.0,
            );
          }
        });
      }
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Text(
              '내 주변 맛집',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(width: 12),
            // 라디오 버튼들
            _buildRadiusChip(1.0, '1km'),
            const SizedBox(width: 6),
            _buildRadiusChip(5.0, '5km'),
            const SizedBox(width: 6),
            _buildRadiusChip(10.0, '10km'),
            const Spacer(),
            // 새로고침 버튼
            IconButton(
              icon: const Icon(Icons.refresh, size: 22),
              onPressed: _getCurrentLocation,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  // SafeArea 없는 헤더 (build에서 SafeArea를 외부에서 처리할 때 사용)
  Widget _buildHeaderContent() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            '내 주변 맛집',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 12),
          // 라디오 버튼들
          _buildRadiusChip(1.0, '1km'),
          const SizedBox(width: 6),
          _buildRadiusChip(5.0, '5km'),
          const SizedBox(width: 6),
          _buildRadiusChip(10.0, '10km'),
          const Spacer(),
          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: _getCurrentLocation,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusChip(double value, String label) {
    final isSelected = _selectedRadius == value;
    return GestureDetector(
      onTap: () => _onRadiusChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : const Color(0xFF374151),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    if (_mapHtmlContent == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isLoadingLocation) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('현재 위치를 가져오는 중...'),
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
              Text(_locationError!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
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

            controller.addJavaScriptHandler(
              handlerName: 'onMarkerClick',
              callback: (args) async {
                if (args.length >= 3) {
                  final restaurantId = args[0] as String;
                  final isDoubleClick = args[2] as bool? ?? false;

                  final restaurantIndex = _restaurants.indexWhere((r) => r.id == restaurantId);
                  if (restaurantIndex == -1) return null;
                  
                  final restaurant = _restaurants[restaurantIndex];

                  if (isDoubleClick) {
                    final updatedRestaurant = await Navigator.push<Restaurant>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RestaurantDetailScreen(restaurant: restaurant),
                      ),
                    );
                    
                    // 음식점 정보가 업데이트되었으면 리스트에서도 업데이트
                    if (updatedRestaurant != null && mounted) {
                      final index = _restaurants.indexWhere((r) => r.id == updatedRestaurant.id);
                      if (index != -1) {
                        setState(() {
                          // 기존 객체에서 regionRank 유지
                          _restaurants[index] = updatedRestaurant.copyWith(
                            regionRank: _restaurants[index].regionRank,
                          );
                          
                          // 사진 캐시도 업데이트 (중요: 삭제된 경우 반영)
                          if (updatedRestaurant.primaryPhotoUrl != null && updatedRestaurant.primaryPhotoUrl!.isNotEmpty) {
                            _restaurantPhotos[updatedRestaurant.id] = updatedRestaurant.primaryPhotoUrl!;
                          } else {
                            // 사진이 없거나 삭제된 경우 캐시에서 제거
                            _restaurantPhotos.remove(updatedRestaurant.id);
                          }
                        });
                      }
                    }
                  } else {
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
            setState(() {
              _isWebViewLoaded = true;
            });
            
            await Future.delayed(const Duration(milliseconds: 1500));
            
            if (_pendingMapInit || _currentPosition != null) {
              await _initializeMap();
            }
          },
        ),
        if (!_isWebViewLoaded)
          Container(
            color: Colors.white,
            child: const Center(child: CircularProgressIndicator()),
          ),
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

  Widget _buildRestaurantCard(Restaurant restaurant, int index) {
    final isSelected = _lastClickedRestaurantId == restaurant.id;
    final distance = _restaurantDistances[restaurant.id];
    final distanceText = distance != null ? _formatDistance(distance) : '';
    
    return GestureDetector(
      key: _getCardKey(restaurant.id),
      onTap: () async {
        if (_lastClickedRestaurantId == restaurant.id) {
          final updatedRestaurant = await Navigator.push<Restaurant>(
            context,
            MaterialPageRoute(
              builder: (context) => RestaurantDetailScreen(restaurant: restaurant),
            ),
          );
          
          // 음식점 정보가 업데이트되었으면 리스트에서도 업데이트
          if (updatedRestaurant != null && mounted) {
            final index = _restaurants.indexWhere((r) => r.id == updatedRestaurant.id);
            if (index != -1) {
              setState(() {
                // 기존 객체에서 regionRank 유지
                _restaurants[index] = updatedRestaurant.copyWith(
                  regionRank: _restaurants[index].regionRank,
                );
                
                // 사진 캐시도 업데이트 (중요: 삭제된 경우 반영)
                if (updatedRestaurant.primaryPhotoUrl != null && updatedRestaurant.primaryPhotoUrl!.isNotEmpty) {
                  _restaurantPhotos[updatedRestaurant.id] = updatedRestaurant.primaryPhotoUrl!;
                } else {
                  // 사진이 없거나 삭제된 경우 캐시에서 제거
                  _restaurantPhotos.remove(updatedRestaurant.id);
                }
              });
            }
          }
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

  Widget _buildRestaurantListItem(int renderedIndex) {
    if (InlineAdListPlacement.isAdIndex(renderedIndex)) {
      return InlineAdMobBanner(
        key: ValueKey('nearby-inline-ad-$renderedIndex'),
      );
    }

    final restaurantIndex =
        InlineAdListPlacement.contentIndexForRenderedIndex(renderedIndex);
    return _buildRestaurantCard(_restaurants[restaurantIndex], restaurantIndex);
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
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '주변 맛집 (${_restaurants.length}개)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                // 크기 조절 라디오 버튼
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
            child: _isLoadingRestaurants
                ? const Center(child: CircularProgressIndicator())
                : _restaurants.isEmpty
                    ? Center(
                        child: Text('${_selectedRadius.toInt()}km 내에 음식점이 없습니다.'),
                      )
                    : GestureDetector(
                        // 수직 드래그를 이 영역에서 가로채서 지도로 전파되지 않도록 함
                        onVerticalDragStart: (_) {},
                        onVerticalDragUpdate: (_) {},
                        onVerticalDragEnd: (_) {},
                        child: ListView.builder(
                          controller: _listScrollController,
                          padding: const EdgeInsets.all(16),
                          physics: const ClampingScrollPhysics(),
                          itemCount: InlineAdListPlacement.totalItemCount(
                            _restaurants.length,
                          ),
                          itemBuilder: (context, index) {
                            return _buildRestaurantListItem(index);
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
    const headerContentHeight = 56.0;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight - headerContentHeight;
            final listHeight = availableHeight * _listHeightFactors[_listSizeIndex];
            final mapHeight = availableHeight - listHeight;
            
            return Column(
              children: [
                _buildHeaderContent(),
                SizedBox(
                  height: mapHeight,
                  child: _buildMap(),
                ),
                _buildRestaurantList(listHeight),
              ],
            );
          },
        ),
      ),
    );
  }
}
