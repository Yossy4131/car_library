import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_library/features/mypage/models/my_car.dart';

class MyCarNotifier extends StateNotifier<MyCar> {
  MyCarNotifier() : super(const MyCar()) {
    _restore();
  }

  static const _makerKey = 'mycar_maker';
  static const _modelKey = 'mycar_model';
  static const _variantKey = 'mycar_variant';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = MyCar(
      maker: prefs.getString(_makerKey),
      model: prefs.getString(_modelKey),
      variant: prefs.getString(_variantKey),
    );
  }

  Future<void> save(MyCar car) async {
    final prefs = await SharedPreferences.getInstance();

    if (car.maker != null && car.maker!.isNotEmpty) {
      await prefs.setString(_makerKey, car.maker!);
    } else {
      await prefs.remove(_makerKey);
    }

    if (car.model != null && car.model!.isNotEmpty) {
      await prefs.setString(_modelKey, car.model!);
    } else {
      await prefs.remove(_modelKey);
    }

    if (car.variant != null && car.variant!.isNotEmpty) {
      await prefs.setString(_variantKey, car.variant!);
    } else {
      await prefs.remove(_variantKey);
    }

    state = car;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_makerKey);
    await prefs.remove(_modelKey);
    await prefs.remove(_variantKey);
    state = const MyCar();
  }
}

final myCarProvider = StateNotifierProvider<MyCarNotifier, MyCar>((ref) {
  return MyCarNotifier();
});
