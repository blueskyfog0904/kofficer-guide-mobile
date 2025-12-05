import 'package:flutter/material.dart';
import 'main_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // 로고 기반 네이비 컬러
  static const Color navyColor = Color(0xFF1E3A5F);
  static const Color navyLight = Color(0xFF2D4A6F);
  static const Color goldAccent = Color(0xFFC9A962);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              // 로고 섹션
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildLogoSection(),
              ),
              const SizedBox(height: 48),
              // 스토리텔링 섹션 (전체 너비 사용)
              _buildStorySection(),
              const SizedBox(height: 40),
              // 데이터 신뢰성 섹션
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildTrustSection(),
              ),
              const SizedBox(height: 48),
              // CTA 버튼 섹션
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildActionSection(context),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  /// 로고 및 앱 타이틀
  Widget _buildLogoSection() {
    return Column(
      children: [
        // 로고 이미지
        Image.asset(
          'assets/images/project_logo.png',
          height: 300,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: navyColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant,
                size: 60,
                color: navyColor,
              ),
            );
          },
        ),
        const SizedBox(height: 2),
        // 앱 타이틀
        const Text(
          '공무원맛집 가이드',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: navyColor,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  /// 스토리텔링 섹션 - 왜 공무원 맛집인가?
  Widget _buildStorySection() {
    return Column(
      children: [
        // 질문형 카피
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            '그 동네를 가장 잘 아는 사람은\n누구일까요?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 핵심 메시지 - 전체 너비 사용
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: const BoxDecoration(
            color: navyColor,
          ),
          child: const Column(
            children: [
              Text(
                '바로, 공무원입니다',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '매일 그 지역에서 근무하며\n진짜 맛집을 찾아다닌 사람들',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white70, 
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 데이터 신뢰성 섹션
  Widget _buildTrustSection() {
    return Column(
      children: [
        // 섹션 타이틀
        const Text(
          '어떻게 찾았을까요?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: navyColor,
          ),
        ),
        const SizedBox(height: 20),
        // 신뢰성 카드들
        _buildTrustCard(
          icon: Icons.account_balance,
          title: '전국 시군구청',
          description: '각 지역 공무원들의 실제 방문 데이터인 \n 업무추진비 내역',
        ),
        const SizedBox(height: 12),
        _buildTrustCard(
          icon: Icons.analytics_outlined,
          title: '업무추진비 빅데이터',
          description: '공개된 업무추진비 내역을\n분석하여 순위 산정',
        ),
        const SizedBox(height: 12),
        _buildTrustCard(
          icon: Icons.verified_outlined,
          title: '검증된 찐맛집',
          description: '가장 많이 방문한 음식점을\n랭킹으로 제공',
        ),
      ],
    );
  }

  Widget _buildTrustCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: navyColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: navyColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: navyColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// CTA 버튼 섹션
  Widget _buildActionSection(BuildContext context) {
    return Column(
      children: [
        // 안내 문구
        Text(
          '전국 어디서든\n공무원들이 인정한 찐맛집을 만나보세요',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        // Primary CTA - 내 주변 찐맛집 찾기
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              // 내 주변 탭(인덱스 1)으로 이동
              MainScreen.globalKey.currentState?.navigateToTab(1);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: navyColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.my_location, size: 20),
                SizedBox(width: 8),
                Text(
                  '내 주변 찐맛집 찾기',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Secondary CTA - 지역별 찐맛집 검색
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () {
              // 지역 검색 탭(인덱스 2)으로 이동
              MainScreen.globalKey.currentState?.navigateToTab(2);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: navyColor,
              side: const BorderSide(color: navyColor, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, size: 20),
                SizedBox(width: 8),
                Text(
                  '지역별 찐맛집 검색',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
