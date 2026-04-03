import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:car_library/features/post/providers/post_provider.dart';
import 'package:car_library/features/post/models/post.dart';
import 'package:car_library/features/post/screens/masking_preview_screen.dart';
import 'package:car_library/features/auth/providers/auth_provider.dart';
import 'package:car_library/features/car_master/providers/nhtsa_provider.dart';
import 'package:car_library/features/mypage/providers/my_car_provider.dart';
import 'package:car_library/shared/services/api_service.dart';
import 'package:car_library/shared/providers/api_service_provider.dart';

/// 新規投稿作成画面
class CreatePostScreen extends HookConsumerWidget {
  const CreatePostScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picker = useMemoized(() => ImagePicker());
    final selectedImage = useState<XFile?>(null);
    final imageBytes = useState<Uint8List?>(null);
    final isUploading = useState(false);

    // NHTSA 選択状態
    final selectedMaker = useState<String?>(null);
    final selectedModel = useState<String?>(null);
    // フリーテキストフォールバック用
    final makerFreeText = useState('');
    final modelFreeText = useState('');

    final variantController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final tagInputController = useTextEditingController();
    final tags = useState<List<String>>([]);
    final maskingRects = useState<List<MaskingRect>>([]);
    final isDetecting = useState(false);

    // マイカー情報で初期値をセット（初回マウント時のみ）
    final myCar = ref.read(myCarProvider);
    useEffect(() {
      if (myCar.hasData) {
        selectedMaker.value = myCar.maker;
        makerFreeText.value = myCar.maker ?? '';
        selectedModel.value = myCar.model;
        modelFreeText.value = myCar.model ?? '';
        if (myCar.variant != null && myCar.variant!.isNotEmpty) {
          variantController.text = myCar.variant!;
        }
      }
      return null;
    }, const []);

    // NHTSA プロバイダー
    final nhtsaMakersAsync = ref.watch(nhtsaMakersProvider);
    final nhtsaModelsAsync = selectedMaker.value != null
        ? ref.watch(nhtsaModelsProvider(selectedMaker.value!))
        : const AsyncValue<List<String>>.data([]);

    // マスキングプレビュー画面を開く
    Future<void> openMaskingPreview() async {
      if (imageBytes.value == null) return;

      if (context.mounted) {
        // maskingRects.value にはピクセル座標が入っているので、そのまま渡す
        // プレビュー画面側で表示座標に変換して使用し、確定時にピクセル座標に変換して返す
        final result = await Navigator.push<List<MaskingRect>>(
          context,
          MaterialPageRoute(
            builder: (context) => MaskingPreviewScreen(
              imageBytes: imageBytes.value!,
              detectedRects: maskingRects.value, // ピクセル座標系
            ),
          ),
        );

        if (result != null) {
          // 確定時に返されるのはピクセル座標
          maskingRects.value = result;
        }
      }
    }

