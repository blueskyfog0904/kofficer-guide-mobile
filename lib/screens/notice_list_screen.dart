import 'package:flutter/material.dart';
import '../services/board_service.dart';
import 'notice_detail_screen.dart';

/// 공지사항 목록 화면
class NoticeListScreen extends StatefulWidget {
  const NoticeListScreen({super.key});

  @override
  State<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends State<NoticeListScreen> {
  final _boardService = BoardService();
  List<Post> _notices = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasMore = true;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadNotices();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadNotices() async {
    setState(() => _isLoading = true);
    
    final notices = await _boardService.getNotices(page: 1);
    
    if (mounted) {
      setState(() {
        _notices = notices;
        _currentPage = 1;
        _hasMore = notices.length >= 20;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    final nextPage = _currentPage + 1;
    final moreNotices = await _boardService.getNotices(page: nextPage);
    
    if (mounted) {
      setState(() {
        _notices.addAll(moreNotices);
        _currentPage = nextPage;
        _hasMore = moreNotices.length >= 20;
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}분 전';
      }
      return '${diff.inHours}시간 전';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    } else {
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotices,
        child: _isLoading && _notices.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _notices.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.campaign_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('공지사항이 없습니다.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _notices.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      if (index >= _notices.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      
                      final notice = _notices[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: notice.isPinned
                            ? const Icon(Icons.push_pin, color: Colors.orange)
                            : null,
                        title: Text(
                          notice.title,
                          style: TextStyle(
                            fontWeight: notice.isPinned ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              _formatDate(notice.createdAt),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.visibility, size: 14, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text(
                              '${notice.viewCount}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NoticeDetailScreen(noticeId: notice.id),
                            ),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}




