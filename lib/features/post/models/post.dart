import 'dart:convert';

/// 投稿に紐付く個別メディアアイテム（画像または動画）
class MediaItem {
  final String url;
  final String type; // 'image' | 'video'
  final String? originalUrl;
  final int sortOrder;

  const MediaItem({
    required this.url,
    required this.type,
    this.originalUrl,
    this.sortOrder = 0,
  });

  bool get isVideo => type == 'video';

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      url: json['url'] as String,
      type: (json['type'] as String?) ?? 'image',
      originalUrl: json['original_url'] as String?,
      sortOrder: (json['sort'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'type': type,
    'original_url': originalUrl,
    'sort': sortOrder,
  };
}

/// 投稿データのモデルクラス
class Post {
  final int id;
  final String userId;
  final String carMaker;
  final String carModel;
  final String? carVariant;
  final String imageUrl;
  final String? originalImageUrl;
  final String? videoUrl;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likesCount;
  final int commentsCount;
  final List<String> tags;
  final List<MediaItem> mediaItems;

  Post({
    required this.id,
    required this.userId,
    required this.carMaker,
    required this.carModel,
    this.carVariant,
    required this.imageUrl,
    this.originalImageUrl,
    this.videoUrl,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.tags = const [],
    this.mediaItems = const [],
  });

  /// JSONからPostオブジェクトを生成
  factory Post.fromJson(Map<String, dynamic> json) {
    List<MediaItem> parsedMedia = [];
    final mediaJsonStr = json['media_items_json'] as String?;
    if (mediaJsonStr != null &&
        mediaJsonStr.isNotEmpty &&
        mediaJsonStr != 'null') {
      try {
        final decoded = jsonDecode(mediaJsonStr) as List;
        parsedMedia = decoded
            .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
            .toList();
        parsedMedia.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      } catch (_) {}
    }

    return Post(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      carMaker: json['car_maker'] as String,
      carModel: json['car_model'] as String,
      carVariant: json['car_variant'] as String?,
      imageUrl: json['image_url'] as String? ?? '',
      originalImageUrl: json['original_image_url'] as String?,
      videoUrl: json['video_url'] as String?,
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
      mediaItems: parsedMedia,
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
      'video_url': videoUrl,
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

  /// 実際のメディア一覧（post_media があればそちら、なければ旧フィールドからフォールバック）
  List<MediaItem> get allMediaItems {
    if (mediaItems.isNotEmpty) return mediaItems;
    if (videoUrl != null && videoUrl!.isNotEmpty) {
      return [MediaItem(url: videoUrl!, type: 'video')];
    }
    if (imageUrl.isNotEmpty) {
      return [
        MediaItem(url: imageUrl, type: 'image', originalUrl: originalImageUrl),
      ];
    }
    return [];
  }

  int get mediaCount => allMediaItems.length;

  /// 動画投稿かどうか（最初のメディアで判断）
  bool get isVideo {
    final items = allMediaItems;
    return items.isNotEmpty && items.first.isVideo;
  }

  /// サムネイル画像URL（動画はそのまま、画像は幅800pxリサイズ）
  String get thumbnailUrl {
    final items = allMediaItems;
    if (items.isEmpty) return imageUrl;
    final first = items.first;
    return first.isVideo ? first.url : '${first.url}?w=800&q=80';
  }

  /// コピーを作成
  Post copyWith({
    int? id,
    String? userId,
    String? carMaker,
    String? carModel,
    String? carVariant,
    String? imageUrl,
    String? originalImageUrl,
    String? videoUrl,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likesCount,
    int? commentsCount,
    List<String>? tags,
    List<MediaItem>? mediaItems,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      carMaker: carMaker ?? this.carMaker,
      carModel: carModel ?? this.carModel,
      carVariant: carVariant ?? this.carVariant,
      imageUrl: imageUrl ?? this.imageUrl,
      originalImageUrl: originalImageUrl ?? this.originalImageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      tags: tags ?? this.tags,
      mediaItems: mediaItems ?? this.mediaItems,
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
  final String? videoUrl;
  final String? description;
  final List<String> tags;
  final List<MediaItem> mediaItems;

  CreatePostRequest({
    required this.userId,
    required this.carMaker,
    required this.carModel,
    this.carVariant,
    this.imageUrl = '',
    this.videoUrl,
    this.description,
    this.tags = const [],
    this.mediaItems = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'car_maker': carMaker,
      'car_model': carModel,
      'car_variant': carVariant,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'description': description,
      'tags': tags,
      'media_items': mediaItems.map((m) => m.toJson()).toList(),
    };
  }
}
