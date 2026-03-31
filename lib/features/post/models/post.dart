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
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

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

  CreatePostRequest({
    required this.userId,
    required this.carMaker,
    required this.carModel,
    this.carVariant,
    required this.imageUrl,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'car_maker': carMaker,
      'car_model': carModel,
      'car_variant': carVariant,
      'image_url': imageUrl,
      'description': description,
    };
  }
}
