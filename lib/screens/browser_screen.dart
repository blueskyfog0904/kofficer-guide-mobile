import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BrowserScreen extends StatefulWidget {
  final String? initialUrl;

  const BrowserScreen({super.key, this.initialUrl});

  @override
  State<BrowserScreen> createState() => BrowserScreenState();
}

class BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isNavigatingBack = false; // 뒤로가기 중인지 확인

  @override
  void initState() {
    super.initState();
    final url = widget.initialUrl ?? 'https://m.search.naver.com/search.naver?query=맛집';
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            // 뒤로가기 중이 아닐 때만 로딩 표시
            if (!_isNavigatingBack) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (_) {
            setState(() {
              _isLoading = false;
              _isNavigatingBack = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }
  
  void loadUrl(String url) {
    _controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('인터넷'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
             if (await _controller.canGoBack()) {
               setState(() {
                 _isNavigatingBack = true;
                 _isLoading = false; // 뒤로가기 시 로딩바 제거
               });
               _controller.goBack();
             }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _goForward,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading && !_isNavigatingBack)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
  
  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      setState(() {
        _isNavigatingBack = true;
        _isLoading = false; // 뒤로가기 시 로딩바 제거
      });
      _controller.goBack();
    }
  }
  
  Future<void> _goForward() async {
    if (await _controller.canGoForward()) {
      setState(() {
        _isLoading = true;
      });
      _controller.goForward();
    }
  }
}
