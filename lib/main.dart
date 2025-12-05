import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. 환경 변수 로드
  try {
    await dotenv.load(fileName: "assets/dotenv");
  } catch (e) {
    print('Error loading .env file: $e');
  }

  // 2. Supabase 초기화
  await SupabaseService().initialize();

  // 3. Kakao SDK 초기화 (Auth용)
  final kakaoNativeKey = dotenv.env['KAKAO_NATIVE_APP_KEY'];
  final kakaoJsKey = dotenv.env['KAKAO_JAVASCRIPT_KEY'];
  
  if (kakaoNativeKey != null && kakaoJsKey != null) {
    // Kakao Auth SDK 초기화
    KakaoSdk.init(
      nativeAppKey: kakaoNativeKey,
      javaScriptAppKey: kakaoJsKey,
    );
    print('✅ Kakao Auth SDK initialized');
    // 카카오맵은 WebView 기반으로 JavaScript API 사용
  } else {
    print('Warning: Kakao App Keys are missing');
  }

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
        // iOS 시스템 폰트(San Francisco) 사용 - Apple HIG 준수
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6), // Tailwind blue-500
          primary: const Color(0xFF3B82F6),
          secondary: const Color(0xFF10B981), // Tailwind emerald-500 (예시)
          surface: Colors.white,
          background: const Color(0xFFF3F4F6), // Tailwind gray-100
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F4F6), // Tailwind gray-100
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black, // Tailwind gray-900
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            // iOS 시스템 폰트 사용
          ),
          iconTheme: IconThemeData(color: Colors.black),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8), // Tailwind rounded-lg
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1, // Tailwind shadow-sm
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Tailwind rounded-xl
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)), // Tailwind gray-300
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
