import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

/// 프로필 변경 화면
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _usernameController = TextEditingController();
  final _userService = UserService();
  bool _isLoading = true;
  bool _isSaving = false;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final authService = context.read<AuthService>();
    final userId = authService.userId;
    
    if (userId != null) {
      final profile = await _userService.getProfile(userId);
      
      if (mounted) {
        setState(() {
          _profile = profile;
          // displayNickname 사용 (mob_nickname 우선, 없으면 nickname)
          _usernameController.text = profile?.displayNickname ?? '';
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEditNicknameDialog() async {
    final currentNickname = _usernameController.text;
    final controller = TextEditingController(text: currentNickname);
    
    final newNickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사용자명 변경'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '새 사용자명',
            hintText: '사용자명을 입력하세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (newNickname != null && newNickname.isNotEmpty && newNickname != currentNickname) {
      await _updateNickname(newNickname);
    }
  }

  Future<void> _updateNickname(String newNickname) async {
    final authService = context.read<AuthService>();
    final userId = authService.userId;
    if (userId == null) return;

    setState(() => _isSaving = true);

    // user_id를 사용하여 업데이트 (RLS 정책 통과)
    final success = await _userService.updateNickname(userId, newNickname);

    if (mounted) {
      setState(() => _isSaving = false);

      if (success) {
        setState(() {
          _usernameController.text = newNickname;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사용자명이 변경되었습니다.')),
        );
        _loadProfile(); // 프로필 새로고침
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사용자명 변경에 실패했습니다.')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('프로필 변경')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 변경'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 사용자명
          const Text(
            '사용자명',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _usernameController.text.isNotEmpty 
                        ? _usernameController.text 
                        : '사용자명을 입력하세요',
                    style: TextStyle(
                      fontSize: 16,
                      color: _usernameController.text.isNotEmpty 
                          ? Colors.black87 
                          : Colors.grey,
                    ),
                  ),
                ),
                if (_isSaving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton(
                    onPressed: _showEditNicknameDialog,
                    child: const Text('수정'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '다른 사용자에게 표시되는 이름입니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          
          const SizedBox(height: 24),
          
          // 이메일 (읽기 전용)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.email_outlined),
            title: const Text('이메일'),
            subtitle: Text(
              _profile?.email ?? '이메일 없음',
              style: const TextStyle(fontSize: 16),
            ),
            trailing: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
          ),
          
          // 가입일 (읽기 전용)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('가입일'),
            subtitle: Text(
              _profile != null 
                  ? _formatDate(_profile!.createdAt)
                  : '-',
              style: const TextStyle(fontSize: 16),
            ),
            trailing: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
          ),

          const SizedBox(height: 16),
          Text(
            '이메일과 가입일은 변경할 수 없습니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}



