import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'notice_list_screen.dart';
import 'profile_edit_screen.dart';
import 'user_activity_screens.dart';
import 'my_reviews_screen.dart';
import 'terms_tabs_screen.dart';
import 'main_screen.dart';

/// 내 정보 관리 메인 화면 (메뉴 리스트)
class MyInfoScreen extends StatefulWidget {
  const MyInfoScreen({super.key});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen> {
  final _userService = UserService();
  UserProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final authService = context.read<AuthService>();
    final userId = authService.userId;
    
    if (userId != null) {
      final profile = await _userService.getProfile(userId);
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    
    if (confirm == true && context.mounted) {
      await context.read<AuthService>().signOut();
      // 홈 탭으로 이동
      MainScreen.globalKey.currentState?.navigateToTab(0);
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final authService = context.read<AuthService>();
    
    // 1차 확인
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 삭제'),
        content: const Text('정말로 계정을 삭제하시겠습니까?\n\n삭제된 계정은 복구할 수 없으며, 모든 데이터(즐겨찾기, 리뷰, 댓글 등)가 영구적으로 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('계속', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;

    // 2차 확인
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('최종 확인'),
        content: const Text('이 작업은 되돌릴 수 없습니다.\n정말로 계정을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (secondConfirm != true || !context.mounted) return;

    // 계정 삭제 실행
    final success = await authService.deleteAccount();
    
    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('계정이 삭제되었습니다.')),
        );
        // 홈 탭으로 이동
        MainScreen.globalKey.currentState?.navigateToTab(0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('계정 삭제에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final kakaoUser = authService.kakaoUser;
    
    // profile 테이블의 displayNickname 사용 (mob_nickname 우선, 없으면 nickname)
    // 둘 다 없으면 카카오 닉네임 사용
    final nickname = _profile?.displayNickname ?? 
                     kakaoUser?.kakaoAccount?.profile?.nickname ?? 
                     '사용자';
    
    // profile 테이블의 email을 우선 사용, 없으면 카카오 이메일 사용
    final email = _profile?.email ?? 
                  kakaoUser?.kakaoAccount?.email ?? 
                  '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 정보'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          children: [
            // 프로필 헤더
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: kakaoUser?.kakaoAccount?.profile?.profileImageUrl != null
                        ? NetworkImage(kakaoUser!.kakaoAccount!.profile!.profileImageUrl!)
                        : null,
                    child: kakaoUser?.kakaoAccount?.profile?.profileImageUrl == null
                        ? const Icon(Icons.person, size: 30, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _isLoading
                            ? const SizedBox(
                                width: 100,
                                height: 20,
                                child: LinearProgressIndicator(),
                              )
                            : Text(
                                nickname,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 메뉴 리스트
            _buildMenuItem(
              context,
              icon: Icons.campaign_outlined,
              title: '공지사항',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NoticeListScreen()),
              ),
            ),
            
            _buildMenuItem(
              context,
              icon: Icons.person_outline,
              title: '프로필 변경',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileEditScreen()),
                );
                // 프로필 변경 후 돌아오면 새로고침
                _loadProfile();
              },
            ),
            
            _buildMenuItem(
              context,
              icon: Icons.favorite_border,
              title: '즐겨찾기 목록',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FavoritesScreen()),
              ),
            ),
            
            _buildMenuItem(
              context,
              icon: Icons.rate_review_outlined,
              title: '작성한 리뷰',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyReviewsScreen()),
              ),
            ),
            
            _buildMenuItem(
              context,
              icon: Icons.description_outlined,
              title: '약관',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TermsTabsScreen()),
              ),
            ),

            const Divider(height: 32),

            // 계정 관리 섹션
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '계정 관리',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            
            _buildMenuItem(
              context,
              icon: Icons.logout,
              title: '로그아웃',
              iconColor: Colors.orange,
              onTap: () => _handleLogout(context),
            ),
            
            _buildMenuItem(
              context,
              icon: Icons.delete_forever,
              title: '계정 삭제',
              iconColor: Colors.red,
              textColor: Colors.red,
              subtitle: '모든 데이터가 삭제됩니다',
              onTap: () => _handleDeleteAccount(context),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
    String? subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.grey.shade700),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12))
          : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}
