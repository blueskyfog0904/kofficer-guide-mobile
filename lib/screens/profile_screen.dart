import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'my_info_screen.dart';
import 'signup_terms_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    
    if (authService.isLoggedIn) {
      return const MyInfoScreen();
    }
    
    return _LoginScreen(authService: authService);
  }
}

class _LoginScreen extends StatefulWidget {
  final AuthService authService;
  
  const _LoginScreen({required this.authService});

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleAppleLogin() async {
    final result = await widget.authService.loginWithApple();
    
    if (!mounted) return;

    switch (result) {
      case LoginResult.success:
        break;
      case LoginResult.needsSignup:
        _showSignupScreen();
        break;
      case LoginResult.cancelled:
        break;
      case LoginResult.failed:
        _showErrorDialog();
        break;
    }
  }

  void _showErrorDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('로그인 실패'),
        content: const Text('로그인 중 문제가 발생했습니다.\n잠시 후 다시 시도해 주세요.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('확인'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showSignupScreen() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => SignupTermsScreen(
          onAgreeComplete: () async {
            final userId = widget.authService.userId;
            if (userId != null) {
              final profileCreated = await _userService.createAppleProfile(userId);
              final termsConsented = await _userService.saveTermsConsent(userId);
              
              if (profileCreated && termsConsented) {
                widget.authService.completeAppleSignup();
                if (mounted) {
                  Navigator.of(context).pop();
                }
              } else {
                if (mounted) {
                  _showErrorDialog();
                }
              }
            }
          },
          onCancel: () async {
            await widget.authService.cancelAppleSignup();
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            slivers: [
              // 중앙정렬된 '내 정보' 헤더
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  alignment: Alignment.center,
                  child: Text(
                    '내 정보',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
              ),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      
                      // 프로필 아이콘
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.grey.shade300,
                              Colors.grey.shade400,
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.person_fill,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      
                      const SizedBox(height: 28),
                      
                      // 로그인 버튼들
                      _buildLoginButtons(isDark),
                      
                      const SizedBox(height: 12),
                      
                      // 안내 문구
                      Text(
                        '처음 이용 시 간단한 약관 동의 후 가입됩니다',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade500 : const Color(0xFF8E8E93),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // 타이틀
                      Text(
                        '로그인하고\n더 많은 기능을 사용하세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          height: 1.25,
                          color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Text(
                        '즐겨찾기, 리뷰 작성 등 모든 기능을 이용할 수 있습니다',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.grey.shade400 : const Color(0xFF8E8E93),
                          height: 1.4,
                        ),
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // 기능 소개 카드
                      _buildFeaturesCard(isDark),
                      
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildFeatureRow(
            icon: CupertinoIcons.heart_fill,
            iconColor: const Color(0xFFFF3B30),
            title: '즐겨찾기',
            subtitle: '마음에 드는 맛집을 저장하세요',
            isDark: isDark,
          ),
          _buildDivider(isDark),
          _buildFeatureRow(
            icon: CupertinoIcons.star_fill,
            iconColor: const Color(0xFFFF9500),
            title: '리뷰 작성',
            subtitle: '방문 경험을 공유하세요',
            isDark: isDark,
          ),
          _buildDivider(isDark),
          _buildFeatureRow(
            icon: CupertinoIcons.bell_fill,
            iconColor: const Color(0xFF007AFF),
            title: '알림',
            subtitle: '새로운 소식을 받아보세요',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 60),
      color: isDark ? Colors.grey.shade800 : const Color(0xFFE5E5EA),
    );
  }

  Widget _buildLoginButtons(bool isDark) {
    return Column(
      children: [
        // 카카오 로그인 버튼
        _buildKakaoSignInButton(isDark),
        
        // Apple 로그인 버튼 (iOS만)
        if (Platform.isIOS) ...[
          const SizedBox(height: 12),
          _buildAppleSignInButton(isDark),
        ],
      ],
    );
  }

  Widget _buildAppleSignInButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        color: isDark ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(14),
        onPressed: widget.authService.isLoading ? null : _handleAppleLogin,
        child: widget.authService.isLoading
            ? CupertinoActivityIndicator(
                color: isDark ? Colors.black : Colors.white,
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.apple,
                    size: 20,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Apple로 계속하기',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.black : Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildKakaoSignInButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        color: const Color(0xFFFEE500),
        borderRadius: BorderRadius.circular(14),
        onPressed: widget.authService.isLoading 
            ? null 
            : () => widget.authService.loginWithKakao(),
        child: widget.authService.isLoading
            ? const CupertinoActivityIndicator(color: Color(0xFF3C1E1E))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network(
                    'https://developers.kakao.com/assets/img/about/logos/kakaolink/kakaolink_btn_small.png',
                    width: 20,
                    height: 20,
                    errorBuilder: (context, error, stackTrace) => 
                        const Icon(CupertinoIcons.chat_bubble_fill, size: 20, color: Color(0xFF3C1E1E)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '카카오로 계속하기',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3C1E1E),
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
