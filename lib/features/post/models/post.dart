/// 投稿データのモデルクラス
class Post {
  final int id;
  final String userId;
  final String carMaker;
  final String carModel;
  final String? carVariant;
  final String imageUrl;
  final String? originalImageUrl;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likesCount;
  final int commentsCount;
  final List<String> tags;

  Post({
    required this.id,
    required this.userId,
    required this.carMaker,
    required this.carModel,
    this.carVariant,
    required this.imageUrl,
    this.originalImageUrl,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.tags = const [],
  });

  /// JSONからPostオブジェクトを生成
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      carMaker: json['car_maker'] as String,
      carModel: json['car_model'] as String,
      carVariant: json['car_variant'] as String?,
      imageUrl: json['image_url'] as String,
      originalImageUrl: json['original_image_url'] as String?,
      description: json['description'] as String?,
      createdAt: _parseUtc(json['created_at'] as String),
      updatedAt: _parseUtc(json['updated_at'] as String),
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      tags:
          (json['tags_csv'] as String?)
              ?.split(',')
              .where((t) => t.isNotEmpty)
              .toList() ??
          [],
    );
  }

  /// UTC文字列をDateTime（ローカルタイム）に変換
  /// SQLite の CURRENT_TIMESTAMP は 'YYYY-MM-DD HH:MM:SS' 形式でUTCを返すため、Zを付与してUTCとして解釈する
  static DateTime _parseUtc(String s) =>
      DateTime.parse(s.contains('Z') || s.contains('+') ? s : '${s}Z');

  /// PostオブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'car_maker': carMaker,
      'car_model': carModel,
      'car_variant': carVariant,
      'image_url': imageUrl,
      'original_image_url': originalImageUrl,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'tags_csv': tags.join(','),
    };
  }

  /// 車の表示名を取得（メーカー + 車種 + 型式）
  String get displayName {
    final parts = [carMaker, carModel];
    if (carVariant != null && carVariant!.isNotEmpty) {
      parts.add('($carVariant)');
    }
    return parts.join(' ');
  }

  /// サムネイル画像URL（幅800pxにリサイズ・圧縮済み）
  /// 一覧表示での転送量削減に使用する
  String get thumbnailUrl => '$imageUrl?w=800&q=80';

  /// コピーを作成
  Post copyWith({
    int? id,
    String? userId,
    String? carMaker,
    String? carModel,
    String? carVariant,
    String? imageUrl,
    String? originalImageUrl,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likesCount,
    int? commentsCount,
    List<String>? tags,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      carMaker: carMaker ?? this.carMaker,
      carModel: carModel ?? this.carModel,
      carVariant: carVariant ?? this.carVariant,
      imageUrl: imageUrl ?? this.imageUrl,
      originalImageUrl: originalImageUrl ?? this.originalImageUrl,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      tags: tags ?? this.tags,
    );
  }
}

/// 新規投稿作成用のDTOクラス
class CreatePostRequest {
  final String userId;
  final String carMaker;
  final String carModel;
  final String? carVariant;
  final String imageUrl;
  final String? description;
  final List<String> tags;

  CreatePostRequest({
    required this.userId,
    required this.carMaker,
    required this.carModel,
    this.carVariant,
    required this.imageUrl,
    this.description,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'car_maker': carMaker,
      'car_model': carModel,
      'car_variant': carVariant,
      'image_url': imageUrl,
      'description': description,
      'tags': tags,
    };
  }
}
