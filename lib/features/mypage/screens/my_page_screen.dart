import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:car_library/features/post/models/post.dart';
import 'package:car_library/features/post/providers/post_provider.dart';
import 'package:car_library/features/post/screens/post_detail_screen.dart';
import 'package:car_library/features/auth/providers/auth_provider.dart';
import 'package:car_library/features/car_master/providers/nhtsa_provider.dart';
import 'package:intl/intl.dart';

/// マイページ画面 — 自分の投稿一覧・削除・備考編集
class MyPageScreen extends HookConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final myPostsAsync = ref.watch(myPostsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          authState.userId != null ? '${authState.userId} のマイページ' : 'マイページ',
        ),
        elevation: 2,
      ),
      body: myPostsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
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
                onPressed: () => ref.invalidate(myPostsProvider),
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
                  const Text('写真を投稿して車を紹介しましょう！'),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final int crossAxisCount = width < 600
                  ? 1
                  : width < 1200
                  ? 2
                  : 3;
              const double spacing = 8.0;

              if (crossAxisCount == 1) {
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(myPostsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(spacing),
                    itemCount: posts.length,
                    itemBuilder: (_, index) => _MyPostCard(post: posts[index]),
                  ),
                );
              }

              final itemWidth =
                  (width - spacing * (crossAxisCount + 1)) / crossAxisCount;
              final mainAxisExtent = itemWidth * 9 / 16 + 200;

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(myPostsProvider),
                child: GridView.builder(
                  padding: const EdgeInsets.all(spacing),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    mainAxisExtent: mainAxisExtent,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (_, index) => _MyPostCard(post: posts[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// マイページ専用の投稿カード（削除・備考編集機能付き）
class _MyPostCard extends HookConsumerWidget {
  final Post post;
  const _MyPostCard({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 画像（タップで詳細へ）
          AspectRatio(
            aspectRatio: 16 / 9,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                child: Image.network(
                  post.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 64,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.grey[300],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 車両情報
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 車両名 + アクションボタン
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        post.displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // 編集ボタン
                    IconButton(
                      onPressed: () => _showEditDialog(context, ref, post),
                      icon: const Icon(Icons.edit_note),
                      tooltip: '編集',
                    ),
                    // 削除ボタン
                    IconButton(
                      onPressed: () => _confirmDelete(context, ref, post),
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red,
                      tooltip: '投稿を削除',
                    ),
                  ],
                ),

                // 備考
                if (post.description != null &&
                    post.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          post.description!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    '備考なし',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // 投稿日時
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      dateFormat.format(post.createdAt),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // いいね数・コメント数
                Row(
                  children: [
                    const Icon(
                      Icons.favorite,
                      size: 16,
                      color: Color(0xFFE57373),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post.likesCount}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
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
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: post.tags
                        .map(
                          (tag) => Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: 12,
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
    );
  }

  // 編集ダイアログ（メーカー・車種・型式・説明）
  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => _EditPostDialog(post: post),
    );

    if (result == null || !context.mounted) return;

    final ok = await ref
        .read(postControllerProvider.notifier)
        .updatePost(
          post.id,
          carMaker: result['carMaker'] as String?,
          carModel: result['carModel'] as String?,
          carVariant: result['carVariant'] as String?,
          description: result['description'] as String?,
          tags: result['tags'] as List<String>?,
        );

    if (!context.mounted) return;

    if (ok) {
      ref.invalidate(myPostsProvider);
      ref.invalidate(postsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿を更新しました')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('更新に失敗しました')));
    }
  }

  // 削除確認ダイアログ
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('投稿を削除'),
        content: const Text('この投稿を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ok = await ref
        .read(postControllerProvider.notifier)
        .deletePost(post.id);

    if (!context.mounted) return;

    if (ok) {
      ref.invalidate(myPostsProvider);
      ref.invalidate(postsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿を削除しました')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿の削除に失敗しました')));
    }
  }
}

// ============================================================
// 編集ダイアログ（NHTSAオートコンプリート付き）
// ============================================================

class _EditPostDialog extends HookConsumerWidget {
  final Post post;
  const _EditPostDialog({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMaker = useState<String?>(post.carMaker);
    final selectedModel = useState<String?>(post.carModel);
    final makerFreeText = useState<String>(post.carMaker);
    final modelFreeText = useState<String>(post.carModel);
    final variantController = useTextEditingController(
      text: post.carVariant ?? '',
    );
    final descriptionController = useTextEditingController(
      text: post.description ?? '',
    );
    final tagInputController = useTextEditingController();
    final tags = useState<List<String>>(List<String>.from(post.tags));

    final nhtsaMakersAsync = ref.watch(nhtsaMakersProvider);
    final nhtsaModelsAsync =
        selectedMaker.value != null && selectedMaker.value!.isNotEmpty
        ? ref.watch(nhtsaModelsProvider(selectedMaker.value!))
        : const AsyncValue<List<String>>.data([]);

    return AlertDialog(
      title: const Text('投稿を編集'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // メーカーオートコンプリート
              _buildMakerField(
                nhtsaMakersAsync: nhtsaMakersAsync,
                selectedMaker: selectedMaker,
                selectedModel: selectedModel,
                makerFreeText: makerFreeText,
                modelFreeText: modelFreeText,
              ),
              const SizedBox(height: 16),
              // 車種名オートコンプリート
              _buildModelField(
                nhtsaModelsAsync: nhtsaModelsAsync,
                selectedMaker: selectedMaker,
                selectedModel: selectedModel,
                modelFreeText: modelFreeText,
              ),
              const SizedBox(height: 16),
              // 型式
              TextField(
                controller: variantController,
                decoration: const InputDecoration(
                  labelText: '型式（任意）',
                  hintText: '例: ZVW50、FK7',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // 説明
              TextField(
                controller: descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '説明・コメント',
                  hintText: 'この車について教えてください',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // タグ入力
              _TagEditField(
                controller: tagInputController,
                tags: tags.value,
                onAddTag: (tag) {
                  final normalized = tag.toLowerCase().trim().replaceAll(
                    RegExp(r'^#+'),
                    '',
                  );
                  if (normalized.isNotEmpty &&
                      !tags.value.contains(normalized) &&
                      tags.value.length < 10) {
                    tags.value = [...tags.value, normalized];
                  }
                  tagInputController.clear();
                },
                onRemoveTag: (tag) {
                  tags.value = tags.value.where((t) => t != tag).toList();
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            final maker = (selectedMaker.value ?? makerFreeText.value).trim();
            final model = (selectedModel.value ?? modelFreeText.value).trim();
            Navigator.of(context).pop(<String, dynamic>{
              'carMaker': maker.isEmpty ? post.carMaker : maker,
              'carModel': model.isEmpty ? post.carModel : model,
              'carVariant': variantController.text.trim().isEmpty
                  ? null
                  : variantController.text.trim(),
              'description': descriptionController.text.trim().isEmpty
                  ? null
                  : descriptionController.text.trim(),
              'tags': tags.value,
            });
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

// メーカー選択フィールド
Widget _buildMakerField({
  required AsyncValue<List<String>> nhtsaMakersAsync,
  required ValueNotifier<String?> selectedMaker,
  required ValueNotifier<String?> selectedModel,
  required ValueNotifier<String> makerFreeText,
  required ValueNotifier<String> modelFreeText,
}) {
  return nhtsaMakersAsync.when(
    loading: () => const TextField(
      decoration: InputDecoration(
        labelText: 'メーカー *',
        hintText: 'メーカー一覧を読み込み中...',
        border: OutlineInputBorder(),
        suffixIcon: Padding(
          padding: EdgeInsets.all(12.0),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      enabled: false,
    ),
    error: (e, _) => TextField(
      decoration: const InputDecoration(
        labelText: 'メーカー *',
        hintText: '例: TOYOTA, HONDA（手動入力）',
        border: OutlineInputBorder(),
        helperText: 'APIが利用できません。直接入力してください',
      ),
      onChanged: (v) {
        makerFreeText.value = v;
        selectedMaker.value = null;
        selectedModel.value = null;
        modelFreeText.value = '';
      },
    ),
    data: (makers) => Autocomplete<String>(
      initialValue: TextEditingValue(text: makerFreeText.value),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim();
        if (query.isEmpty) return const Iterable<String>.empty();
        final lower = query.toLowerCase();
        return makers.where((m) => m.toLowerCase().contains(lower)).take(10);
      },
      onSelected: (value) {
        selectedMaker.value = value;
        makerFreeText.value = value;
        selectedModel.value = null;
        modelFreeText.value = '';
      },
      fieldViewBuilder: (ctx, controller, focusNode, onSubmit) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'メーカー *',
            hintText: 'メーカー名を入力して検索',
            border: OutlineInputBorder(),
            helperText: '例: TOYOTA, HONDA, NISSAN',
          ),
          onChanged: (v) {
            makerFreeText.value = v;
            if (selectedMaker.value != null && v != selectedMaker.value) {
              selectedMaker.value = null;
              selectedModel.value = null;
              modelFreeText.value = '';
            }
          },
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (ctx, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    ),
  );
}

// 車種名選択フィールド
Widget _buildModelField({
  required AsyncValue<List<String>> nhtsaModelsAsync,
  required ValueNotifier<String?> selectedMaker,
  required ValueNotifier<String?> selectedModel,
  required ValueNotifier<String> modelFreeText,
}) {
  final hasMaker =
      selectedMaker.value != null && selectedMaker.value!.isNotEmpty;

  if (!hasMaker) {
    return const TextField(
      decoration: InputDecoration(
        labelText: '車種名 *',
        hintText: '先にメーカーを選択してください',
        border: OutlineInputBorder(),
      ),
      enabled: false,
    );
  }

  return nhtsaModelsAsync.when(
    loading: () => const TextField(
      decoration: InputDecoration(
        labelText: '車種名 *',
        hintText: '車種一覧を読み込み中...',
        border: OutlineInputBorder(),
        suffixIcon: Padding(
          padding: EdgeInsets.all(12.0),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      enabled: false,
    ),
    error: (e, _) => TextField(
      decoration: const InputDecoration(
        labelText: '車種名 *',
        hintText: '例: Corolla, Civic（手動入力）',
        border: OutlineInputBorder(),
        helperText: 'APIが利用できません。直接入力してください',
      ),
      onChanged: (v) {
        modelFreeText.value = v;
        selectedModel.value = null;
      },
    ),
    data: (models) => Autocomplete<String>(
      key: ValueKey(selectedMaker.value),
      initialValue: TextEditingValue(text: modelFreeText.value),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim();
        if (query.isEmpty) return models.take(10);
        final lower = query.toLowerCase();
        return models.where((m) => m.toLowerCase().contains(lower)).take(10);
      },
      onSelected: (value) {
        selectedModel.value = value;
        modelFreeText.value = value;
      },
      fieldViewBuilder: (ctx, controller, focusNode, onSubmit) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: '車種名 *',
            hintText: '車種名を入力して検索',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            modelFreeText.value = v;
            if (selectedModel.value != null && v != selectedModel.value) {
              selectedModel.value = null;
            }
          },
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (ctx, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    ),
  );
}

// ────────────────────────────────────────────────────
// マイページ用タグ編集フィールド
// ────────────────────────────────────────────────────

class _TagEditField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> tags;
  final void Function(String tag) onAddTag;
  final void Function(String tag) onRemoveTag;

  const _TagEditField({
    required this.controller,
    required this.tags,
    required this.onAddTag,
    required this.onRemoveTag,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'ハッシュタグ',
            hintText: '例: スポーツカー（最大10個）',
            border: const OutlineInputBorder(),
            helperText: '入力してEnterで追加。# は自動で付きます。',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                final v = controller.text.trim();
                if (v.isNotEmpty) onAddTag(v);
              },
            ),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) onAddTag(v.trim());
          },
          onChanged: (v) {
            if (v.endsWith(' ') || v.endsWith('　')) {
              final trimmed = v.trim();
              if (trimmed.isNotEmpty) onAddTag(trimmed);
            }
          },
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: tags
                .map(
                  (tag) => Chip(
                    label: Text('#$tag'),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => onRemoveTag(tag),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
