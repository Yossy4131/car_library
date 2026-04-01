import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:car_library/features/post/models/like_comment.dart';
import 'package:car_library/shared/providers/api_service_provider.dart';

// ========== いいね ==========

/// いいね状態プロバイダー（postIdごと）
final likeStatusProvider = FutureProvider.family<LikeStatus, int>((
  ref,
  postId,
) async {
  final api = ref.watch(apiServiceProvider);
  return api.getLikeStatus(postId);
});

/// いいねを操作するNotifier
class LikeNotifier extends StateNotifier<AsyncValue<LikeStatus>> {
  final int postId;
  final _ApiServiceRef _ref;

  LikeNotifier(this.postId, this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final status = await _ref.api.getLikeStatus(postId);
      state = AsyncValue.data(status);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggle() async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      final next = current.liked
          ? await _ref.api.removeLike(postId)
          : await _ref.api.addLike(postId);
      state = AsyncValue.data(next);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

class _ApiServiceRef {
  final Ref _ref;
  _ApiServiceRef(this._ref);
  get api => _ref.read(apiServiceProvider);
}

final likeNotifierProvider =
    StateNotifierProvider.family<LikeNotifier, AsyncValue<LikeStatus>, int>((
      ref,
      postId,
    ) {
      return LikeNotifier(postId, _ApiServiceRef(ref));
    });

// ========== コメント ==========

/// コメント一覧プロバイダー（postIdごと）
final commentsProvider = FutureProvider.family<List<Comment>, int>((
  ref,
  postId,
) async {
  final api = ref.watch(apiServiceProvider);
  return api.getComments(postId);
});
