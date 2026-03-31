import 'package:flutter_dotenv/flutter_dotenv.dart';

/// アプリケーション全体で使用される環境変数を管理するクラス
class AppConfig {
  /// Cloudflare Workers APIのベースURL
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';

  /// アプリ名
  static String get appName => dotenv.env['APP_NAME'] ?? '皆の車博覧会';

  /// 環境変数が正しく設定されているかをチェック
  static bool get isConfigured => apiBaseUrl.isNotEmpty;
}
