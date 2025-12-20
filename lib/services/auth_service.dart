import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'supabase_service.dart';
import '../main.dart' show setKakaoAuthCodeCallback;

enum LoginResult {
  success,      // 기존 회원 로그인 성공
  needsSignup,  // 신규 회원, 약관 동의 필요
  failed,       // 로그인 실패
  cancelled,    // 사용자 취소
}

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

  // 카카오 인증 코드 수신 Completer (Android에서 딥링크 처리용)
  Completer<String>? _authCodeCompleter;

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
      _isKakaoLoggedIn = false;
      _kakaoUser = null;
      _userId = null;
    }
    notifyListeners();
  }

  /// Android에서 카카오계정 로그인 (딥링크 콜백 방식)
  /// app_links가 딥링크를 가로채서 SDK가 받지 못하는 문제 해결
  Future<OAuthToken> _loginWithKakaoAccountAndroid() async {
    // Completer 생성 - 딥링크에서 인증 코드를 받을 때까지 대기
    _authCodeCompleter = Completer<String>();
    
    // 콜백 등록 - main.dart의 딥링크 핸들러에서 호출됨
    setKakaoAuthCodeCallback((code) {
      if (_authCodeCompleter != null && !_authCodeCompleter!.isCompleted) {
        _authCodeCompleter!.complete(code);
      }
    });
    
    try {
      // 카카오 OAuth URL 생성
      final appKey = await KakaoSdk.appKey;
      final redirectUri = 'kakao$appKey://oauth';
      final state = DateTime.now().millisecondsSinceEpoch.toString();
      
      final authUrl = Uri.parse(
        'https://kauth.kakao.com/oauth/authorize'
        '?client_id=$appKey'
        '&redirect_uri=${Uri.encodeComponent(redirectUri)}'
        '&response_type=code'
        '&state=$state'
      );
      
      // 카카오 로그인 페이지 열기 (비동기로 실행 - await 하지 않음!)
      // launchBrowserTab은 브라우저가 닫힐 때까지 대기하므로, await하면 콜백을 받지 못함
      unawaited(launchBrowserTab(authUrl));
      
      // 딥링크에서 인증 코드를 받을 때까지 대기 (최대 5분)
      final code = await _authCodeCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw Exception('로그인 시간 초과'),
      );
      
      // 인증 코드를 토큰으로 교환
      final token = await AuthApi.instance.issueAccessToken(authCode: code);
      
      // 토큰을 SDK 내부 저장소에 명시적으로 저장
      // issueAccessToken()이 자동으로 저장하지 않으므로 수동 저장 필요
      await TokenManagerProvider.instance.manager.setToken(token);
      
      return token;
    } finally {
      // 콜백 해제
      setKakaoAuthCodeCallback(null);
      _authCodeCompleter = null;
    }
  }

  /// 카카오 토큰을 Supabase 세션으로 교환 (Edge Function 호출)
  Future<bool> _exchangeKakaoToken(String kakaoAccessToken) async {
    try {
      print('🔐 [EDGE] Edge Function 호출 중... (kakao-login)');
      final response = await _supabase.functions.invoke(
        'kakao-login',
        body: {'access_token': kakaoAccessToken},
      );
      
      print('🔐 [EDGE] 응답 상태: ${response.status}');
      if (response.status != 200) {
        print('🔐 [EDGE] ❌ 응답 실패: ${response.data}');
        return false;
      }
      
      final data = response.data as Map<String, dynamic>;
      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;
      
      print('🔐 [EDGE] 토큰 수신: access=${accessToken != null}, refresh=${refreshToken != null}');
      
      if (accessToken == null || refreshToken == null) {
        print('🔐 [EDGE] ❌ 토큰 누락');
        return false;
      }
      
      // Supabase 세션 설정
      print('🔐 [EDGE] Supabase 세션 설정 중...');
      final authResponse = await _supabase.auth.setSession(refreshToken);
      
      if (authResponse.session != null) {
        _userId = authResponse.user?.id;
        _isKakaoLoggedIn = true;
        print('🔐 [EDGE] ✅ 세션 설정 성공, userId: $_userId');
        return true;
      }
      
      print('🔐 [EDGE] ❌ 세션 설정 실패');
      return false;
    } catch (e) {
      print('🔐 [EDGE] ❌ 예외 발생: $e');
      return false;
    }
  }

  Future<bool> loginWithKakao() async {
    print('🔐 [AUTH] loginWithKakao: 시작');
    _isLoading = true;
    notifyListeners();

    try {
      // Android keyHash 출력 (디버깅용)
      if (Platform.isAndroid) {
        try {
          final keyHash = await KakaoSdk.origin;
          print('🔑 [KEYHASH] 현재 앱의 keyHash: $keyHash');
          print('🔑 [KEYHASH] ⚠️ 이 값을 카카오 개발자 콘솔에 등록하세요!');
        } catch (e) {
          print('🔑 [KEYHASH] keyHash 확인 실패: $e');
        }
      }
      
      bool isInstalled = await isKakaoTalkInstalled();
      print('🔐 [AUTH] 카카오톡 설치 여부: $isInstalled, Platform: ${Platform.isAndroid ? "Android" : "iOS"}');
      OAuthToken token;

      // Android에서는 딥링크 콜백 방식 사용 (app_links와의 충돌 회피)
      if (Platform.isAndroid && !isInstalled) {
        print('🔐 [AUTH] Android 카카오계정 로그인 시도 (딥링크 방식)');
        token = await _loginWithKakaoAccountAndroid();
        print('🔐 [AUTH] Android 토큰 발급 성공: ${token.accessToken.substring(0, 20)}...');
      } else if (isInstalled) {
        try {
          print('🔐 [AUTH] 카카오톡 로그인 시도');
          token = await UserApi.instance.loginWithKakaoTalk();
          print('🔐 [AUTH] 카카오톡 토큰 발급 성공');
        } catch (error) {
          print('🔐 [AUTH] 카카오톡 로그인 실패: $error');
          if (error is PlatformException && error.code == 'CANCELED') {
            _isLoading = false;
            notifyListeners();
            return false;
          }
          // Android에서 카카오톡 실패 시 딥링크 콜백 방식 사용
          if (Platform.isAndroid) {
            print('🔐 [AUTH] Android fallback: 딥링크 방식으로 재시도');
            token = await _loginWithKakaoAccountAndroid();
          } else {
            token = await UserApi.instance.loginWithKakaoAccount();
          }
        }
      } else {
        try {
          print('🔐 [AUTH] 카카오계정 로그인 시도 (iOS)');
          token = await UserApi.instance.loginWithKakaoAccount();
        } catch (error) {
          print('🔐 [AUTH] 카카오계정 로그인 실패: $error');
           _isLoading = false;
           notifyListeners();
           return false;
        }
      }

      // 카카오 사용자 정보 가져오기
      print('🔐 [AUTH] 카카오 사용자 정보 조회 중...');
      _kakaoUser = await UserApi.instance.me();
      print('🔐 [AUTH] 카카오 사용자: ${_kakaoUser?.kakaoAccount?.email ?? _kakaoUser?.id}');
      
      // Edge Function 호출해서 Supabase 세션 생성
      print('🔐 [AUTH] Edge Function 호출 시작...');
      final success = await _exchangeKakaoToken(token.accessToken);
      print('🔐 [AUTH] Edge Function 결과: $success');
      
      if (success) {
        print('🔐 [AUTH] ✅ 로그인 성공! isLoggedIn = true 설정');
        _isKakaoLoggedIn = true;
        notifyListeners();
        print('🔐 [AUTH] notifyListeners() 호출 완료');
        return true;
      } else {
        // Edge Function 실패해도 카카오 로그인은 유지
        print('🔐 [AUTH] ⚠️ Edge Function 실패했지만 카카오 로그인 유지');
        _isKakaoLoggedIn = true;
        notifyListeners();
        print('🔐 [AUTH] notifyListeners() 호출 완료 (Edge Function 실패 케이스)');
        return true;
      }
    } catch (error) {
      print('🔐 [AUTH] ❌ 로그인 예외 발생: $error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
      print('🔐 [AUTH] loginWithKakao 종료, isLoggedIn: $_isKakaoLoggedIn');
    }
  }

  String _generateRandomString() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  Future<LoginResult> loginWithApple() async {
    if (!Platform.isIOS) {
      return LoginResult.failed;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final rawNonce = _generateRandomString();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        return LoginResult.failed;
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      if (response.session != null) {
        _userId = response.user?.id;
        
        // 프로필 존재 여부 확인
        final profileExists = await _checkProfileExists(_userId!);
        
        if (profileExists) {
          _isKakaoLoggedIn = true;
          notifyListeners();
          return LoginResult.success;
        } else {
          // 신규 회원 - 약관 동의 필요
          return LoginResult.needsSignup;
        }
      }

      return LoginResult.failed;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return LoginResult.cancelled;
      } else {
        return LoginResult.failed;
      }
    } catch (error) {
      return LoginResult.failed;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _checkProfileExists(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  void completeAppleSignup() {
    _isKakaoLoggedIn = true;
    notifyListeners();
  }

  Future<void> cancelAppleSignup() async {
    await _supabase.auth.signOut();
    _userId = null;
    _isKakaoLoggedIn = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await UserApi.instance.logout();
    } catch (e) {
      // ignore
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
      } catch (e) {
        // ignore
      }

      _isKakaoLoggedIn = false;
      _kakaoUser = null;
      _userId = null;

      await _supabase.auth.signOut();
      
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }
}
