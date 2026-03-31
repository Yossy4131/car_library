import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:car_library/core/config/app_config.dart';
import 'package:car_library/core/constants/api_constants.dart';
import 'package:car_library/features/post/models/post.dart';
import 'package:car_library/features/car_master/models/car_master.dart';

/// Cloudflare Workers APIとの通信を担当するサービスクラス
class ApiService {
  final http.Client _client;
  late final String _baseUrl;

  ApiService({http.Client? client}) : _client = client ?? http.Client() {
    _baseUrl = AppConfig.apiBaseUrl;
    if (_baseUrl.isEmpty) {
      throw Exception('API_BASE_URL is not configured in .env file');
    }
  }

  /// 共通のHTTPヘッダーを取得
  Map<String, String> _getHeaders({String? authToken}) {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  /// エラーハンドリング付きのGETリクエスト
  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: queryParams);
    
    try {
      final response = await _client.get(
        uri,
        headers: _getHeaders(),
      ).timeout(Duration(seconds: AppConstants.apiTimeout));

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
  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$path');
    
    try {
      final response = await _client.post(
        uri,
        headers: _getHeaders(),
        body: json.encode(body),
      ).timeout(Duration(seconds: AppConstants.apiTimeout));

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
      final response = await _client.delete(
        uri,
        headers: _getHeaders(),
      ).timeout(Duration(seconds: AppConstants.apiTimeout));

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
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (maker != null) queryParams['maker'] = maker;
    if (model != null) queryParams['model'] = model;

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

  // ========== 車種マスター関連のAPI ==========

  /// 車種マスター一覧を取得
  Future<List<CarMaster>> getCars({String? maker, String? search}) async {
    final queryParams = <String, String>{};
    if (maker != null) queryParams['maker'] = maker;
    if (search != null) queryParams['search'] = search;

    final data = await _get(ApiEndpoints.carMaster, queryParams: queryParams);
    final carsJson = data['cars'] as List;
    return carsJson.map((json) => CarMaster.fromJson(json)).toList();
  }

  /// メーカー一覧を取得
  Future<List<String>> getMakers() async {
    final data = await _get('${ApiEndpoints.carMaster}/makers');
    return (data['makers'] as List).cast<String>();
  }

  /// リソースをクリーンアップ
  void dispose() {
    _client.close();
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
