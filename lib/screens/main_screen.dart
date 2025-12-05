import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'region_search_screen.dart';
import 'browser_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  // 외부에서 접근 가능한 상태 키
  static final GlobalKey<_MainScreenState> globalKey = GlobalKey<_MainScreenState>();

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 브라우저 스크린의 상태에 접근하기 위한 키
  final GlobalKey<BrowserScreenState> _browserKey = GlobalKey<BrowserScreenState>();

  // 각 탭의 Navigator 키 (네비게이션 스택 유지용)
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      // 같은 탭을 다시 누르면 해당 탭의 루트로 이동
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  // 외부에서 탭을 전환하고, 필요하다면 브라우저 URL을 로드하는 메서드
  void navigateToTab(int index, {String? browserUrl}) {
    setState(() {
      _selectedIndex = index;
    });
    
    if (index == 3 && browserUrl != null) {
      // 브라우저 탭으로 이동 시 URL 로드
      // 위젯이 빌드된 후 실행되도록 지연
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _browserKey.currentState?.loadUrl(browserUrl);
      });
    }
  }

  // 각 탭의 화면을 Navigator로 감싸서 독립적인 네비게이션 스택 유지
  Widget _buildNavigator(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => child,
        );
      },
    );
  }

  // 뒤로가기 버튼 처리
  Future<bool> _onWillPop() async {
    final navigator = _navigatorKeys[_selectedIndex].currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final navigator = _navigatorKeys[_selectedIndex].currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        } else {
          // 루트 화면에서 뒤로가기 시 앱 종료 확인 또는 홈으로 이동
          if (_selectedIndex != 0) {
            setState(() {
              _selectedIndex = 0;
            });
          }
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildNavigator(0, const HomeScreen()),
            _buildNavigator(1, const MapScreen()),
            _buildNavigator(2, const RegionSearchScreen()),
            _buildNavigator(3, BrowserScreen(key: _browserKey)),
            _buildNavigator(4, const ProfileScreen()),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.near_me),
              label: '내 주변',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: '지역 검색',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.language),
              label: '네이버',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: '내 정보',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF3B82F6),
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
