import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BrowserScreen extends StatefulWidget {
  final String? initialUrl;

  const BrowserScreen({super.key, this.initialUrl});

  @override
  State<BrowserScreen> createState() => BrowserScreenState();
}

class BrowserScreenState extends State<BrowserScreen> {
  late WebViewController _controller;
  int _controllerGeneration = 0;
  bool _isLoading = true;
  bool _isNavigatingBack = false; // 뒤로가기 중인지 확인

  @override
  void initState() {
    super.initState();
    final url =
        widget.initialUrl ?? 'https://m.search.naver.com/search.naver?query=맛집';

    _controller = _createController(url);
  }

  WebViewController _createController(String url) {
    final generation = ++_controllerGeneration;

    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted || generation != _controllerGeneration) {
              return;
            }

            // 뒤로가기 중이 아닐 때만 로딩 표시
            if (!_isNavigatingBack) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (_) {
            if (!mounted || generation != _controllerGeneration) {
              return;
            }

            setState(() {
              _isLoading = false;
              _isNavigatingBack = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  void loadUrl(String url, {bool resetHistory = false}) {
    if (resetHistory) {
      setState(() {
        _isLoading = true;
        _isNavigatingBack = false;
        _controller = _createController(url);
      });
      return;
    }

    _controller.loadRequest(Uri.parse(url));
  }

  Future<bool> handleBack() async {
    if (!await _controller.canGoBack()) {
      return false;
    }

    if (mounted) {
      setState(() {
        _isNavigatingBack = true;
        _isLoading = false; // 뒤로가기 시 로딩바 제거
      });
    }

    await _controller.goBack();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('인터넷'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await handleBack();
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

  Future<void> _goForward() async {
    if (await _controller.canGoForward()) {
      setState(() {
        _isLoading = true;
      });
      _controller.goForward();
    }
  }
}
