# Flutter 카카오맵 클러스터링 기능 구현 프롬프트

## 목표
공무원맛집 가이드 Flutter 앱에서 웹과 동일한 카카오맵 클러스터링 기능을 구현합니다.

---

## 데이터 구조

### MapMarker 모델
```dart
class MapMarker {
  final String id;
  final String? name;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? subAdd1;  // 시/도
  final String? subAdd2;  // 구/군
  final int? ranking;
  final double? distance;
  
  MapMarker({
    required this.id,
    this.name,
    this.latitude,
    this.longitude,
    this.address,
    this.subAdd1,
    this.subAdd2,
    this.ranking,
    this.distance,
  });
}
```

### ClusterGroup 모델
```dart
class ClusterGroup {
  final List<MarkerPosition> markers;
  final LatLng center;
  
  ClusterGroup({
    required this.markers,
    required this.center,
  });
}

class MarkerPosition {
  final MapMarker marker;
  final LatLng coords;
  
  MarkerPosition({
    required this.marker,
    required this.coords,
  });
}
```

### UserLocation 모델
```dart
class UserLocation {
  final double latitude;
  final double longitude;
  final String? label;
  
  UserLocation({
    required this.latitude,
    required this.longitude,
    this.label,
  });
}
```

---

## 클러스터링 알고리즘

### 1. 줌 레벨에 따른 클러스터링 활성화 규칙
- **줌 레벨 1~3**: 클러스터링 비활성화, 모든 마커를 개별 표시
- **줌 레벨 4 이상**: 클러스터링 활성화

### 2. 클러스터링 거리 계산 공식
```dart
import 'dart:math';

double calculateClusterDistance(int currentZoomLevel) {
  // 기본 거리 (픽셀)
  const double baseDistance = 80.0;
  
  // 줌 레벨에 따른 배율 계산
  // 레벨 4에서 시작, 레벨이 높아질수록 클러스터 거리 증가
  double levelMultiplier = pow(1.5, currentZoomLevel - 4).toDouble();
  
  // 최종 클러스터링 거리
  return baseDistance * levelMultiplier;
}
```

### 3. 픽셀 거리 계산 함수
두 좌표 간의 화면상 픽셀 거리를 계산합니다:
```dart
import 'dart:math';

double getDistanceInPixels(
  LatLng pos1, 
  LatLng pos2, 
  KakaoMapController controller,
) {
  // 지도 projection을 사용하여 좌표를 화면 픽셀로 변환
  final point1 = controller.latLngToScreenPoint(pos1);
  final point2 = controller.latLngToScreenPoint(pos2);
  
  if (point1 == null || point2 == null) {
    return double.infinity;
  }
  
  final dx = point1.x - point2.x;
  final dy = point1.y - point2.y;
  
  return sqrt(dx * dx + dy * dy);
}
```

### 4. 클러스터 그룹 생성 알고리즘
```dart
List<ClusterGroup> createClusterGroups(
  List<MarkerPosition> positions,
  KakaoMapController controller,
  double clusterDistance,
) {
  final groups = <ClusterGroup>[];
  final assigned = <int>{};

  for (int i = 0; i < positions.length; i++) {
    // 이미 그룹에 할당된 마커는 건너뛰기
    if (assigned.contains(i)) continue;

    // 새 그룹 시작 - 현재 마커를 첫 번째 멤버로
    final groupMarkers = <MarkerPosition>[positions[i]];
    assigned.add(i);

    // 클러스터 거리 내의 다른 마커들 찾기
    for (int j = i + 1; j < positions.length; j++) {
      if (assigned.contains(j)) continue;

      final dist = getDistanceInPixels(
        positions[i].coords,
        positions[j].coords,
        controller,
      );

      if (dist < clusterDistance) {
        groupMarkers.add(positions[j]);
        assigned.add(j);
      }
    }

    // 그룹 중심점 계산
    LatLng center;
    if (groupMarkers.length > 1) {
      // 여러 마커가 있으면 평균 좌표 계산
      double sumLat = 0, sumLng = 0;
      for (final m in groupMarkers) {
        sumLat += m.coords.latitude;
        sumLng += m.coords.longitude;
      }
      center = LatLng(
        sumLat / groupMarkers.length,
        sumLng / groupMarkers.length,
      );
    } else {
      // 단일 마커면 해당 마커의 좌표 사용
      center = groupMarkers[0].coords;
    }

    groups.add(ClusterGroup(markers: groupMarkers, center: center));
  }

  return groups;
}
```

---

## 렌더링 로직

