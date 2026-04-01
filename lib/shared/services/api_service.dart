import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:car_library/core/config/app_config.dart';
import 'package:car_library/core/constants/api_constants.dart';
import 'package:car_library/features/post/models/post.dart';
import 'package:car_library/features/post/models/like_comment.dart';

/// Cloudflare Workers APIとの通信を担当するサービスクラス
class ApiService {
  final http.Client _client;
  late final String _baseUrl;
  String? _authToken;

  ApiService({http.Client? client}) : _client = client ?? http.Client() {
    _baseUrl = AppConfig.apiBaseUrl;
    if (_baseUrl.isEmpty) {
      throw Exception('API_BASE_URL is not configured in .env file');
    }
  }

  /// 共通のHTTPヘッダーを取得
  Map<String, String> _getHeaders({String? authToken}) {
    final headers = {'Content-Type': 'application/json'};
    final token = authToken ?? _authToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// エラーハンドリング付きのGETリクエスト
  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _client
          .get(uri, headers: _getHeaders())
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final error = json.decode(response.body);
        throw ApiException(
          error['error'] ?? 'Unknown error',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e', 0);
    }
  }

  /// エラーハンドリング付きのPOSTリクエスト
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');

    try {
      final response = await _client
          .post(uri, headers: _getHeaders(), body: json.encode(body))
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final error = json.decode(response.body);
        throw ApiException(
          error['error'] ?? 'Unknown error',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e', 0);
    }
  }

