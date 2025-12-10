import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'terms_page.dart';
import 'privacy_page.dart';

class SignupTermsScreen extends StatefulWidget {
  final VoidCallback onAgreeComplete;
  final VoidCallback? onCancel;

  const SignupTermsScreen({
    super.key,
    required this.onAgreeComplete,
    this.onCancel,
  });

  @override
  State<SignupTermsScreen> createState() => _SignupTermsScreenState();
}

class _SignupTermsScreenState extends State<SignupTermsScreen> 
    with SingleTickerProviderStateMixin {
  bool _agreeAll = false;
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _isLoading = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updateAgreeAll() {
    setState(() {
      _agreeAll = _agreeTerms && _agreePrivacy;
    });
  }

  void _toggleAll(bool value) {
    setState(() {
      _agreeAll = value;
      _agreeTerms = value;
      _agreePrivacy = value;
    });
  }

  Future<void> _handleAgree() async {
    setState(() => _isLoading = true);
    widget.onAgreeComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final canProceed = _agreeTerms && _agreePrivacy;
    
    return CupertinoPageScaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: widget.onCancel ?? () => Navigator.pop(context),
          child: Icon(
            CupertinoIcons.xmark,
            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
            size: 22,
          ),
        ),
        middle: Text(
          '회원가입',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  
                  // 헤더 텍스트
                  Text(
                    '서비스 이용을 위해\n약관에 동의해 주세요',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      height: 1.2,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Text(
                    '원활한 서비스 이용을 위해 약관 동의가 필요합니다',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.grey.shade400 : const Color(0xFF8E8E93),
                      height: 1.4,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // 전체 동의 카드
                  _buildAllAgreeCard(isDark),
                  
                  const SizedBox(height: 24),
                  
                  // 개별 약관 리스트
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildTermItem(
                          title: '서비스 이용약관',
                          isRequired: true,
                          isChecked: _agreeTerms,
                          onChanged: (value) {
                            setState(() => _agreeTerms = value);
                            _updateAgreeAll();
                          },
                          onViewPressed: () => _navigateToTerms(const TermsPage()),
                          isDark: isDark,
                          isFirst: true,
                        ),
                        _buildSeparator(isDark),
                        _buildTermItem(
                          title: '개인정보처리방침',
                          isRequired: true,
                          isChecked: _agreePrivacy,
                          onChanged: (value) {
                            setState(() => _agreePrivacy = value);
                            _updateAgreeAll();
                          },
                          onViewPressed: () => _navigateToTerms(const PrivacyPage()),
                          isDark: isDark,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // 가입 버튼
                  _buildAgreeButton(canProceed, isDark),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAllAgreeCard(bool isDark) {
    return GestureDetector(
      onTap: () => _toggleAll(!_agreeAll),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: _agreeAll
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                )
              : null,
          color: _agreeAll 
              ? null 
              : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: _agreeAll 
              ? null 
              : Border.all(
                  color: isDark ? Colors.grey.shade700 : const Color(0xFFE5E5EA),
                  width: 1,
                ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _agreeAll 
                    ? Colors.white 
                    : (isDark ? Colors.grey.shade700 : const Color(0xFFE5E5EA)),
              ),
              child: _agreeAll
                  ? const Icon(
                      CupertinoIcons.checkmark,
                      size: 16,
                      color: Color(0xFF007AFF),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '전체 동의하기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _agreeAll 
                          ? Colors.white 
                          : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '서비스 이용에 필요한 모든 약관에 동의합니다',
                    style: TextStyle(
                      fontSize: 13,
                      color: _agreeAll 
                          ? Colors.white.withOpacity(0.8)
                          : (isDark ? Colors.grey.shade400 : const Color(0xFF8E8E93)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermItem({
    required String title,
    required bool isRequired,
    required bool isChecked,
    required ValueChanged<bool> onChanged,
    required VoidCallback onViewPressed,
    required bool isDark,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 6 : 0,
        bottom: isLast ? 6 : 0,
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onPressed: () => onChanged(!isChecked),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isChecked 
                    ? const Color(0xFF007AFF)
                    : Colors.transparent,
                border: Border.all(
                  color: isChecked 
                      ? const Color(0xFF007AFF)
                      : (isDark ? Colors.grey.shade600 : const Color(0xFFD1D1D6)),
                  width: 2,
                ),
              ),
              child: isChecked
                  ? const Icon(
                      CupertinoIcons.checkmark,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: isRequired ? '[필수] ' : '[선택] ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isRequired 
                            ? const Color(0xFF007AFF)
                            : (isDark ? Colors.grey.shade400 : const Color(0xFF8E8E93)),
                      ),
                    ),
                    TextSpan(
                      text: title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: onViewPressed,
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: isDark ? Colors.grey.shade500 : const Color(0xFFC7C7CC),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeparator(bool isDark) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 54),
      color: isDark ? Colors.grey.shade800 : const Color(0xFFE5E5EA),
    );
  }

  Widget _buildAgreeButton(bool canProceed, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(14),
          color: canProceed 
              ? const Color(0xFF007AFF)
              : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
          onPressed: canProceed && !_isLoading ? _handleAgree : null,
          child: _isLoading
              ? const CupertinoActivityIndicator(color: Colors.white)
              : Text(
                  '동의하고 시작하기',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                    color: canProceed 
                        ? Colors.white
                        : (isDark ? Colors.grey.shade600 : const Color(0xFFC7C7CC)),
                  ),
                ),
        ),
      ),
    );
  }

  void _navigateToTerms(Widget page) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => page),
    );
  }
}