### 메인 렌더링 함수
```dart
void renderMarkersWithClustering(
  List<MarkerPosition> positions,
  int currentZoomLevel,
  String? focusMarkerId,
  KakaoMapController controller,
) {
  // 1. 기존 마커/오버레이 제거
  clearAllMarkers();

  // 2. 사용자 위치 마커 표시 (클러스터링과 무관)
  if (userLocation != null && showUserLocation) {
    renderUserLocationMarker(userLocation!);
  }

  // 3. 선택된 마커는 클러스터링에서 제외
  MarkerPosition? focusedPosition;
  List<MarkerPosition> otherPositions;
  
  if (focusMarkerId != null) {
    focusedPosition = positions.firstWhereOrNull(
      (p) => p.marker.id == focusMarkerId,
    );
    otherPositions = positions.where(
      (p) => p.marker.id != focusMarkerId,
    ).toList();
  } else {
    focusedPosition = null;
    otherPositions = positions;
  }

  // 4. 선택된 마커는 항상 개별 표시 (클러스터링 제외)
  if (focusedPosition != null) {
    renderSingleMarker(focusedPosition, isFocused: true);
  }

  // 5. 줌 레벨에 따른 렌더링 분기
  if (currentZoomLevel <= 3) {
    // 줌 레벨 1-3: 클러스터링 없이 개별 마커 표시
    for (final pos in otherPositions) {
      renderSingleMarker(pos, isFocused: false);
    }
    return;
  }

  // 6. 줌 레벨 4+: 클러스터링 적용
  final clusterDistance = calculateClusterDistance(currentZoomLevel);
  final groups = createClusterGroups(otherPositions, controller, clusterDistance);

  for (final group in groups) {
    if (group.markers.length == 1) {
      // 단일 마커 그룹 -> 개별 마커로 표시
      renderSingleMarker(group.markers[0], isFocused: false);
    } else {
      // 다중 마커 그룹 -> 클러스터로 표시
      renderCluster(group);
    }
  }
}
```

### 개별 마커 렌더링
```dart
void renderSingleMarker(MarkerPosition position, {required bool isFocused}) {
  // 마커 위젯 생성
  // - 위치: position.coords
  // - 포커스 상태에 따른 스타일 차별화
  // - zIndex: isFocused ? 1300 : 1200
  
  // 음식점 이름이 있으면 카드 오버레이도 표시
  if (position.marker.name != null) {
    renderRestaurantCard(position, isFocused: isFocused);
  }
  
  // 포커스된 마커면 해당 위치로 지도 이동
  if (isFocused && !ignoreFocusMarker) {
    controller.moveCamera(CameraUpdate.newLatLng(position.coords));
  }
}
```

### 클러스터 렌더링
```dart
void renderCluster(ClusterGroup group) {
  // 클러스터 마커 생성
  // - 위치: group.center
  // - 텍스트: "지역 맛집 ${group.markers.length}개"
  // - 스타일: 둥근 카드 형태
  // - zIndex: 1100
  // - 클릭 이벤트 연결
  
  final clusterMarker = ClusterMarkerWidget(
    position: group.center,
    count: group.markers.length,
    onTap: () => onClusterTap(group),
  );
  
  addMarkerToMap(clusterMarker);
}

void onClusterTap(ClusterGroup group) {
  // 클러스터 클릭 시: 줌 인 + 해당 위치로 이동
  final currentLevel = controller.zoomLevel.toInt();
  final newZoomLevel = max(1, currentLevel - 1);
  
  controller.setZoomLevel(newZoomLevel);
  controller.moveCamera(CameraUpdate.newLatLng(group.center));
}
```

---

## 마커 디자인

### 음식점 마커 SVG
```dart
// SVG Path 데이터 - CustomPainter 또는 flutter_svg로 구현
const String restaurantMarkerSvg = '''
<svg width="32" height="48" viewBox="0 0 32 42" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M16 0C7.16344 0 0 7.16344 0 16C0 28 16 42 16 42C16 42 32 28 32 16C32 7.16344 24.8366 0 16 0Z" fill="#FF6B35"/>
  <circle cx="16" cy="16" r="11" fill="white"/>
  <path d="M11.5 10V14C11.5 15.1 12.4 16 13.5 16V22H14.5V16C15.6 16 16.5 15.1 16.5 14V10H15.5V13H14.5V10H13.5V13H12.5V10H11.5ZM19.5 10C18.9 10 18.5 10.4 18.5 11V22H19.5V14C20.1 14 20.5 13.6 20.5 13V10H19.5Z" fill="#FF6B35"/>
</svg>
''';
```

