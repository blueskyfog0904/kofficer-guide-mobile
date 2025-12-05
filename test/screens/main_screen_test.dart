import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kofficer_guide/screens/main_screen.dart';
import 'package:kofficer_guide/services/auth_service.dart';
import 'package:provider/provider.dart';

// AuthService Mock
class MockAuthService extends ChangeNotifier implements AuthService {
  @override
  bool get isLoading => false;
  
  @override
  get currentUser => null;
  
  @override
  Future<bool> loginWithKakao() async => true;
  
  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('MainScreen has BottomNavigationBar with 5 items', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthService>(
          create: (_) => MockAuthService(),
          child: const MainScreen(),
        ),
      ),
    );

    // 탭 바가 있는지 확인
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    // 탭 아이콘들이 있는지 확인
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.near_me), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.language), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}

