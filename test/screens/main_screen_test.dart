import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kofficer_guide/screens/main_screen.dart';

const _exitConfirmMessage = '한번 더 뒤로 가기 클릭시 앱이 종료됩니다.';

const _testTabs = <Widget>[
  _TestTab(label: 'tab-0'),
  _TestTab(label: 'tab-1'),
  _TestTab(label: 'tab-2'),
  _TestTab(label: 'tab-3'),
  _TestTab(label: 'tab-4'),
];

const _pushableTestTabs = <Widget>[
  _PushableTestTab(label: 'tab-0', detailLabel: 'detail-tab-0'),
  _PushableTestTab(label: 'tab-1', detailLabel: 'detail-tab-1'),
  _PushableTestTab(label: 'tab-2', detailLabel: 'detail-tab-2'),
  _PushableTestTab(label: 'tab-3', detailLabel: 'detail-tab-3'),
  _PushableTestTab(label: 'tab-4', detailLabel: 'detail-tab-4'),
];

class _TestTab extends StatelessWidget {
  const _TestTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}

class _PushableTestTab extends StatelessWidget {
  const _PushableTestTab({required this.label, required this.detailLabel});

  final String label;
  final String detailLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            ElevatedButton(
              key: ValueKey('push-$label'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: Center(child: Text(detailLabel)),
                    ),
                  ),
                );
              },
              child: Text('open-$label'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _pumpMainScreen(
  WidgetTester tester, {
  BrowserBackHandler? browserBackHandler,
  CurrentTimeProvider? currentTimeProvider,
  List<Widget> tabScreens = _testTabs,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MainScreen(
        key: MainScreen.globalKey,
        browserBackHandlerOverride: browserBackHandler,
        currentTimeOverride: currentTimeProvider,
        tabScreensOverride: tabScreens,
        showAdBanner: false,
      ),
    ),
  );
}

List<MethodCall> _recordPlatformCalls() {
  final calls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    calls.add(call);
    return null;
  });
  return calls;
}

Iterable<MethodCall> _systemNavigatorPopCalls(List<MethodCall> calls) {
  return calls.where((call) => call.method == 'SystemNavigator.pop');
}

void _clearPlatformCallRecorder() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null);
}

int _selectedTabIndex(WidgetTester tester) {
  return tester
      .widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      )
      .currentIndex;
}

Future<void> _tapBottomNavigationLabel(
  WidgetTester tester,
  String label,
) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void _navigateToBrowserWithOrigin() {
  final mainState = MainScreen.globalKey.currentState;
  expect(mainState, isNotNull);
  mainState!.navigateToTab(
    3,
    browserUrl: 'https://example.com',
    preserveOrigin: true,
  );
}

