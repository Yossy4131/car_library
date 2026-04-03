/// いいね状態モデル
class LikeStatus {
  final int count;
  final bool liked;

  const LikeStatus({required this.count, required this.liked});

  factory LikeStatus.fromJson(Map<String, dynamic> json) {
    return LikeStatus(
      count: (json['count'] as num).toInt(),
      liked: json['liked'] as bool,
    );
  }
}

/// コメントモデル
class Comment {
  final int id;
  final int postId;
  final String userId;
  final String body;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.body,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: (json['id'] as num).toInt(),
      postId: (json['post_id'] as num).toInt(),
      userId: json['user_id'] as String,
      body: json['body'] as String,
      createdAt: _parseUtc(json['created_at'] as String),
    );
  }

  /// UTC文字列をDateTime（ローカルタイム）に変換
  static DateTime _parseUtc(String s) =>
      DateTime.parse(s.contains('Z') || s.contains('+') ? s : '${s}Z');
}
