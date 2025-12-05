import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'my_info_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    
    // 카카오 로그인 상태 확인
    if (authService.isLoggedIn) {
      // 로그인됨: 내 정보 관리 화면 (메뉴 리스트)
      return const MyInfoScreen();
    }
    
    // 로그인하지 않은 상태: 카카오 로그인 UI 표시
    return _LoginScreen(authService: authService);
  }
}

/// 로그인 화면 (카카오로 시작하기)
class _LoginScreen extends StatelessWidget {
  final AuthService authService;
  
  const _LoginScreen({required this.authService});

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.blue.shade700)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, Color color, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 정보'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            // 로고
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_outline, size: 40, color: Colors.grey.shade400),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              '로그인이 필요합니다',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Text(
              '카카오 계정으로 간편하게 시작하세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 카카오 로그인 혜택 안내
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '회원 혜택',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoItem('즐겨찾기한 음식점을 저장하고 관리'),
                  _buildInfoItem('리뷰 작성 및 다른 사용자와 소통'),
                  _buildInfoItem('맞춤 추천 서비스 이용'),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 카카오로 시작하기 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: authService.isLoading 
                    ? null 
                    : () => authService.loginWithKakao(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE500),
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: authService.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.network(
                            'https://developers.kakao.com/assets/img/about/logos/kakaolink/kakaolink_btn_small.png',
                            width: 24,
                            height: 24,
                            errorBuilder: (context, error, stackTrace) => 
                                const Icon(Icons.chat_bubble, size: 24),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '카카오로 시작하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              '처음 이용 시 자동으로 회원가입됩니다',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            
            const SizedBox(height: 48),
            
            // 주요 기능 안내
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '주요 기능',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(
                    Icons.favorite,
                    Colors.red,
                    '즐겨찾기',
                    '자주 가는 음식점을 저장하세요',
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(
                    Icons.rate_review,
                    Colors.amber,
                    '리뷰 작성',
                    '방문 후기를 남기고 공유하세요',
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(
                    Icons.notifications,
                    Colors.blue,
                    '알림',
                    '새로운 소식을 받아보세요',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