void main() {
  tearDown(_clearPlatformCallRecorder);

  testWidgets('MainScreen has BottomNavigationBar with 5 items', (
    WidgetTester tester,
  ) async {
    await _pumpMainScreen(tester);

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.near_me), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.language), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  group('Android back navigation', () {
    testWidgets('keeps browser tab when WebView consumes back', (
      WidgetTester tester,
    ) async {
      var browserBackCalls = 0;

      await _pumpMainScreen(
        tester,
        browserBackHandler: () async {
          browserBackCalls += 1;
          return true;
        },
      );

      await _tapBottomNavigationLabel(tester, '네이버');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(browserBackCalls, 1);
      expect(_selectedTabIndex(tester), 3);
    });

    testWidgets('returns to origin tab when browser has no WebView history', (
      WidgetTester tester,
    ) async {
      var browserBackCalls = 0;

      await _pumpMainScreen(
        tester,
        browserBackHandler: () async {
          browserBackCalls += 1;
          return false;
        },
      );

      await _tapBottomNavigationLabel(tester, '지역 검색');
      _navigateToBrowserWithOrigin();
      await tester.pumpAndSettle();

      expect(_selectedTabIndex(tester), 3);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(browserBackCalls, 1);
      expect(_selectedTabIndex(tester), 2);

      await _tapBottomNavigationLabel(tester, '네이버');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(browserBackCalls, 2);
      expect(_selectedTabIndex(tester), 0);
    });

    testWidgets('falls back to home when browser has no origin', (
      WidgetTester tester,
    ) async {
      var browserBackCalls = 0;

      await _pumpMainScreen(
        tester,
        browserBackHandler: () async {
          browserBackCalls += 1;
          return false;
        },
      );

      await _tapBottomNavigationLabel(tester, '네이버');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(browserBackCalls, 1);
      expect(_selectedTabIndex(tester), 0);
    });

    testWidgets('keeps existing non-browser root fallback to home', (
      WidgetTester tester,
    ) async {
      var browserBackCalls = 0;
      final platformCalls = _recordPlatformCalls();

      await _pumpMainScreen(
        tester,
        browserBackHandler: () async {
          browserBackCalls += 1;
          return false;
        },
      );

      await _tapBottomNavigationLabel(tester, '내 주변');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(browserBackCalls, 0);
      expect(_selectedTabIndex(tester), 0);
      expect(find.text(_exitConfirmMessage), findsNothing);
      expect(_systemNavigatorPopCalls(platformCalls), isEmpty);
    });

    for (final tabCase in <({int index, String label})>[
      (index: 1, label: '내 주변'),
      (index: 2, label: '지역 검색'),
      (index: 3, label: '네이버'),
      (index: 4, label: '내 정보'),
    ]) {
      testWidgets(
        'returns ${tabCase.label} root to home without exiting',
        (WidgetTester tester) async {
          var browserBackCalls = 0;
          final platformCalls = _recordPlatformCalls();

          await _pumpMainScreen(
            tester,
            browserBackHandler: () async {
              browserBackCalls += 1;
              return false;
            },
          );

          await _tapBottomNavigationLabel(tester, tabCase.label);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();

          expect(_selectedTabIndex(tester), 0);
          expect(find.text(_exitConfirmMessage), findsNothing);
          expect(_systemNavigatorPopCalls(platformCalls), isEmpty);
          expect(browserBackCalls, tabCase.index == 3 ? 1 : 0);
        },
      );
    }

    testWidgets('pops selected tab route before falling back to home', (
      WidgetTester tester,
    ) async {
      final platformCalls = _recordPlatformCalls();

      await _pumpMainScreen(tester, tabScreens: _pushableTestTabs);

      await _tapBottomNavigationLabel(tester, '내 주변');
      await tester.tap(find.byKey(const ValueKey('push-tab-1')));
      await tester.pumpAndSettle();

      expect(_selectedTabIndex(tester), 1);
      expect(find.text('detail-tab-1'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(_selectedTabIndex(tester), 1);
      expect(find.text('detail-tab-1'), findsNothing);
      expect(find.text('tab-1'), findsOneWidget);
      expect(_systemNavigatorPopCalls(platformCalls), isEmpty);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(_selectedTabIndex(tester), 0);
      expect(find.text(_exitConfirmMessage), findsNothing);
      expect(_systemNavigatorPopCalls(platformCalls), isEmpty);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text(_exitConfirmMessage), findsOneWidget);
      expect(_systemNavigatorPopCalls(platformCalls), isEmpty);
    });

    testWidgets(
      'ignores inactive tab route when selected tab falls back home',
      (WidgetTester tester) async {
        final platformCalls = _recordPlatformCalls();

        await _pumpMainScreen(tester, tabScreens: _pushableTestTabs);

        await _tapBottomNavigationLabel(tester, '내 주변');
        await tester.tap(find.byKey(const ValueKey('push-tab-1')));
        await tester.pumpAndSettle();

        expect(_selectedTabIndex(tester), 1);
        expect(find.text('detail-tab-1'), findsOneWidget);

        await _tapBottomNavigationLabel(tester, '지역 검색');
        expect(_selectedTabIndex(tester), 2);
        expect(find.text('detail-tab-1'), findsNothing);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(_selectedTabIndex(tester), 0);
        expect(find.text(_exitConfirmMessage), findsNothing);
        expect(_systemNavigatorPopCalls(platformCalls), isEmpty);

        await _tapBottomNavigationLabel(tester, '내 주변');

        expect(_selectedTabIndex(tester), 1);
        expect(find.text('detail-tab-1'), findsOneWidget);
      },
    );
  });

  group('Home tab exit confirmation', () {
    testWidgets('shows confirmation instead of exiting on first home back', (
      WidgetTester tester,
    ) async {
      final platformCalls = _recordPlatformCalls();
      final now = DateTime(2026, 5, 24, 12);

      await _pumpMainScreen(tester, currentTimeProvider: () => now);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(_selectedTabIndex(tester), 0);
      expect(find.text(_exitConfirmMessage), findsOneWidget);
      expect(_systemNavigatorPopCalls(platformCalls), isEmpty);
    });

    testWidgets('exits on second home back within 3 seconds', (
      WidgetTester tester,
    ) async {
      final platformCalls = _recordPlatformCalls();
      var now = DateTime(2026, 5, 24, 12);

      await _pumpMainScreen(tester, currentTimeProvider: () => now);

      await tester.binding.handlePopRoute();
      await tester.pump();

      now = now.add(const Duration(seconds: 2));
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(_systemNavigatorPopCalls(platformCalls), hasLength(1));
    });

    testWidgets('asks again when second home back is after 3 seconds', (
      WidgetTester tester,
    ) async {
      final platformCalls = _recordPlatformCalls();
      var now = DateTime(2026, 5, 24, 12);

      await _pumpMainScreen(tester, currentTimeProvider: () => now);

      await tester.binding.handlePopRoute();
      await tester.pump();

      now = now.add(const Duration(seconds: 4));
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(_systemNavigatorPopCalls(platformCalls), isEmpty);
      expect(find.text(_exitConfirmMessage), findsAtLeastNWidgets(1));
    });
  });
}
