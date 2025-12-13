import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'services/supabase_service.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';

// app_links 카카오 딥링크 핸들러 (Android에서 Supabase app_links 충돌 해결용)
late AppLinks _appLinks;
StreamSubscription<Uri>? _linkSubscription;

Future<void> _initAppLinks(String kakaoNativeKey) async {
  _appLinks = AppLinks();
  
  // 초기 딥링크 확인 (앱이 딥링크로 시작된 경우)
  try {
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) {
      _handleDeepLink(initialLink, kakaoNativeKey);
    }
  } catch (e) {
    print('초기 딥링크 확인 오류: $e');
  }
  
  // 딥링크 스트림 구독 (앱이 실행 중일 때 딥링크 도착)
  _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
    _handleDeepLink(uri, kakaoNativeKey);
  });
}

void _handleDeepLink(Uri uri, String kakaoNativeKey) {
  final scheme = uri.scheme;
  final kakaoScheme = 'kakao$kakaoNativeKey';
  
  // 카카오 딥링크인 경우 - code를 추출해서 AuthService에 전달
  if (scheme == kakaoScheme && uri.host == 'oauth') {
    final code = uri.queryParameters['code'];
    if (code != null) {
      // 전역 콜백을 통해 AuthService에 code 전달
      _kakaoAuthCodeCallback?.call(code);
    }
  }
}

// 카카오 인증 코드 콜백 (AuthService에서 설정)
void Function(String code)? _kakaoAuthCodeCallback;

void setKakaoAuthCodeCallback(void Function(String code)? callback) {
  _kakaoAuthCodeCallback = callback;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. 환경 변수 로드
  try {
    await dotenv.load(fileName: "assets/dotenv");
  } catch (e) {
    print('Error loading .env file: $e');
  }

  // 2. Kakao SDK 초기화 (Auth용) - Supabase보다 먼저 초기화해서 딥링크 우선 처리
  final kakaoNativeKey = dotenv.env['KAKAO_NATIVE_APP_KEY'];
  final kakaoJsKey = dotenv.env['KAKAO_JAVASCRIPT_KEY'];

  if (kakaoNativeKey != null && kakaoJsKey != null) {
    // Kakao Auth SDK 초기화
    KakaoSdk.init(
      nativeAppKey: kakaoNativeKey,
      javaScriptAppKey: kakaoJsKey,
    );
    
    // app_links 딥링크 핸들러 초기화 - 카카오 딥링크 감지용
    await _initAppLinks(kakaoNativeKey);
  } else {
    print('Warning: Kakao App Keys are missing');
  }

  // 3. Supabase 초기화 - 카카오 SDK 이후에 초기화
  await SupabaseService().initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kofficer Guide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          primary: const Color(0xFF3B82F6),
          secondary: const Color(0xFF10B981),
          surface: Colors.white,
          background: const Color(0xFFF3F4F6),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.black),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      ),
      home: const SplashScreen(),
    );
  }
}
