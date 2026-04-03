/// マイカー情報モデル（SharedPreferences でローカル保存）
class MyCar {
  final String? maker;
  final String? model;
  final String? variant;

  const MyCar({this.maker, this.model, this.variant});

  bool get hasData => maker != null && maker!.isNotEmpty;

  MyCar copyWith({String? maker, String? model, String? variant}) {
    return MyCar(
      maker: maker ?? this.maker,
      model: model ?? this.model,
      variant: variant ?? this.variant,
    );
  }
}
