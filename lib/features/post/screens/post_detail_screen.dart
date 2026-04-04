import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:car_library/features/post/models/post.dart';
import 'package:car_library/features/post/models/like_comment.dart';
import 'package:car_library/features/post/providers/like_comment_provider.dart';
import 'package:car_library/features/auth/providers/auth_provider.dart';
import 'package:car_library/features/auth/screens/login_screen.dart';
import 'package:car_library/shared/providers/api_service_provider.dart';
import 'package:car_library/features/post/widgets/video_player_widget.dart';
import 'package:intl/intl.dart';

/// 投稿詳細画面 — 写真をフル表示し、いいね・コメントができる
class PostDetailScreen extends HookConsumerWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    final authState = ref.watch(authProvider);
    final isLoggedIn = authState.isAuthenticated;

    final likeState = ref.watch(likeNotifierProvider(post.id));
    final commentsAsync = ref.watch(commentsProvider(post.id));

    final commentController = useTextEditingController();
    final submitting = useState(false);
    final pageController = usePageController();
    final currentPage = useState(0);
    final mediaItems = post.allMediaItems;

    Future<void> submitComment() async {
      final text = commentController.text.trim();
      if (text.isEmpty) return;
      submitting.value = true;
      try {
        final api = ref.read(apiServiceProvider);
        await api.addComment(post.id, text);
        commentController.clear();
        ref.invalidate(commentsProvider(post.id));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('コメントの送信に失敗しました: $e')));
        }
      } finally {
        submitting.value = false;
      }
    }

    Future<void> deleteComment(int commentId) async {
      try {
        final api = ref.read(apiServiceProvider);
        await api.deleteComment(post.id, commentId);
        ref.invalidate(commentsProvider(post.id));
      } catch (_) {}
    }

    void requireLogin() {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          post.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // フル表示メディアエリア
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                PageView.builder(
                  controller: pageController,
                  onPageChanged: (page) => currentPage.value = page,
                  itemCount: mediaItems.length,
                  itemBuilder: (context, index) {
                    final item = mediaItems[index];
                    return item.isVideo
                        ? VideoPlayerWidget(url: item.url)
                        : _ZoomableImage(url: item.url);
                  },
                ),
                // 前へボタン
                if (mediaItems.length > 1 && currentPage.value > 0)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _NavButton(
                        icon: Icons.chevron_left,
                        onTap: () => pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                      ),
                    ),
                  ),
                // 次へボタン
                if (mediaItems.length > 1 &&
                    currentPage.value < mediaItems.length - 1)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _NavButton(
                        icon: Icons.chevron_right,
                        onTap: () => pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                      ),
                    ),
                  ),
                // ページインジケーター（複数メディア時のみ表示）
                if (mediaItems.length > 1)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        mediaItems.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == currentPage.value ? 16 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == currentPage.value
                                ? Colors.white
                                : Colors.white38,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 下部パネル（情報 + いいね + コメント）
          Expanded(
            flex: 4,
            child: Container(
              color: const Color(0xFF162F4E),
              child: Column(
                children: [
                  // 投稿情報 + いいねボタン
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.carMaker,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    post.carModel +
                                        (post.carVariant != null &&
                                                post.carVariant!.isNotEmpty
                                            ? '  ${post.carVariant}'
                                            : ''),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // いいねボタン
                            likeState.when(
                              loading: () => const Padding(
                                padding: EdgeInsets.all(8),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                              error: (_, __) => const SizedBox.shrink(),
                              data: (status) => GestureDetector(
                                onTap: () {
                                  if (!isLoggedIn) {
                                    requireLogin();
                                    return;
                                  }
                                  ref
                                      .read(
                                        likeNotifierProvider(post.id).notifier,
                                      )
                                      .toggle();
                                },
                                child: Column(
                                  children: [
                                    Icon(
                                      status.liked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: status.liked
                                          ? Colors.redAccent
                                          : Colors.white60,
                                      size: 28,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${status.count}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (post.description != null &&
                            post.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              post.description!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                        // タグ
                        if (post.tags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: post.tags
                                  .map(
                                    (tag) => Text(
                                      '#$tag',
                                      style: const TextStyle(
                                        color: Color(0xFF90CAF9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 13,
                                color: Colors.white38,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '@${post.userId}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                dateFormat.format(post.createdAt),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white12, height: 16),

                  // コメント一覧
                  Expanded(
                    child: commentsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: Colors.white38),
                      ),
                      error: (_, __) => const Center(
                        child: Text(
                          'コメントを読み込めませんでした',
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
                      data: (comments) => comments.isEmpty
                          ? const Center(
                              child: Text(
                                'まだコメントはありません',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: comments.length,
                              itemBuilder: (_, i) => _CommentTile(
                                comment: comments[i],
                                currentUserId: authState.userId,
                                onDelete: () => deleteComment(comments[i].id),
                              ),
                            ),
                    ),
                  ),

                  // コメント入力欄
                  Container(
                    color: const Color(0xFF0D1F35),
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 8,
                      top: 8,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: isLoggedIn
                                  ? 'コメントを入力...'
                                  : 'コメントするにはログインが必要です',
                              hintStyle: const TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: Colors.white10,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            enabled: isLoggedIn,
                            onTap: isLoggedIn ? null : requireLogin,
                            maxLines: 1,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => submitComment(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: isLoggedIn
                              ? (submitting.value ? null : submitComment)
                              : requireLogin,
                          icon: submitting.value
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white54,
                                  ),
                                )
                              : Icon(
                                  Icons.send,
                                  color: isLoggedIn
                                      ? Colors.lightBlueAccent
                                      : Colors.white24,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 左右ナビゲーションボタン
class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}

/// ズーム時のみパンを有効にし、PageView のスワイプを妨げない画像ウィジェット
class _ZoomableImage extends HookWidget {
  final String url;

  const _ZoomableImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final controller = useMemoized(() => TransformationController());
    final isZoomed = useState(false);

    useEffect(() {
      void listener() {
        isZoomed.value = controller.value.getMaxScaleOnAxis() > 1.01;
      }

      controller.addListener(listener);
      return () => controller.removeListener(listener);
    }, [controller]);

    return InteractiveViewer(
      transformationController: controller,
      panEnabled: isZoomed.value,
      minScale: 1.0,
      maxScale: 5.0,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, size: 64, color: Colors.white38),
              SizedBox(height: 12),
              Text('画像を読み込めませんでした', style: TextStyle(color: Colors.white54)),
            ],
          ),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                    : null,
                color: Colors.white54,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final String? currentUserId;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.currentUserId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MM/dd HH:mm');
    final isOwn = comment.userId == currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_circle, color: Colors.white38, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '@${comment.userId}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      fmt.format(comment.createdAt),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.body,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (isOwn)
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.only(left: 4, top: 2),
                child: Icon(Icons.close, color: Colors.white38, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}
