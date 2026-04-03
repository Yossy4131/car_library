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
import 'package:car_library/shared/widgets/vehicle_form_fields.dart';

/// 新規投稿作成画面
class CreatePostScreen extends HookConsumerWidget {
  const CreatePostScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picker = useMemoized(() => ImagePicker());
    final selectedImage = useState<XFile?>(null);
    final imageBytes = useState<Uint8List?>(null);
    final selectedVideo = useState<XFile?>(null);
    final videoBytes = useState<Uint8List?>(null);
    final isVideoMode = useState(false);
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

    // 動画選択処理
    Future<void> pickVideo() async {
      try {
        final XFile? video = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 3),
        );
        if (video != null) {
          final bytes = await video.readAsBytes();
          const maxSizeBytes = 100 * 1024 * 1024; // 100MB
          if (bytes.length > maxSizeBytes) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('動画ファイルは100MB以下にしてください')),
              );
            }
            return;
          }
          selectedVideo.value = video;
          videoBytes.value = bytes;
          // 画像選択をリセット
          selectedImage.value = null;
          imageBytes.value = null;
          maskingRects.value = [];
          isVideoMode.value = true;
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('動画の選択に失敗しました: $e')));
        }
      }
    }

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

          // 動画選択をリセット
          selectedVideo.value = null;
          videoBytes.value = null;
          isVideoMode.value = false;

          // 新しい画像を選択したら、前のマスキング領域をクリア
          maskingRects.value = [];

          // AI検出を実行してからプレビュー画面を開く
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
      if (!isVideoMode.value &&
          (selectedImage.value == null || imageBytes.value == null)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('画像または動画を選択してください')));
        return;
      }
      if (isVideoMode.value &&
          (selectedVideo.value == null || videoBytes.value == null)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('動画を選択してください')));
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

        // 1. メディアをアップロード
        String mediaImageUrl = '';
        String? mediaVideoUrl;
        bool uploadedMasked = false;
        int uploadedDetectedCount = 0;

        if (isVideoMode.value) {
          // 動画アップロード（マスキングなし）
          final videoResult = await apiService.uploadVideo(
            videoBytes.value!,
            selectedVideo.value!.name,
          );
          mediaVideoUrl = videoResult.videoUrl;
        } else {
          // 画像アップロード（マスキングあり）
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
          mediaImageUrl = uploadResult.imageUrl;
          uploadedMasked = uploadResult.masked;
          uploadedDetectedCount = uploadResult.detectedCount;
        }

        // 2. 投稿を作成
        final request = CreatePostRequest(
          userId: authState.userId!,
          carMaker: maker,
          carModel: model,
          carVariant: variantController.text.isEmpty
              ? null
              : variantController.text,
          imageUrl: mediaImageUrl,
          videoUrl: mediaVideoUrl,
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
          final message = isVideoMode.value
              ? '動画投稿が完了しました！'
              : (uploadedMasked && uploadedDetectedCount > 0
                    ? '投稿が完了しました！（ナンバープレート $uploadedDetectedCount 箇所を検出）'
                    : '投稿が完了しました！');

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
                  // メディアプレビュー＆選択（画像 or 動画）
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => SafeArea(
                          child: Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.photo_camera),
                                title: const Text('カメラで撮影（画像）'),
                                onTap: () {
                                  Navigator.pop(context);
                                  pickImage(ImageSource.camera);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: const Text('ギャラリーから画像を選択'),
                                onTap: () {
                                  Navigator.pop(context);
                                  pickImage(ImageSource.gallery);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.videocam),
                                title: const Text('ギャラリーから動画を選択'),
                                onTap: () {
                                  Navigator.pop(context);
                                  pickVideo();
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
                          if (isVideoMode.value && selectedVideo.value != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox.expand(
                                child: Container(
                                  color: Colors.black87,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.videocam,
                                        size: 64,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        selectedVideo.value!.name,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${(videoBytes.value!.length / 1024 / 1024).toStringAsFixed(1)} MB',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else if (imageBytes.value != null)
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
                                  'タップして画像または動画を選択',
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

                  // マスキング調整ボタン（画像選択時のみ表示）
                  if (imageBytes.value != null && !isVideoMode.value)
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
                  NhtsaMakerField(
                    nhtsaMakersAsync: nhtsaMakersAsync,
                    selectedMaker: selectedMaker,
                    selectedModel: selectedModel,
                    makerFreeText: makerFreeText,
                    modelFreeText: modelFreeText,
                    enabled: !isUploading.value,
                    initialValue: myCar.maker,
                  ),

                  const SizedBox(height: 16),

                  // 車種名選択（NHTSA Autocomplete）
                  NhtsaModelField(
                    nhtsaModelsAsync: nhtsaModelsAsync,
                    selectedMaker: selectedMaker,
                    selectedModel: selectedModel,
                    modelFreeText: modelFreeText,
                    enabled: !isUploading.value,
                    initialValue: myCar.model,
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
                  TagInputField(
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
