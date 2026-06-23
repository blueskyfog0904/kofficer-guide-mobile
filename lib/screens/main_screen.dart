import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'region_search_screen.dart';
import 'browser_screen.dart';
import 'profile_screen.dart';
import '../widgets/admob_banner.dart';

typedef BrowserBackHandler = Future<bool> Function();
typedef CurrentTimeProvider = DateTime Function();

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    this.browserBackHandlerOverride,
    this.currentTimeOverride,
    this.tabScreensOverride,
    this.showAdBanner = true,
  });

  // 테스트에서 WebView/platform 의존성을 우회하기 위한 선택적 seam입니다.
  final BrowserBackHandler? browserBackHandlerOverride;
  final CurrentTimeProvider? currentTimeOverride;
  final List<Widget>? tabScreensOverride;
  final bool showAdBanner;

  // 음식점 상세 등 탭 내부 화면에서 탭 전환을 요청하기 위한 앱 전역 키
  static final GlobalKey<MainScreenState> globalKey =
      GlobalKey<MainScreenState>();

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  static const int _homeTabIndex = 0;
  static const int _browserTabIndex = 3;
  static const int _tabCount = 5;
  static const Duration _exitConfirmDuration = Duration(seconds: 3);
  static const String _exitConfirmMessage = '한번 더 뒤로 가기 클릭시 앱이 종료됩니다.';

  int _selectedIndex = 0;
  int? _browserOriginTabIndex;
  DateTime? _lastExitBackPressedAt;
  final List<bool> _tabCanHandlePop = List<bool>.filled(_tabCount, false);
  bool _frameworkBackHandlingScheduled = false;

  // 브라우저 스크린의 상태에 접근하기 위한 키
  final GlobalKey<BrowserScreenState> _browserKey =
      GlobalKey<BrowserScreenState>();

  // 각 탭의 Navigator 키 (네비게이션 스택 유지용)
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  void _scheduleFrameworkBackHandling() {
    if (_frameworkBackHandlingScheduled) return;

    _frameworkBackHandlingScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameworkBackHandlingScheduled = false;
      Future<void>.microtask(() {
        if (!mounted) return;

        // MainScreen은 모든 탭 root에서도 자체 fallback을 처리합니다.
        // 일부 Android 기기에서는 IndexedStack 내부 Navigator의
        // canHandlePop=false 알림 이후 플랫폼이 앱 종료를 직접 수행할 수
        // 있어, MainScreen이 활성화된 동안 back 이벤트를 Flutter로
        // 전달하도록 보강합니다.
        SystemNavigator.setFrameworkHandlesBack(true);
      });
    });
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      // 같은 탭을 다시 누르면 해당 탭의 루트로 이동
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      _clearBrowserOrigin();
      _resetExitBackPress();
    } else {
      setState(() {
        _clearBrowserOrigin();
        _resetExitBackPress();
        _selectedIndex = index;
      });
    }
  }

  // 외부에서 탭을 전환하고, 필요하다면 브라우저 URL을 로드하는 메서드
  void navigateToTab(
    int index, {
    String? browserUrl,
    bool preserveOrigin = false,
  }) {
    final originTabIndex =
        preserveOrigin && index == _browserTabIndex && _selectedIndex != index
            ? _selectedIndex
            : null;
    final shouldResetBrowserHistory = _isValidTabIndex(originTabIndex) &&
        originTabIndex != _browserTabIndex &&
        browserUrl != null;

    _resetExitBackPress();

    setState(() {
      if (_isValidTabIndex(originTabIndex) &&
          originTabIndex != _browserTabIndex) {
        _browserOriginTabIndex = originTabIndex;
      } else if (index != _browserTabIndex || !preserveOrigin) {
        _clearBrowserOrigin();
      }

      _selectedIndex = index;
    });

    if (index == _browserTabIndex && browserUrl != null) {
      // 브라우저 탭으로 이동 시 URL 로드
      // 위젯이 빌드된 후 실행되도록 지연
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _browserKey.currentState?.loadUrl(
          browserUrl,
          resetHistory: shouldResetBrowserHistory,
        );
      });
    }
  }

  // 각 탭의 화면을 Navigator로 감싸서 독립적인 네비게이션 스택 유지
  Widget _buildNavigator(int index, Widget child) {
    return NotificationListener<NavigationNotification>(
      onNotification: (notification) {
        _updateTabCanHandlePop(index, notification.canHandlePop);
        // IndexedStack 안의 비활성 탭 Navigator 알림이 앱 최상단의
        // Android back 가능 여부를 덮어쓰지 않도록 여기서 흡수합니다.
        return true;
      },
      child: NavigatorPopHandler<Object?>(
        enabled: _selectedIndex == index,
        onPopWithResult: (_) {
          if (_selectedIndex != index || !_tabCanHandlePop[index]) return;

          _resetExitBackPress();
          _navigatorKeys[index].currentState?.maybePop();
        },
        child: Navigator(
          key: _navigatorKeys[index],
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              builder: (context) => child,
            );
          },
        ),
      ),
    );
  }

  bool get _activeTabCanHandlePop => _tabCanHandlePop[_selectedIndex];

  void _updateTabCanHandlePop(int index, bool canHandlePop) {
    if (_tabCanHandlePop[index] == canHandlePop || !mounted) return;

    setState(() {
      _tabCanHandlePop[index] = canHandlePop;
    });
  }

  bool _isValidTabIndex(int? index) {
    return index != null && index >= 0 && index < _tabCount;
  }

  void _clearBrowserOrigin() {
    _browserOriginTabIndex = null;
  }

  void _resetExitBackPress() {
    _lastExitBackPressedAt = null;
  }

  DateTime _now() {
    return widget.currentTimeOverride?.call() ?? DateTime.now();
  }

  Future<bool> _handleBrowserBack() async {
    if (_selectedIndex != _browserTabIndex) {
      return false;
    }

    final browserBackHandler = widget.browserBackHandlerOverride;
    final isWebViewBackHandled = browserBackHandler != null
        ? await browserBackHandler()
        : await (_browserKey.currentState?.handleBack() ?? Future.value(false));

    if (isWebViewBackHandled) {
      _resetExitBackPress();
      return true;
    }

    final originTabIndex = _browserOriginTabIndex;
    if (_isValidTabIndex(originTabIndex) &&
        originTabIndex != _browserTabIndex) {
      setState(() {
        _selectedIndex = originTabIndex!;
        _clearBrowserOrigin();
        _resetExitBackPress();
      });
      return true;
    }

    _clearBrowserOrigin();
    return false;
  }

  Future<void> _handleHomeRootBack(BuildContext context) async {
    final now = _now();
    final lastExitBackPressedAt = _lastExitBackPressedAt;

    if (lastExitBackPressedAt != null &&
        now.difference(lastExitBackPressedAt) <= _exitConfirmDuration) {
      _resetExitBackPress();
      await SystemNavigator.pop();
      return;
    }

    _lastExitBackPressedAt = now;
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(_exitConfirmMessage),
          duration: _exitConfirmDuration,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    _scheduleFrameworkBackHandling();

    assert(
      widget.tabScreensOverride == null ||
          widget.tabScreensOverride!.length == _tabCount,
      'tabScreensOverride must contain exactly $_tabCount widgets.',
    );

    final tabScreens = widget.tabScreensOverride ??
        [
          const HomeScreen(),
          const MapScreen(),
          const RegionSearchScreen(),
          BrowserScreen(key: _browserKey),
          const ProfileScreen(),
        ];

    return PopScope(
      canPop: _activeTabCanHandlePop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 탭 내부 Navigator가 처리할 수 있는 route pop은
        // NavigatorPopHandler가 담당합니다. 루트 PopScope는 탭 root의
        // fallback(브라우저 back/origin → 홈 이동 → 종료 확인)만 처리합니다.
        if (_activeTabCanHandlePop) {
          return;
        }

        if (await _handleBrowserBack()) {
          return;
        }

        if (!mounted) return;

        // 루트 화면에서 뒤로가기 시 홈으로 이동하거나 종료 확인
        if (_selectedIndex != _homeTabIndex) {
          setState(() {
            _resetExitBackPress();
            _selectedIndex = _homeTabIndex;
          });
          return;
        }

        await _handleHomeRootBack(context);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildNavigator(0, tabScreens[0]),
            _buildNavigator(1, tabScreens[1]),
            _buildNavigator(2, tabScreens[2]),
            _buildNavigator(3, tabScreens[3]),
            _buildNavigator(4, tabScreens[4]),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showAdBanner) const AdMobBanner(),
            BottomNavigationBar(
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
          ],
        ),
      ),
    );
  }
}
