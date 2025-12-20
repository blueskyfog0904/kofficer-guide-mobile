import 'package:flutter/material.dart';
import 'terms_page.dart';
import 'privacy_page.dart';

/// 약관 탭 화면 (서비스 이용약관 / 개인정보처리방침)
class TermsTabsScreen extends StatefulWidget {
  const TermsTabsScreen({super.key});

  @override
  State<TermsTabsScreen> createState() => _TermsTabsScreenState();
}

class _TermsTabsScreenState extends State<TermsTabsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('약관'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '서비스 이용약관'),
            Tab(text: '개인정보처리방침'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          TermsPage(),
          PrivacyPage(),
        ],
      ),
    );
  }
}




