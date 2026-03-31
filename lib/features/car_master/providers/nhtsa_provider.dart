import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:car_library/features/car_master/services/nhtsa_service.dart';

/// NHTSAService のインスタンスプロバイダー
final nhtsaServiceProvider = Provider<NHTSAService>((ref) {
  return NHTSAService();
});

/// NHTSA から全メーカー一覧を取得するプロバイダー（キャッシュあり）
final nhtsaMakersProvider = FutureProvider<List<String>>((ref) async {
  ref.keepAlive();
  final service = ref.read(nhtsaServiceProvider);
  return service.getAllMakes();
});

/// 指定メーカーのモデル一覧を取得するプロバイダー（キャッシュあり）
final nhtsaModelsProvider = FutureProvider.family<List<String>, String>((
  ref,
  make,
) async {
  ref.keepAlive();
  final service = ref.read(nhtsaServiceProvider);
  return service.getModelsForMake(make);
});
