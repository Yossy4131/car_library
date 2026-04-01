import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:car_library/shared/services/api_service.dart';
import 'package:car_library/features/post/models/post.dart';
import 'package:car_library/features/auth/providers/auth_provider.dart';
import 'package:car_library/shared/providers/api_service_provider.dart';

/// 投稿一覧を管理するプロバイダー
final postsProvider = FutureProvider.family<List<Post>, PostsQueryParams>((
  ref,
  params,
) async {
  final apiService = ref.watch(apiServiceProvider);
  return await apiService.getPosts(
    limit: params.limit,
    offset: params.offset,
    maker: params.maker,
    model: params.model,
  );
});

/// 投稿詳細を管理するプロバイダー
final postDetailProvider = FutureProvider.family<Post, int>((
  ref,
  postId,
) async {
  final apiService = ref.watch(apiServiceProvider);
  return await apiService.getPost(postId);
});

/// 投稿一覧のクエリパラメータ
class PostsQueryParams {
  final int limit;
  final int offset;
  final String? maker;
  final String? model;

  const PostsQueryParams({
    this.limit = 20,
    this.offset = 0,
    this.maker,
    this.model,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PostsQueryParams &&
        other.limit == limit &&
        other.offset == offset &&
        other.maker == maker &&
        other.model == model;
  }

  @override
  int get hashCode {
    return Object.hash(limit, offset, maker, model);
  }
}

/// 投稿の作成・削除を管理するコントローラー
class PostController extends StateNotifier<AsyncValue<void>> {
  final ApiService _apiService;

  PostController(this._apiService) : super(const AsyncValue.data(null));

  /// 新規投稿を作成
  Future<int?> createPost(CreatePostRequest request) async {
    state = const AsyncValue.loading();
    try {
      final id = await _apiService.createPost(request);
      state = const AsyncValue.data(null);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// 投稿を削除
  Future<bool> deletePost(int postId) async {
    state = const AsyncValue.loading();
    try {
      await _apiService.deletePost(postId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// 投稿の任意フィールド（メーカー・車種・型式・説明）を更新
  Future<bool> updatePost(
    int postId, {
    String? carMaker,
    String? carModel,
    String? carVariant,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _apiService.updatePost(
        postId,
        carMaker: carMaker,
        carModel: carModel,
        carVariant: carVariant,
        description: description,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// PostControllerのプロバイダー
final postControllerProvider =
    StateNotifierProvider<PostController, AsyncValue<void>>((ref) {
      final apiService = ref.watch(apiServiceProvider);
      return PostController(apiService);
    });

/// 自分の投稿一覧を管理するプロバイダー
/// authProviderを監視することで、ログイン/ログアウト時に自動再フェッチする
final myPostsProvider = FutureProvider<List<Post>>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) return [];
  final apiService = ref.watch(apiServiceProvider);
  return apiService.getMyPosts();
});