    // 画像選択処理
    Future<void> pickImage(ImageSource source) async {
      try {
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (image != null) {
          selectedImage.value = image;
          final bytes = await image.readAsBytes();
          imageBytes.value = bytes;

          // 新しい画像を選択したら、前のマスキング領域をクリア
          maskingRects.value = [];

          // マスキング有効時はAI検出を実行してから、プレビュー画面を開く
          if (true) {
            try {
              isDetecting.value = true;
              final apiService = ref.read(apiServiceProvider);
              // AI検出を実行
              final detectedBoxes = await apiService.detectLicensePlates(
                bytes,
                image.name,
              );

              // 検出結果をピクセル座標として保存
              maskingRects.value = detectedBoxes
                  .map(
                    (box) => MaskingRect(
                      x: box.x,
                      y: box.y,
                      width: box.width,
                      height: box.height,
                    ),
                  )
                  .toList();

              isDetecting.value = false;
              if (context.mounted) {
                // 検出結果を表示
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${detectedBoxes.length}個の領域を検出しました'),
                    duration: const Duration(seconds: 2),
                  ),
                );

                // プレビュー画面を開く
                await openMaskingPreview();
              }
            } catch (e) {
              isDetecting.value = false;
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('AI検出に失敗しました: $e')));
              }
            }
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('画像の選択に失敗しました: $e')));
        }
      }
    }

    // 投稿処理
    Future<void> submitPost() async {
      if (selectedImage.value == null || imageBytes.value == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('画像を選択してください')));
        return;
      }

      final maker = (selectedMaker.value ?? makerFreeText.value).trim();
      final model = (selectedModel.value ?? modelFreeText.value).trim();

      if (maker.isEmpty || model.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('メーカーと車種名を選択または入力してください')));
        return;
      }

      isUploading.value = true;

      try {
        final apiService = ref.read(apiServiceProvider);
        final authState = ref.read(authProvider);
        if (!authState.isAuthenticated || authState.userId == null) {
          throw Exception('サインインが必要です');
        }

        // 1. 画像をアップロード
        // 手動マスキング領域がある場合はそれを優先（AI検出を無効化）
        final hasManualRects = maskingRects.value.isNotEmpty;

        final uploadResult = await apiService.uploadImage(
          imageBytes.value!,
          selectedImage.value!.name,
          enableMasking: hasManualRects ? false : true,
          maskingRects: hasManualRects
              ? maskingRects.value
                    .map(
                      (rect) => MaskingBox(
                        x: rect.x,
                        y: rect.y,
                        width: rect.width,
                        height: rect.height,
                      ),
                    )
                    .toList()
              : null,
        );

        // 2. 投稿を作成
        final maker = (selectedMaker.value ?? makerFreeText.value).trim();
        final model = (selectedModel.value ?? modelFreeText.value).trim();
        final request = CreatePostRequest(
          userId: authState.userId!,
          carMaker: maker,
          carModel: model,
          carVariant: variantController.text.isEmpty
              ? null
              : variantController.text,
          imageUrl: uploadResult.imageUrl,
          description: descriptionController.text.isEmpty
              ? null
              : descriptionController.text,
          tags: tags.value,
        );

        final postController = ref.read(postControllerProvider.notifier);
        final postId = await postController.createPost(request);

        if (postId != null && context.mounted) {
          // 投稿一覧を更新
          ref.invalidate(postsProvider);

          Navigator.of(context).pop();

          // マスキング結果を通知
          final message = uploadResult.masked && uploadResult.detectedCount > 0
              ? '投稿が完了しました！（ナンバープレート ${uploadResult.detectedCount} 箇所を検出）'
              : '投稿が完了しました！';

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('投稿に失敗しました: $e')));
        }
      } finally {
        isUploading.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('新規投稿'),
        actions: [
          if (isUploading.value)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: submitPost,
              child: const Text(
                '投稿',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 画像プレビュー＆選択
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => SafeArea(
                          child: Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.photo_camera),
                                title: const Text('カメラで撮影'),
                                onTap: () {
                                  Navigator.pop(context);
                                  pickImage(ImageSource.camera);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: const Text('ギャラリーから選択'),
                                onTap: () {
                                  Navigator.pop(context);
                                  pickImage(ImageSource.gallery);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 250,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[400]!),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (imageBytes.value != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox.expand(
                                child: Image.memory(
                                  imageBytes.value!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          else
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 64,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'タップして画像を選択',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  // マスキング調整ボタン
                  if (imageBytes.value != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: OutlinedButton.icon(
                        onPressed: openMaskingPreview,
                        icon: const Icon(Icons.edit),
                        label: Text(
                          'マスキングを調整 (${maskingRects.value.length}個の領域)',
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // メーカー選択（NHTSA Autocomplete）
                  _buildMakerField(
                    nhtsaMakersAsync: nhtsaMakersAsync,
                    selectedMaker: selectedMaker,
                    selectedModel: selectedModel,
                    makerFreeText: makerFreeText,
                    modelFreeText: modelFreeText,
                    isUploading: isUploading.value,
                    initialMaker: myCar.maker,
                  ),

                  const SizedBox(height: 16),

                  // 車種名選択（NHTSA Autocomplete）
                  _buildModelField(
                    nhtsaModelsAsync: nhtsaModelsAsync,
                    selectedMaker: selectedMaker,
                    selectedModel: selectedModel,
                    modelFreeText: modelFreeText,
                    isUploading: isUploading.value,
                    initialModel: myCar.model,
                  ),

                  const SizedBox(height: 16),

                  // 型式入力（フリーテキスト）
                  TextField(
                    controller: variantController,
                    decoration: const InputDecoration(
                      labelText: '型式',
                      hintText: '例: ZVW50、FK7（任意）',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !isUploading.value,
                  ),

                  const SizedBox(height: 16),

                  // 説明入力
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: '説明・コメント',
                      hintText: 'この車について教えてください',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    enabled: !isUploading.value,
                  ),

                  const SizedBox(height: 16),

                  // タグ入力
                  _TagInputField(
                    controller: tagInputController,
                    tags: tags.value,
                    enabled: !isUploading.value,
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

                  const SizedBox(height: 16),

                  const SizedBox(height: 24),

                  // 投稿ボタン（モバイル用）
                  ElevatedButton.icon(
                    onPressed: isUploading.value ? null : submitPost,
                    icon: isUploading.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(isUploading.value ? '投稿中...' : '投稿する'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isDetecting.value)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'ナンバープレートを検出中...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
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

// ────────────────────────────────────────────────────
// メーカー選択フィールド（NHTSA Autocomplete）
// ────────────────────────────────────────────────────

Widget _buildMakerField({
  required AsyncValue<List<String>> nhtsaMakersAsync,
  required ValueNotifier<String?> selectedMaker,
  required ValueNotifier<String?> selectedModel,
  required ValueNotifier<String> makerFreeText,
  required ValueNotifier<String> modelFreeText,
  required bool isUploading,
  String? initialMaker,
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
    error: (_, _) => TextField(
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
      enabled: !isUploading,
    ),
    data: (makers) => Autocomplete<String>(
      initialValue: TextEditingValue(text: initialMaker ?? makerFreeText.value),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim();
        if (query.isEmpty) return const Iterable<String>.empty();
        final lower = query.toLowerCase();
        return makers.where((m) => m.toLowerCase().contains(lower)).take(10);
      },
      onSelected: (value) {
        selectedMaker.value = value;
        makerFreeText.value = value;
        // メーカー変更時はモデル選択をリセット
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
          enabled: !isUploading,
          onChanged: (v) {
            makerFreeText.value = v;
            // ドロップダウン選択後に手動編集した場合は選択を無効化
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

// ────────────────────────────────────────────────────
// 車種名選択フィールド（NHTSA Autocomplete）
// ────────────────────────────────────────────────────

Widget _buildModelField({
  required AsyncValue<List<String>> nhtsaModelsAsync,
  required ValueNotifier<String?> selectedMaker,
  required ValueNotifier<String?> selectedModel,
  required ValueNotifier<String> modelFreeText,
  required bool isUploading,
  String? initialModel,
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
    error: (_, _) => TextField(
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
      enabled: !isUploading,
    ),
    data: (models) => Autocomplete<String>(
      key: ValueKey(selectedMaker.value), // メーカー変更でウィジェットをリセット
      initialValue: TextEditingValue(text: initialModel ?? modelFreeText.value),
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
          enabled: !isUploading,
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
// タグ入力フィールド
// ────────────────────────────────────────────────────

class _TagInputField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> tags;
  final bool enabled;
  final void Function(String tag) onAddTag;
  final void Function(String tag) onRemoveTag;

  const _TagInputField({
    required this.controller,
    required this.tags,
    required this.enabled,
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
          enabled: enabled,
          decoration: InputDecoration(
            labelText: 'ハッシュタグ',
            hintText: '例: スポーツカー（最大10個）',
            border: const OutlineInputBorder(),
            helperText: '入力してEnterで追加。# は自動で付きます。',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: enabled
                  ? () {
                      final v = controller.text.trim();
                      if (v.isNotEmpty) onAddTag(v);
                    }
                  : null,
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
