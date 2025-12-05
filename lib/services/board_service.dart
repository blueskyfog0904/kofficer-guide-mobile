import 'supabase_service.dart';

/// 게시글 모델
class Post {
  final String id;
  final String title;
  final String content;
  final String boardType;
  final int viewCount;
  final int likeCount;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PostAuthor? author;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.boardType,
    required this.viewCount,
    required this.likeCount,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
    this.author,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      boardType: json['board_type'] ?? 'notice',
      viewCount: json['view_count'] ?? 0,
      likeCount: json['like_count'] ?? 0,
      isPinned: json['is_pinned'] ?? false,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      author: json['author'] != null ? PostAuthor.fromJson(json['author']) : null,
    );
  }
}

/// 게시글 작성자 모델
class PostAuthor {
  final String? nickname;
  final String? avatarUrl;

  PostAuthor({
    this.nickname,
    this.avatarUrl,
  });

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    return PostAuthor(
      nickname: json['nickname'],
      avatarUrl: json['avatar_url'],
    );
  }
}

/// 게시판 서비스
class BoardService {
  final _client = SupabaseService().client;

  /// 공지사항 목록 조회
  Future<List<Post>> getNotices({int page = 1, int size = 20}) async {
    try {
      final from = (page - 1) * size;
      final to = from + size - 1;

      final response = await _client
          .from('posts')
          .select('*')
          .eq('board_type', 'notice')
          .eq('is_active', true)
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false)
          .range(from, to);

      final posts = <Post>[];
      for (final postJson in response as List) {
        // 작성자 정보 별도 조회
        PostAuthor? author;
        if (postJson['author_id'] != null) {
          try {
            final authorResponse = await _client
                .from('profiles')
                .select('nickname, avatar_url')
                .eq('user_id', postJson['author_id'])
                .maybeSingle();
            
            if (authorResponse != null) {
              author = PostAuthor.fromJson(authorResponse as Map<String, dynamic>);
            }
          } catch (e) {
            print('작성자 정보 조회 실패: $e');
          }
        }

        final postWithAuthor = <String, dynamic>{
          ...(postJson as Map<String, dynamic>),
          'author': author != null ? {'nickname': author.nickname, 'avatar_url': author.avatarUrl} : null,
        };
        posts.add(Post.fromJson(postWithAuthor));
      }

      return posts;
    } catch (e) {
      print('Error fetching notices: $e');
      return [];
    }
  }

  /// 공지사항 상세 조회
  Future<Post?> getNoticeById(String id) async {
    try {
      final response = await _client
          .from('posts')
          .select('*')
          .eq('id', id)
          .single();

      // 조회수 증가
      await _client
          .from('posts')
          .update({'view_count': (response['view_count'] ?? 0) + 1})
          .eq('id', id);

      // 작성자 정보 별도 조회
      PostAuthor? author;
      if (response['author_id'] != null) {
        try {
          final authorResponse = await _client
              .from('profiles')
              .select('nickname, avatar_url')
              .eq('user_id', response['author_id'])
              .maybeSingle();
          
          if (authorResponse != null) {
            author = PostAuthor.fromJson(authorResponse as Map<String, dynamic>);
          }
        } catch (e) {
          print('작성자 정보 조회 실패: $e');
        }
      }

      final postWithAuthor = <String, dynamic>{
        ...(response as Map<String, dynamic>),
        'author': author != null ? {'nickname': author.nickname, 'avatar_url': author.avatarUrl} : null,
      };
      
      return Post.fromJson(postWithAuthor);
    } catch (e) {
      print('Error fetching notice: $e');
      return null;
    }
  }

  /// 최신 공지사항 조회 (홈 화면용)
  Future<List<Post>> getLatestNotices({int limit = 5}) async {
    try {
      final response = await _client
          .from('posts')
          .select('*')
          .eq('board_type', 'notice')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).map((json) => Post.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error fetching latest notices: $e');
      return [];
    }
  }
}



