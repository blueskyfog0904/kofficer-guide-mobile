package com.thenaum.kofficerguide

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent?) {
        // 딥링크 처리 - FlutterFragmentActivity가 Flutter 엔진에 전달
        val uri = intent?.data
        if (uri != null && uri.scheme?.startsWith("kakao") == true) {
            // 카카오 딥링크는 Flutter의 app_links에서 처리됨
        }
    }
}
