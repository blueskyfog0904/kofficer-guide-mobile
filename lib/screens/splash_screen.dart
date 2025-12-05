import 'package:flutter/material.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // 로고 기반 네이비 컬러 (HomeScreen과 동일)
  static const Color navyColor = Color(0xFF1E3A5F);

  @override
  void initState() {
    super.initState();
    _navigateToMain();
  }

  Future<void> _navigateToMain() async {
    // 스플래시 화면 표시 시간 (2초)
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MainScreen(key: MainScreen.globalKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 로고 이미지
            Image.asset(
              'assets/images/project_logo.png',
              width: 300,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: navyColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    size: 80,
                    color: navyColor,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            // 앱 타이틀
            const Text(
              '공무원맛집 가이드',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: navyColor,
                fontFamily: 'Pretendard',
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            // 부가 설명 - 남색 배경, 흰색 글자
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              color: navyColor,
              child: const Text(
                '업무추진비를 분석해 만든\n공무원의 찐맛집 어플',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  fontFamily: 'Pretendard',
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

