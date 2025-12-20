import 'package:shared_preferences/shared_preferences.dart';

/// 지도 높이 설정을 저장/로드하는 서비스
/// 각 화면별로 스냅 포지션 인덱스를 SharedPreferences에 저장합니다.
class MapHeightService {
  static const String _mapScreenSnapIndexKey = 'map_screen_snap_index';
  static const String _regionSearchSnapIndexKey = 'region_search_snap_index';
  
  /// 기본 스냅 인덱스 (중간 크기)
  static const int defaultSnapIndex = 1;
  
  /// MapScreen (내 주변 탭)의 스냅 인덱스 저장
  static Future<void> saveMapScreenSnapIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_mapScreenSnapIndexKey, index);
  }
  
  /// MapScreen (내 주변 탭)의 스냅 인덱스 로드
  static Future<int> loadMapScreenSnapIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_mapScreenSnapIndexKey) ?? defaultSnapIndex;
  }
  
  /// RegionSearchScreen (지역 검색 탭)의 스냅 인덱스 저장
  static Future<void> saveRegionSearchSnapIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_regionSearchSnapIndexKey, index);
  }
  
  /// RegionSearchScreen (지역 검색 탭)의 스냅 인덱스 로드
  static Future<int> loadRegionSearchSnapIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_regionSearchSnapIndexKey) ?? defaultSnapIndex;
  }
}