### 색상 상수
```dart
class MarkerColors {
  // 음식점 마커 (식욕 자극 오렌지)
  static const Color restaurantPrimary = Color(0xFFFF6B35);
  static const Color restaurantBackground = Colors.white;
  
  // 사용자 위치 마커 (빨간색)
  static const Color userLocation = Color(0xFFDC2626);
  
  // 선택된 마커
  static const Color selectedBackground = Color(0xFFFF6B35);
  static const Color selectedText = Colors.white;
  
  // 클러스터
  static const Color clusterBackground = Colors.white;
  static const Color clusterText = Color(0xFF374151);
  static const Color clusterBorder = Color(0xFFE5E7EB);
}
```

### 사용자 위치 마커
```dart
Widget buildUserLocationMarker(UserLocation location) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // 레이블 (있는 경우)
      if (location.label != null)
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: MarkerColors.userLocation,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: MarkerColors.userLocation.withOpacity(0.3),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            location.label!,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      // 핀 아이콘
      Text('📍', style: TextStyle(fontSize: 24)),
    ],
  );
}
```

---

## 이벤트 처리

### 줌 변경 감지
```dart
class ClusteringMapState extends State<ClusteringMap> {
  int _currentZoomLevel = 3;
  
  @override
  void initState() {
    super.initState();
    _setupZoomListener();
  }
  
  void _setupZoomListener() {
    widget.controller.addCameraIdleListener(() {
      final newZoomLevel = widget.controller.zoomLevel.toInt();
      if (newZoomLevel != _currentZoomLevel) {
        setState(() {
          _currentZoomLevel = newZoomLevel;
        });
        // 줌 레벨 변경 시 클러스터링 재계산
        renderMarkersWithClustering(
          positions,
          _currentZoomLevel,
          focusMarkerId,
          widget.controller,
        );
      }
    });
  }
}
```

### 마커/클러스터 클릭 처리
```dart
void onMarkerTap(MarkerPosition position, bool isFocused) {
  if (isFocused && widget.onMarkerClick != null) {
    // 이미 선택된 마커 클릭 -> 상세 페이지 이동 등
    widget.onMarkerClick!(position.marker);
  } else if (widget.onCardClick != null) {
    // 다른 마커 클릭 -> 해당 마커 선택 + 줌 인
    widget.onCardClick!(position.marker);
    widget.controller.setZoomLevel(2);
    widget.controller.moveCamera(
      CameraUpdate.newLatLng(position.coords),
    );
  }
}
```

---

## 성능 최적화

### Debounce 적용
```dart
Timer? _debounceTimer;

void onZoomChanged(int newZoomLevel) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(Duration(milliseconds: 100), () {
    renderMarkersWithClustering(positions, newZoomLevel, focusMarkerId, controller);
  });
}

@override
void dispose() {
  _debounceTimer?.cancel();
  super.dispose();
}
```

### 마커 캐싱
```dart
// 마커 위젯 캐싱으로 재생성 최소화
final Map<String, Widget> _markerCache = {};

Widget getOrCreateMarker(MapMarker marker, bool isFocused) {
  final cacheKey = '${marker.id}_$isFocused';
  return _markerCache.putIfAbsent(
    cacheKey,
    () => buildMarkerWidget(marker, isFocused),
  );
}
```

---

## 구현 체크리스트

- [ ] MapMarker, ClusterGroup, MarkerPosition 모델 생성
- [ ] calculateClusterDistance() 함수 구현
- [ ] getDistanceInPixels() 함수 구현 (카카오맵 SDK 메서드 활용)
- [ ] createClusterGroups() 알고리즘 구현
- [ ] renderMarkersWithClustering() 메인 함수 구현
- [ ] 개별 마커 위젯 (SVG 또는 CustomPainter)
- [ ] 클러스터 위젯 (카운트 표시)
- [ ] 사용자 위치 마커 위젯
- [ ] 줌 변경 리스너 설정
- [ ] 마커/클러스터 클릭 이벤트 처리
- [ ] focusMarkerId 처리 (선택된 마커 항상 개별 표시)
- [ ] 성능 최적화 (debounce, 캐싱)

---

## 참고: 웹 구현 파일
이 프롬프트는 웹 버전의 다음 파일을 기반으로 작성되었습니다:
- `web/src/components/KakaoMap.tsx`

핵심 함수:
- `createClusterGroups()` - 클러스터 그룹 생성
- `renderMarkersWithClustering()` - 클러스터링 적용 렌더링
- `renderSingleMarker()` - 개별 마커 렌더링
- `renderCluster()` - 클러스터 렌더링
- `getDistanceInPixels()` - 픽셀 거리 계산

