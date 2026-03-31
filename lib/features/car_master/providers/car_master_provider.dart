import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:car_library/features/car_master/models/car_master.dart';
import 'package:car_library/shared/providers/api_service_provider.dart';

/// 車種マスター一覧を管理するプロバイダー
final carsProvider = FutureProvider.family<List<CarMaster>, CarQueryParams>((
  ref,
  params,
) async {
  final apiService = ref.watch(apiServiceProvider);
  return await apiService.getCars(maker: params.maker, search: params.search);
});

/// メーカー一覧を管理するプロバイダー
final makersProvider = FutureProvider<List<String>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  return await apiService.getMakers();
});

/// 車種マスターのクエリパラメータ
class CarQueryParams {
  final String? maker;
  final String? search;

  const CarQueryParams({this.maker, this.search});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CarQueryParams &&
        other.maker == maker &&
        other.search == search;
  }

  @override
  int get hashCode {
    return Object.hash(maker, search);
  }
}
