import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:car_library/features/post/providers/post_provider.dart';
import 'package:car_library/features/post/widgets/post_card.dart';
import 'package:car_library/features/post/screens/create_post_screen.dart';
import 'package:car_library/features/auth/providers/auth_provider.dart';
import 'package:car_library/features/auth/screens/login_screen.dart';
import 'package:car_library/features/mypage/screens/my_page_screen.dart'
    show MyPageScreen;
import 'package:car_library/features/car_master/providers/nhtsa_provider.dart';

/// 投稿一覧画面
class PostListScreen extends HookConsumerWidget {
  const PostListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterMaker = useState<String?>(null);
    final filterModel = useState<String?>(null);
    final filterTag = useState<String?>(null);

    // 投稿一覧を取得
    final postsAsync = ref.watch(
      postsProvider(
        PostsQueryParams(
          maker: filterMaker.value,
          model: filterModel.value,
          tag: filterTag.value,
        ),
      ),
    );
    final authState = ref.watch(authProvider);

    final hasFilter =
        filterMaker.value != null ||
        filterModel.value != null ||
        filterTag.value != null;

    Future<void> openSearchSheet() async {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _FilterSheet(
          initialMaker: filterMaker.value,
          initialModel: filterModel.value,
          initialTag: filterTag.value,
          onApply: (maker, model, tag) {
            filterMaker.value = maker;
            filterModel.value = model;
            filterTag.value = tag;
          },
        ),
      );
    }

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
            icon: Badge(
              isLabelVisible: hasFilter,
              child: const Icon(Icons.search),
            ),
            tooltip: '検索',
            onPressed: openSearchSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // 検索中バナー
          if (hasFilter)
            Container(
              color: const Color(0xFF162F4E).withOpacity(0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: Color(0xFF162F4E)),
                  const SizedBox(width: 6),
                  if (filterMaker.value != null)
                    Chip(
                      label: Text(filterMaker.value!),
                      onDeleted: () {
                        filterMaker.value = null;
                        filterModel.value = null;
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (filterMaker.value != null && filterModel.value != null)
                    const SizedBox(width: 6),
                  if (filterModel.value != null)
                    Chip(
                      label: Text(filterModel.value!),
                      onDeleted: () => filterModel.value = null,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (filterTag.value != null) ...[
                    const SizedBox(width: 6),
                    Chip(
                      label: Text('#${filterTag.value!}'),
                      avatar: const Icon(Icons.tag, size: 14),
                      onDeleted: () => filterTag.value = null,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      filterMaker.value = null;
                      filterModel.value = null;
                      filterTag.value = null;
                    },
                    child: const Text('クリア'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: postsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'エラーが発生しました',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
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
                          itemBuilder: (_, index) =>
                              PostCard(post: posts[index]),
                        ),
                      );
                    }

                    // タブレット/PC: グリッドレイアウト
                    // カード高さ = 画像(16:9) + テキストエリア
                    final itemWidth =
                        (width - spacing * (crossAxisCount + 1)) /
                        crossAxisCount;
                    final mainAxisExtent = itemWidth * 9 / 16 + 200;

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
          ),
        ],
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

/// 検索ボトムシート
class _FilterSheet extends HookConsumerWidget {
  final String? initialMaker;
  final String? initialModel;
  final String? initialTag;
  final void Function(String? maker, String? model, String? tag) onApply;

  const _FilterSheet({
    required this.initialMaker,
    required this.initialModel,
    required this.onApply,
    this.initialTag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMaker = useState<String?>(initialMaker);
    final selectedModel = useState<String?>(initialModel);
    final tagController = useTextEditingController(text: initialTag ?? '');
    final makerController = useTextEditingController(text: initialMaker ?? '');
    final modelController = useTextEditingController(text: initialModel ?? '');

    final makersAsync = ref.watch(nhtsaMakersProvider);
    final modelsAsync = selectedMaker.value != null
        ? ref.watch(nhtsaModelsProvider(selectedMaker.value!))
        : const AsyncValue<List<String>>.data([]);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ハンドル
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '検索',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),

            // メーカー選択
            makersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('メーカー取得に失敗しました'),
              data: (makers) => Autocomplete<String>(
                initialValue: TextEditingValue(text: initialMaker ?? ''),
                optionsBuilder: (value) {
                  if (value.text.isEmpty) return makers.take(50);
                  final q = value.text.toLowerCase();
                  return makers.where((m) => m.toLowerCase().contains(q));
                },
                onSelected: (maker) {
                  selectedMaker.value = maker;
                  selectedModel.value = null;
                  modelController.clear();
                },
                fieldViewBuilder: (_, ctrl, focusNode, onSubmit) {
                  makerController.text = ctrl.text;
                  return TextField(
                    controller: ctrl,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'メーカー',
                      hintText: 'Toyota, Honda...',
                      prefixIcon: Icon(Icons.business),
                    ),
                    onChanged: (v) {
                      if (v.isEmpty) {
                        selectedMaker.value = null;
                        selectedModel.value = null;
                        modelController.clear();
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 車種選択
            if (selectedMaker.value != null)
              modelsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('車種取得に失敗しました'),
                data: (models) => Autocomplete<String>(
                  initialValue: TextEditingValue(text: initialModel ?? ''),
                  optionsBuilder: (value) {
                    if (value.text.isEmpty) return models.take(50);
                    final q = value.text.toLowerCase();
                    return models.where((m) => m.toLowerCase().contains(q));
                  },
                  onSelected: (model) => selectedModel.value = model,
                  fieldViewBuilder: (_, ctrl, focusNode, onSubmit) {
                    return TextField(
                      controller: ctrl,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: '車種',
                        hintText: 'Corolla, Civic...',
                        prefixIcon: Icon(Icons.directions_car),
                      ),
                      onChanged: (v) {
                        if (v.isEmpty) selectedModel.value = null;
                      },
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            // タグ入力
            TextField(
              controller: tagController,
              decoration: const InputDecoration(
                labelText: 'ハッシュタグ',
                hintText: 'スポーツカー、改造車...',
                prefixIcon: Icon(Icons.tag),
                helperText: '# なしで入力してください',
              ),
            ),

            const SizedBox(height: 24),

            // 適用ボタン
            ElevatedButton(
              onPressed: () {
                final tagText = tagController.text.trim().replaceAll(
                  RegExp(r'^#+'),
                  '',
                );
                onApply(
                  selectedMaker.value,
                  selectedModel.value,
                  tagText.isEmpty ? null : tagText,
                );
                Navigator.pop(context);
              },
              child: const Text('この条件で検索する'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                onApply(null, null, null);
                Navigator.pop(context);
              },
              child: const Text('検索条件をリセット'),
            ),
          ],
        ),
      ),
    );
  }
}
