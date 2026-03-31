import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:car_library/features/post/providers/post_provider.dart';
import 'package:car_library/features/post/models/post.dart';
import 'package:car_library/features/post/screens/masking_preview_screen.dart';
import 'package:car_library/features/auth/providers/auth_provider.dart';
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

    final makerController = useTextEditingController();
    final modelController = useTextEditingController();
    final variantController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final enableMasking = useState(true); // デフォルトでマスキング有効
    final maskingRects = useState<List<MaskingRect>>([]);

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
          if (enableMasking.value) {
            try {
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

      if (makerController.text.isEmpty || modelController.text.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('メーカーと車種名を入力してください')));
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
        // そうでない場合はenableMaskingフラグに従う
        final hasManualRects = maskingRects.value.isNotEmpty;

        final uploadResult = await apiService.uploadImage(
          imageBytes.value!,
          selectedImage.value!.name,
          enableMasking: hasManualRects ? false : enableMasking.value,
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
        final request = CreatePostRequest(
          userId: authState.userId!,
          carMaker: makerController.text,
          carModel: modelController.text,
          carVariant: variantController.text.isEmpty
              ? null
              : variantController.text,
          imageUrl: uploadResult.imageUrl,
          description: descriptionController.text.isEmpty
              ? null
              : descriptionController.text,
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
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
                  child: imageBytes.value != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            imageBytes.value!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                ),
              ),

              // マスキング調整ボタン
              if (imageBytes.value != null && enableMasking.value)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: OutlinedButton.icon(
                    onPressed: openMaskingPreview,
                    icon: const Icon(Icons.edit),
                    label: Text('マスキングを調整 (${maskingRects.value.length}個の領域)'),
                  ),
                ),

              const SizedBox(height: 24),

              // メーカー入力
              TextField(
                controller: makerController,
                decoration: const InputDecoration(
                  labelText: 'メーカー *',
                  hintText: '例: トヨタ、ホンダ',
                  border: OutlineInputBorder(),
                ),
                enabled: !isUploading.value,
              ),

              const SizedBox(height: 16),

              // 車種名入力
              TextField(
                controller: modelController,
                decoration: const InputDecoration(
                  labelText: '車種名 *',
                  hintText: '例: プリウス、シビック',
                  border: OutlineInputBorder(),
                ),
                enabled: !isUploading.value,
              ),

              const SizedBox(height: 16),

              // 型式入力
              TextField(
                controller: variantController,
                decoration: const InputDecoration(
                  labelText: '型式',
                  hintText: '例: ZVW50、FK7',
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

              // AIマスキングチェックボックス
              CheckboxListTile(
                title: const Text('ナンバープレート自動マスキング'),
                subtitle: const Text('AI が自動でナンバープレートを検出してマスキングします（試験的機能）'),
                value: enableMasking.value,
                onChanged: isUploading.value
                    ? null
                    : (value) {
                        enableMasking.value = value ?? false;
                      },
                contentPadding: EdgeInsets.zero,
              ),

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
    );
  }
}
