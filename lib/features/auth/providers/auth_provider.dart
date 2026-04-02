import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_library/features/auth/models/auth_state.dart';
import 'package:car_library/shared/providers/api_service_provider.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this.ref) : super(const AuthState()) {
    _restore();
  }

  final Ref ref;

  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userId = prefs.getString(_userIdKey);
    if (token != null && userId != null) {
      ref.read(apiServiceProvider).setAuthToken(token);
      try {
        // トークンが本番でも有効か検証
        await ref.read(apiServiceProvider).getCurrentUser();
        state = state.copyWith(token: token, userId: userId);
      } catch (_) {
        // 無効（期限切れ・JWT_SECRET変更など）の場合はクリア
        await prefs.remove(_tokenKey);
        await prefs.remove(_userIdKey);
        ref.read(apiServiceProvider).setAuthToken(null);
      }
    }
  }

  Future<bool> login(String userId, String password) async {
    try {
      final resp = await ref.read(apiServiceProvider).login(userId, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, resp.token);
      await prefs.setString(_userIdKey, resp.userId);
      ref.read(apiServiceProvider).setAuthToken(resp.token);
      state = state.copyWith(token: resp.token, userId: resp.userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> register(String userId, String password) async {
    try {
      final resp = await ref
          .read(apiServiceProvider)
          .register(userId, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, resp.token);
      await prefs.setString(_userIdKey, resp.userId);
      ref.read(apiServiceProvider).setAuthToken(resp.token);
      state = state.copyWith(token: resp.token, userId: resp.userId);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    ref.read(apiServiceProvider).setAuthToken(null);
    state = state.copyWith(clearAuth: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
