import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  
  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  Future<void> initialize() async {
    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || anonKey == null || url.isEmpty || anonKey.isEmpty) {
      // 개발 중에는 로그만 남기고 에러를 던지지 않도록 처리하거나,
      // 필수 값이므로 에러를 던질 수 있습니다.
      print('Warning: Supabase URL or Key is missing in .env');
      return;
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        // Supabase가 자동으로 딥링크를 처리하지 않도록 설정
        // 카카오 로그인 딥링크와 충돌 방지
        authFlowType: AuthFlowType.implicit,
      ),
    );
  }

  SupabaseClient get client => Supabase.instance.client;
}

