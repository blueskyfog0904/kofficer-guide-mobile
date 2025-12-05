import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'supabase_service.dart';

class AuthService extends ChangeNotifier {
  final _supabase = SupabaseService().client;
  bool _isLoading = false;
  bool _isKakaoLoggedIn = false;
  User? _kakaoUser;
  String? _userId; // Supabase Auth의 user_id

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isKakaoLoggedIn;
  User? get kakaoUser => _kakaoUser;
  String? get userId => _userId;
  supabase.User? get currentUser => _supabase.auth.currentUser;

  AuthService() {
    // 앱 시작 시 로그인 상태 확인
    _checkLoginStatus();
  }

  /// 로그인 상태 확인 (Supabase 세션 + 카카오 토큰)
  Future<void> _checkLoginStatus() async {
    try {
      // 1. Supabase 세션 확인
      final session = _supabase.auth.currentSession;
      if (session != null) {
        _userId = _supabase.auth.currentUser?.id;
        _isKakaoLoggedIn = true;
        
        // 카카오 토큰도 확인
        if (await AuthApi.instance.hasToken()) {
          try {
            await UserApi.instance.accessTokenInfo();
            _kakaoUser = await UserApi.instance.me();
          } catch (e) {
            print('카카오 토큰 만료, Supabase 세션만 유효');
          }
        }
        
        print('✅ Supabase 세션 유효: $_userId');
        notifyListeners();
        return;
      }

      // 2. Supabase 세션이 없으면 카카오 토큰 확인
      if (await AuthApi.instance.hasToken()) {
        try {
          await UserApi.instance.accessTokenInfo();
          _kakaoUser = await UserApi.instance.me();
          
          // 카카오 토큰은 유효하지만 Supabase 세션이 없으면 Edge Function 호출
          final kakaoToken = await TokenManagerProvider.instance.manager.getToken();
          if (kakaoToken?.accessToken != null) {
            await _exchangeKakaoToken(kakaoToken!.accessToken);
          }
        } catch (e) {
          print('❌ 카카오 토큰 만료: $e');
          _isKakaoLoggedIn = false;
          _kakaoUser = null;
          _userId = null;
        }
      } else {
        _isKakaoLoggedIn = false;
        _kakaoUser = null;
        _userId = null;
      }
    } catch (e) {
      print('로그인 상태 확인 오류: $e');
      _isKakaoLoggedIn = false;
      _kakaoUser = null;
      _userId = null;
    }
    notifyListeners();
  }

  /// 카카오 토큰을 Supabase 세션으로 교환 (Edge Function 호출)
  Future<bool> _exchangeKakaoToken(String kakaoAccessToken) async {
    try {
      print('🔄 Edge Function 호출 중...');
      
      final response = await _supabase.functions.invoke(
        'kakao-login',
        body: {'access_token': kakaoAccessToken},
      );
      
      if (response.status != 200) {
        print('❌ Edge Function 오류: ${response.data}');
        return false;
      }
      
      final data = response.data as Map<String, dynamic>;
      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;
      
      if (accessToken == null || refreshToken == null) {
        print('❌ 세션 토큰 없음');
        return false;
      }
      
      // Supabase 세션 설정
      final authResponse = await _supabase.auth.setSession(refreshToken);
      
      if (authResponse.session != null) {
        _userId = authResponse.user?.id;
        _isKakaoLoggedIn = true;
        print('✅ Supabase 세션 설정 완료: $_userId');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ 카카오 토큰 교환 오류: $e');
      return false;
    }
  }

  Future<bool> loginWithKakao() async {
    _isLoading = true;
    notifyListeners();

    try {
      bool isInstalled = await isKakaoTalkInstalled();
      OAuthToken token;

      if (isInstalled) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          print('카카오톡으로 로그인 실패 $error');
          if (error is PlatformException && error.code == 'CANCELED') {
            _isLoading = false;
            notifyListeners();
            return false;
          }
          try {
            token = await UserApi.instance.loginWithKakaoAccount();
          } catch (error) {
             print('카카오계정으로 로그인 실패 $error');
             _isLoading = false;
             notifyListeners();
             return false;
          }
        }
      } else {
        try {
          token = await UserApi.instance.loginWithKakaoAccount();
        } catch (error) {
           print('카카오계정으로 로그인 실패 $error');
           _isLoading = false;
           notifyListeners();
           return false;
        }
      }

      print('✅ 카카오 로그인 성공: ${token.accessToken.substring(0, 20)}...');
      
      // 카카오 사용자 정보 가져오기
      _kakaoUser = await UserApi.instance.me();
      print('✅ 카카오 사용자: ${_kakaoUser?.kakaoAccount?.profile?.nickname}');
      
      // Edge Function 호출해서 Supabase 세션 생성
      final success = await _exchangeKakaoToken(token.accessToken);
      
      if (success) {
        _isKakaoLoggedIn = true;
        notifyListeners();
        return true;
      } else {
        // Edge Function 실패해도 카카오 로그인은 유지
        // (일부 기능은 제한될 수 있음)
        _isKakaoLoggedIn = true;
        notifyListeners();
        return true;
      }
    } catch (error) {
      print('로그인 프로세스 에러: $error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await UserApi.instance.logout();
      print('✅ 카카오 로그아웃 성공');
    } catch (e) {
      print('카카오 로그아웃 실패: $e');
    }
    
    _isKakaoLoggedIn = false;
    _kakaoUser = null;
    _userId = null;
    
    await _supabase.auth.signOut();
    notifyListeners();
  }

  /// 계정 삭제
  Future<bool> deleteAccount() async {
    try {
      // 카카오 연결 해제
      try {
        await UserApi.instance.unlink();
        print('카카오 연결 해제 성공');
      } catch (e) {
        print('카카오 연결 해제 실패: $e');
      }

      _isKakaoLoggedIn = false;
      _kakaoUser = null;
      _userId = null;

      await _supabase.auth.signOut();
      
      notifyListeners();
      return true;
    } catch (e) {
      print('계정 삭제 실패: $e');
      return false;
    }
  }
}
