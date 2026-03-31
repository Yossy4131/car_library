/// APIエンドポイントの定義
class ApiEndpoints {
  static const String posts = '/posts';
  static const String carMaster = '/cars';
  static const String carMakers = '/cars/makers';
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authMe = '/auth/me';
  static const String upload = '/upload';
  static const String detect = '/detect';
  static const String myPosts = '/users/me/posts';
}

/// アプリケーション全体で使用される定数
class AppConstants {
  // タイムアウト設定（秒）
  static const int apiTimeout = 30;

  // ページネーション
  static const int postsPerPage = 20;

  // 画像設定
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const List<String> supportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];
}
