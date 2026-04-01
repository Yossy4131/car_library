import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:car_library/features/post/models/post.dart';
import 'package:car_library/features/post/providers/post_provider.dart';
import 'package:car_library/features/post/screens/post_detail_screen.dart';
import 'package:intl/intl.dart';

/// 投稿カードウィジェット
class PostCard extends ConsumerWidget {
  final Post post;
  final bool canDelete;
  final VoidCallback? onDelete;

  const PostCard({
    super.key,
    required this.post,
    this.canDelete = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('yyyy/MM/dd');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
          );
          ref.invalidate(postsProvider);
          ref.invalidate(myPostsProvider);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 画像 + グラデーションオーバーレイ
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    post.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFE8EAF6),
                      child: const Center(
                        child: Icon(
                          Icons.directions_car,
                          size: 48,
                          color: Color(0xFF9FA8DA),
                        ),
                      ),
                    ),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: const Color(0xFFE8EAF6),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                : null,
                            color: const Color(0xFF162F4E),
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                  ),
                  // 下部グラデーション
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 56,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x88000000)],
                        ),
                      ),
                    ),
                  ),
                  // 削除ボタン
                  if (canDelete && onDelete != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: onDelete,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // 投稿日時（画像下部）
                  Positioned(
                    right: 10,
                    bottom: 8,
                    child: Text(
                      dateFormat.format(post.createdAt),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // テキストエリア
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // メーカーChip
                  Chip(
                    label: Text(post.carMaker),
                    avatar: const Icon(
                      Icons.directions_car,
                      size: 14,
                      color: Color(0xFF162F4E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 車種名 + 型式
                  Text(
                    post.carModel +
                        (post.carVariant != null && post.carVariant!.isNotEmpty
                            ? '  ${post.carVariant}'
                            : ''),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // 説明
                  if (post.description != null &&
                      post.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      post.description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // いいね数・コメント数
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.favorite,
                        size: 15,
                        color: Color(0xFFE57373),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${post.likesCount}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 15,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${post.commentsCount}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  // タグ
                  if (post.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: post.tags
                          .take(5)
                          .map(
                            (tag) => Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF162F4E).withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
