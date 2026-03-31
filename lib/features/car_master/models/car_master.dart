/// 車種マスターのモデルクラス
class CarMaster {
  final int id;
  final String maker;
  final String model;
  final String? variant;
  final int? yearFrom;
  final int? yearTo;
  final DateTime createdAt;
  final DateTime updatedAt;

  CarMaster({
    required this.id,
    required this.maker,
    required this.model,
    this.variant,
    this.yearFrom,
    this.yearTo,
    required this.createdAt,
    required this.updatedAt,
  });

  /// JSONからCarMasterオブジェクトを生成
  factory CarMaster.fromJson(Map<String, dynamic> json) {
    return CarMaster(
      id: json['id'] as int,
      maker: json['maker'] as String,
      model: json['model'] as String,
      variant: json['variant'] as String?,
      yearFrom: json['year_from'] as int?,
      yearTo: json['year_to'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// CarMasterオブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'maker': maker,
      'model': model,
      'variant': variant,
      'year_from': yearFrom,
      'year_to': yearTo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// 車の表示名を取得（メーカー + 車種 + 型式）
  String get displayName {
    final parts = [maker, model];
    if (variant != null && variant!.isNotEmpty) {
      parts.add('($variant)');
    }
    return parts.join(' ');
  }

  /// 年式の表示文字列を取得
  String get yearRange {
    if (yearFrom == null) return '不明';
    if (yearTo == null) return '$yearFrom年〜現行';
    return '$yearFrom年〜$yearTo年';
  }

  /// 検索用の文字列を取得
  String get searchText {
    return '$maker $model ${variant ?? ''}'.toLowerCase();
  }
}
