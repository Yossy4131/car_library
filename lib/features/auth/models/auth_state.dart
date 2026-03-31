class AuthState {
  final String? userId;
  final String? token;
  final bool isLoading;

  const AuthState({this.userId, this.token, this.isLoading = false});

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  AuthState copyWith({
    String? userId,
    String? token,
    bool? isLoading,
    bool clearAuth = false,
  }) {
    return AuthState(
      userId: clearAuth ? null : (userId ?? this.userId),
      token: clearAuth ? null : (token ?? this.token),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
