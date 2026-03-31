import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:car_library/shared/services/api_service.dart';

/// ApiServiceのプロバイダー
final apiServiceProvider = Provider<ApiService>((ref) {
  final service = ApiService();
  ref.onDispose(() => service.dispose());
  return service;
});
