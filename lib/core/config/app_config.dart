/// アプリケーション全体で使用される環境変数を管理するクラス
class AppConfig {
  /// Cloudflare Workers APIのベースURL
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://car-library-api.y-yoshida1031.workers.dev',
  );

  /// アプリ名
  static const String appName = 'Car Lovers';

  /// 環境変数が正しく設定されているかをチェック
  static bool get isConfigured => apiBaseUrl.isNotEmpty;
}
