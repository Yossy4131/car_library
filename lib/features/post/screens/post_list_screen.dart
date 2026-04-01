import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:car_library/features/post/providers/post_provider.dart';
import 'package:car_library/features/post/widgets/post_card.dart';
import 'package:car_library/features/post/screens/create_post_screen.dart';
import 'package:car_library/features/auth/providers/auth_provider.dart';
import 'package:car_library/features/auth/screens/login_screen.dart';
import 'package:car_library/features/mypage/screens/my_page_screen.dart';

/// 投稿一覧画面
class PostListScreen extends HookConsumerWidget {
  const PostListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 投稿一覧を取得
    final postsAsync = ref.watch(postsProvider(const PostsQueryParams()));
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/app_icon.png',
              width: 32,
              height: 32,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(width: 8),
            Text(
              'Car Lovers',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          if (authState.isAuthenticated)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'mypage') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyPageScreen()),
                  );
                } else if (value == 'logout') {
                  await ref.read(authProvider.notifier).signOut();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'mypage',
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Color(0xFF162F4E)),
                      SizedBox(width: 8),
                      Text('マイページ'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Color(0xFF162F4E)),
                      SizedBox(width: 8),
                      Text('ログアウト'),
                    ],
                  ),
                ),
              ],
              icon: const Icon(Icons.account_circle),
            )
          else
            TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              child: const Text('ログイン', style: TextStyle(color: Colors.white)),
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: フィルター機能の実装
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('フィルター機能は今後実装予定です')));
            },
          ),
        ],
      ),
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('エラーが発生しました', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(postsProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('再読み込み'),
              ),
            ],
          ),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.directions_car,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'まだ投稿がありません',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('最初の投稿をしてみましょう！'),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              // ブレークポイント: ~600px = 1列, ~1200px = 2列, 1200px~ = 3列
              final int crossAxisCount = width < 600
                  ? 1
                  : width < 1200
                  ? 2
                  : 3;
              const double spacing = 8.0;

              // モバイル: 現状維持（ListView）
              if (crossAxisCount == 1) {
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(postsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(spacing),
                    itemCount: posts.length,
                    itemBuilder: (_, index) => PostCard(post: posts[index]),
                  ),
                );
              }

              // タブレット/PC: グリッドレイアウト
              // カード高さ = 画像(16:9) + テキストエリア
              final itemWidth =
                  (width - spacing * (crossAxisCount + 1)) / crossAxisCount;
              final mainAxisExtent = itemWidth * 9 / 16 + 160;

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(postsProvider),
                child: GridView.builder(
                  padding: const EdgeInsets.all(spacing),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    mainAxisExtent: mainAxisExtent,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (_, index) => PostCard(post: posts[index]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (!authState.isAuthenticated) {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
        },
        icon: const Icon(Icons.add_a_photo),
        label: const Text('投稿する'),
      ),
    );
  }
}