  /// エラーハンドリング付きのDELETEリクエスト
  Future<Map<String, dynamic>> _delete(String path) async {
    final uri = Uri.parse('$_baseUrl$path');

    try {
      final response = await _client
          .delete(uri, headers: _getHeaders())
          .timeout(Duration(seconds: AppConstants.apiTimeout));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final error = json.decode(response.body);
        throw ApiException(
          error['error'] ?? 'Unknown error',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e', 0);
    }
  }

  /// エラーハンドリング付きのPATCHリクエスト
  Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');

    try {
      final request = http.Request('PATCH', uri);
      request.headers.addAll(_getHeaders());
      request.body = json.encode(body);

      final streamedResponse = await _client
          .send(request)
          .timeout(Duration(seconds: AppConstants.apiTimeout));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final error = json.decode(response.body);
        throw ApiException(
          error['error'] ?? 'Unknown error',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e', 0);
    }
  }

  // ========== 投稿関連のAPI ==========

  /// 投稿一覧を取得
  Future<List<Post>> getPosts({
    int limit = 20,
    int offset = 0,
    String? maker,
    String? model,
    String? tag,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (maker != null) queryParams['maker'] = maker;
    if (model != null) queryParams['model'] = model;
    if (tag != null) queryParams['tag'] = tag;

    final data = await _get(ApiEndpoints.posts, queryParams: queryParams);
    final postsJson = data['posts'] as List;
    return postsJson.map((json) => Post.fromJson(json)).toList();
  }

  /// 投稿詳細を取得
  Future<Post> getPost(int id) async {
    final data = await _get('${ApiEndpoints.posts}/$id');
    return Post.fromJson(data['post']);
  }

  /// 新規投稿を作成
  Future<int> createPost(CreatePostRequest request) async {
    final data = await _post(ApiEndpoints.posts, request.toJson());
    return data['id'] as int;
  }

  /// 投稿を削除
  Future<void> deletePost(int id) async {
    await _delete('${ApiEndpoints.posts}/$id');
  }

  /// 自分の投稿一覧を取得
  Future<List<Post>> getMyPosts() async {
    final data = await _get(ApiEndpoints.myPosts);
    final postsJson = data['posts'] as List;
    return postsJson.map((json) => Post.fromJson(json)).toList();
  }

  /// 投稿の任意フィールドを更新（メーカー・車種・型式・説明）
  Future<void> updatePost(
    int id, {
    String? carMaker,
    String? carModel,
    String? carVariant,
    String? description,
    List<String>? tags,
  }) async {
    final body = <String, dynamic>{
      'car_variant': carVariant,
      'description': description,
    };
    if (carMaker != null) body['car_maker'] = carMaker;
    if (carModel != null) body['car_model'] = carModel;
    if (tags != null) body['tags'] = tags;
    await _patch('${ApiEndpoints.posts}/$id', body);
  }

  // ========== 画像アップロード関連のAPI ==========

  /// 画像をアップロード（オプションでAIマスキング）
  Future<ImageUploadResult> uploadImage(
    List<int> imageBytes,
    String fileName, {
    bool enableMasking = false,
    List<MaskingBox>? maskingRects,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl${ApiEndpoints.upload}',
    ).replace(queryParameters: enableMasking ? {'mask': 'true'} : null);

    try {
      final request = http.MultipartRequest('POST', uri);
      if (_authToken != null && _authToken!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }
      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: fileName),
      );

      // 手動指定のマスキング領域がある場合は送信
      if (maskingRects != null && maskingRects.isNotEmpty) {
        final rectsJson = json.encode(
          maskingRects
              .map(
                (rect) => {
                  'x': rect.x,
                  'y': rect.y,
                  'width': rect.width,
                  'height': rect.height,
                },
              )
              .toList(),
        );
        request.fields['maskingRects'] = rectsJson;
      }

      final streamedResponse = await request.send().timeout(
        Duration(seconds: AppConstants.apiTimeout * 2), // 画像アップロードは時間がかかる
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final imageUrl = data['imageUrl'] as String;
        final originalImageUrl = data['originalImageUrl'] as String?;
        final detectedCount = data['detectedCount'] as int? ?? 0;
        final masked = data['masked'] as bool? ?? false;
        final detectedBoxes =
            (data['detectedBoxes'] as List<dynamic>?)
                ?.map((box) => MaskingBox.fromJson(box as Map<String, dynamic>))
                .toList() ??
            [];

        // 相対パスを絶対パスに変換
        return ImageUploadResult(
          imageUrl: imageUrl.startsWith('http')
              ? imageUrl
              : '$_baseUrl$imageUrl',
          originalImageUrl:
              originalImageUrl != null && !originalImageUrl.startsWith('http')
              ? '$_baseUrl$originalImageUrl'
              : originalImageUrl,
          detectedCount: detectedCount,
          masked: masked,
          detectedBoxes: detectedBoxes,
        );
      } else {
        final error = json.decode(response.body);
        throw ApiException(
          error['error'] ?? 'Upload failed',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error during upload: $e', 0);
    }
  }

  /// AIでナンバープレートを検出（アップロードなし）
  Future<List<MaskingBox>> detectLicensePlates(
    List<int> imageBytes,
    String fileName,
  ) async {
    final uri = Uri.parse('$_baseUrl${ApiEndpoints.detect}');

    try {
      final request = http.MultipartRequest('POST', uri);
      if (_authToken != null && _authToken!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }
      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: fileName),
      );

      final streamedResponse = await request.send().timeout(
        Duration(seconds: AppConstants.apiTimeout * 2),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final detectedBoxes =
            (data['detectedBoxes'] as List<dynamic>?)
                ?.map((box) => MaskingBox.fromJson(box as Map<String, dynamic>))
                .toList() ??
            [];

        return detectedBoxes;
      } else {
        final error = json.decode(response.body);
        throw ApiException(
          error['error'] ?? 'Detection failed',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error during detection: $e', 0);
    }
  }

  // ========== 認証関連のAPI ==========

  Future<AuthResponse> login(String userId, String password) async {
    final data = await _post(ApiEndpoints.authLogin, {
      'userId': userId,
      'password': password,
    });
    return AuthResponse(
      token: data['token'] as String,
      userId: data['userId'] as String,
    );
  }

  Future<AuthResponse> register(String userId, String password) async {
    final data = await _post(ApiEndpoints.authRegister, {
      'userId': userId,
      'password': password,
    });
    return AuthResponse(
      token: data['token'] as String,
      userId: data['userId'] as String,
    );
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    return await _get(ApiEndpoints.authMe);
  }

  // ========== いいね・コメント関連のAPI ==========

  /// いいね状態を取得
  Future<LikeStatus> getLikeStatus(int postId) async {
    final data = await _get('/posts/$postId/likes');
    return LikeStatus.fromJson(data);
  }

  /// いいねを追加
  Future<LikeStatus> addLike(int postId) async {
    final data = await _post('/posts/$postId/likes', {});
    return LikeStatus.fromJson(data);
  }

  /// いいねを取り消し
  Future<LikeStatus> removeLike(int postId) async {
    final data = await _delete('/posts/$postId/likes');
    return LikeStatus.fromJson(data);
  }

  /// コメント一覧を取得
  Future<List<Comment>> getComments(int postId) async {
    final data = await _get('/posts/$postId/comments');
    final list = data['comments'] as List<dynamic>;
    return list
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// コメントを投稿
  Future<Comment> addComment(int postId, String body) async {
    final data = await _post('/posts/$postId/comments', {'body': body});
    return Comment.fromJson(data);
  }

  /// コメントを削除
  Future<void> deleteComment(int postId, int commentId) async {
    await _delete('/posts/$postId/comments/$commentId');
  }

  /// リソースをクリーンアップ
  void dispose() {
    _client.close();
  }
}

/// 画像アップロード結果
class ImageUploadResult {
  final String imageUrl;
  final String? originalImageUrl;
  final int detectedCount;
  final bool masked;
  final List<MaskingBox> detectedBoxes;

  ImageUploadResult({
    required this.imageUrl,
    this.originalImageUrl,
    required this.detectedCount,
    required this.masked,
    this.detectedBoxes = const [],
  });
}

class MaskingBox {
  final double x;
  final double y;
  final double width;
  final double height;

  MaskingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory MaskingBox.fromJson(Map<String, dynamic> json) {
    return MaskingBox(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }
}

/// API通信時のエラーを表すクラス
class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class AuthResponse {
  final String token;
  final String userId;

  AuthResponse({required this.token, required this.userId});
}
