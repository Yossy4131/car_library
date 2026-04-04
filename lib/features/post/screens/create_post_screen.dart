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

/// メディアエントリー（画像または動画の一件）
class _MediaEntry {
  final XFile file;
  final Uint8List bytes;
  final bool isVideo;
  final List<MaskingRect> maskingRects;

  const _MediaEntry({
    required this.file,
    required this.bytes,
    required this.isVideo,
    this.maskingRects = const [],
  });

  _MediaEntry withMaskingRects(List<MaskingRect> rects) => _MediaEntry(
    file: file,
    bytes: bytes,
    isVideo: isVideo,
    maskingRects: rects,
  );
}

const _kMaxMediaCount = 10;

/// 新規投稿作成画面
class CreatePostScreen extends HookConsumerWidget {
  const CreatePostScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picker = useMemoized(() => ImagePicker());
    final mediaEntries = useState<List<_MediaEntry>>([]);
    final selectedIndex = useState(0);
    final isUploading = useState(false);
    final isDetecting = useState(false);

    // NHTSA 選択状態
    final selectedMaker = useState<String?>(null);
    final selectedModel = useState<String?>(null);
    final makerFreeText = useState('');
    final modelFreeText = useState('');

    final variantController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final tagInputController = useTextEditingController();
    final tags = useState<List<String>>([]);

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

    // 現在選択中のエントリー
    _MediaEntry? currentEntry() {
      final entries = mediaEntries.value;
      final idx = selectedIndex.value;
      return entries.isNotEmpty && idx < entries.length ? entries[idx] : null;
    }

    // マスキングプレビューを開く
    Future<void> openMaskingPreview(int index) async {
      final entries = mediaEntries.value;
      if (index >= entries.length || entries[index].isVideo) return;
      final entry = entries[index];
      if (!context.mounted) return;
      final result = await Navigator.push<List<MaskingRect>>(
        context,
        MaterialPageRoute(
          builder: (context) => MaskingPreviewScreen(
            imageBytes: entry.bytes,
            detectedRects: entry.maskingRects,
          ),
        ),
      );
      if (result != null) {
        final updated = List<_MediaEntry>.from(mediaEntries.value);
        updated[index] = entry.withMaskingRects(result);
        mediaEntries.value = updated;
      }
    }

    // 画像を追加
    Future<void> addImage(ImageSource source) async {
      if (mediaEntries.value.length >= _kMaxMediaCount) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('メディアは最大${_kMaxMediaCount}件まで追加できます')),
          );
        }
        return;
      }
      try {
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
        if (image == null) return;

        final bytes = await image.readAsBytes();

        // AI検出
        isDetecting.value = true;
        List<MaskingRect> rects = [];
        try {
          final apiService = ref.read(apiServiceProvider);
          final detectedBoxes = await apiService.detectLicensePlates(bytes, image.name);
          rects = detectedBoxes
              .map((box) => MaskingRect(x: box.x, y: box.y, width: box.width, height: box.height))
              .toList();
        } catch (_) {}
        isDetecting.value = false;

        final newEntry = _MediaEntry(file: image, bytes: bytes, isVideo: false, maskingRects: rects);
        final newList = List<_MediaEntry>.from(mediaEntries.value)..add(newEntry);
        mediaEntries.value = newList;
        final newIdx = newList.length - 1;
        selectedIndex.value = newIdx;

        if (context.mounted && rects.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${rects.length}個の領域を検出しました'),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // 自動でマスキングプレビューを開く
        if (context.mounted) {
          await openMaskingPreview(newIdx);
        }
      } catch (e) {
        isDetecting.value = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('画像の選択に失敗しました: $e')),
          );
        }
      }
    }

    // 動画を追加
    Future<void> addVideo() async {
      if (mediaEntries.value.length >= _kMaxMediaCount) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('メディアは最大${_kMaxMediaCount}件まで追加できます')),
          );
        }
        return;
      }
      try {
        final XFile? video = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 3),
        );
        if (video == null) return;

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

        final newEntry = _MediaEntry(file: video, bytes: bytes, isVideo: true);
        final newList = List<_MediaEntry>.from(mediaEntries.value)..add(newEntry);
        mediaEntries.value = newList;
        selectedIndex.value = newList.length - 1;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('動画の選択に失敗しました: $e')),
          );
        }
      }
    }

    // メディアを削除
    void removeMedia(int index) {
      final updated = List<_MediaEntry>.from(mediaEntries.value)..removeAt(index);
      mediaEntries.value = updated;
      if (updated.isEmpty) {
        selectedIndex.value = 0;
      } else if (selectedIndex.value >= updated.length) {
        selectedIndex.value = updated.length - 1;
      }
    }

    // メディア追加ボトムシート
    void showAddMediaSheet() {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('カメラで撮影（画像）'),
                onTap: () { Navigator.pop(ctx); addImage(ImageSource.camera); },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('ギャラリーから画像を選択'),
                onTap: () { Navigator.pop(ctx); addImage(ImageSource.gallery); },
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('ギャラリーから動画を選択'),
                onTap: () { Navigator.pop(ctx); addVideo(); },
              ),
            ],
          ),
        ),
      );
    }

    // 投稿処理
    Future<void> submitPost() async {
      if (mediaEntries.value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('画像または動画を選択してください')),
        );
        return;
      }

      final maker = (selectedMaker.value ?? makerFreeText.value).trim();
      final model = (selectedModel.value ?? modelFreeText.value).trim();
      if (maker.isEmpty || model.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メーカーと車種名を選択または入力してください')),
        );
        return;
      }

      isUploading.value = true;
      try {
        final apiService = ref.read(apiServiceProvider);
        final authState = ref.read(authProvider);
        if (!authState.isAuthenticated || authState.userId == null) {
          throw Exception('サインインが必要です');
        }

        // 各メディアを順番にアップロード
        final uploadedItems = <MediaItem>[];
        int totalDetected = 0;
        bool anyMasked = false;

        for (int i = 0; i < mediaEntries.value.length; i++) {
          final entry = mediaEntries.value[i];
          if (entry.isVideo) {
            final result = await apiService.uploadVideo(entry.bytes, entry.file.name);
            uploadedItems.add(MediaItem(url: result.videoUrl, type: 'video', sortOrder: i));
          } else {
            final hasManualRects = entry.maskingRects.isNotEmpty;
            final uploadResult = await apiService.uploadImage(
              entry.bytes,
              entry.file.name,
              enableMasking: !hasManualRects,
              maskingRects: hasManualRects
                  ? entry.maskingRects
                        .map((r) => MaskingBox(x: r.x, y: r.y, width: r.width, height: r.height))
                        .toList()
                  : null,
            );
            uploadedItems.add(MediaItem(
              url: uploadResult.imageUrl,
              type: 'image',
              originalUrl: uploadResult.originalImageUrl,
              sortOrder: i,
            ));
            totalDetected += uploadResult.detectedCount;
            if (uploadResult.masked) anyMasked = true;
          }
        }

        // 後方互換のため first item を imageUrl/videoUrl にもセット
        final firstItem = uploadedItems.first;
        final request = CreatePostRequest(
          userId: authState.userId!,
          carMaker: maker,
          carModel: model,
          carVariant: variantController.text.isEmpty ? null : variantController.text,
          imageUrl: firstItem.isVideo ? '' : firstItem.url,
          videoUrl: firstItem.isVideo ? firstItem.url : null,
          description: descriptionController.text.isEmpty ? null : descriptionController.text,
          tags: tags.value,
          mediaItems: uploadedItems,
        );

        final postController = ref.read(postControllerProvider.notifier);
        final postId = await postController.createPost(request);

        if (postId != null && context.mounted) {
          ref.invalidate(postsProvider);
          Navigator.of(context).pop();

          final mediaCount = uploadedItems.length;
          final hasVideo = uploadedItems.any((m) => m.isVideo);
          String message;
          if (hasVideo && mediaCount == 1) {
            message = '動画投稿が完了しました！';
          } else if (anyMasked && totalDetected > 0) {
            message = '投稿が完了しました（${mediaCount}件のメディア、ナンバープレート $totalDetected 箇所を検出）';
          } else {
            message = '投稿が完了しました（${mediaCount}件のメディア）';
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('投稿に失敗しました: $e')),
          );
        }
      } finally {
        isUploading.value = false;
      }
    }

    final curr = currentEntry();

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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
                  // メインプレビューエリア
                  GestureDetector(
                    onTap: mediaEntries.value.isEmpty ? showAddMediaSheet : null,
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
                          if (curr != null)
                            curr.isVideo
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox.expand(
                                      child: Container(
                                        color: Colors.black87,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.videocam, size: 64, color: Colors.white70),
                                            const SizedBox(height: 12),
                                            Text(
                                              curr.file.name,
                                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${(curr.bytes.length / 1024 / 1024).toStringAsFixed(1)} MB',
                                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox.expand(
                                      child: Image.memory(curr.bytes, fit: BoxFit.cover),
                                    ),
                                  )
                          else
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 64, color: Colors.grey[600]),
                                const SizedBox(height: 16),
                                Text(
                                  'タップして画像または動画を選択',
                                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          // ページ番号バッジ
                          if (mediaEntries.value.length > 1)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${selectedIndex.value + 1} / ${mediaEntries.value.length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // マスキング調整ボタン（現在選択中が画像の場合のみ）
                  if (curr != null && !curr.isVideo)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: OutlinedButton.icon(
                        onPressed: () => openMaskingPreview(selectedIndex.value),
                        icon: const Icon(Icons.edit),
                        label: Text('マスキングを調整 (${curr.maskingRects.length}個の領域)'),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // サムネイルストリップ（横スクロール）
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: mediaEntries.value.length +
                          (mediaEntries.value.length < _kMaxMediaCount ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        // 追加ボタン
                        if (index == mediaEntries.value.length) {
                          return GestureDetector(
                            onTap: showAddMediaSheet,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[400]!),
                              ),
                              child: Icon(Icons.add_photo_alternate, color: Colors.grey[600]),
                            ),
                          );
                        }
                        final entry = mediaEntries.value[index];
                        final isSelected = index == selectedIndex.value;
                        return GestureDetector(
                          onTap: () => selectedIndex.value = index,
                          child: Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: entry.isVideo
                                      ? Container(
                                          color: Colors.black87,
                                          child: const Center(
                                            child: Icon(Icons.videocam, color: Colors.white70, size: 32),
                                          ),
                                        )
                                      : Image.memory(entry.bytes, fit: BoxFit.cover),
                                ),
                              ),
                              // 削除ボタン
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => removeMedia(index),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // メーカー選択
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

                  // 車種名選択
                  NhtsaModelField(
                    nhtsaModelsAsync: nhtsaModelsAsync,
                    selectedMaker: selectedMaker,
                    selectedModel: selectedModel,
                    modelFreeText: modelFreeText,
                    enabled: !isUploading.value,
                    initialValue: myCar.model,
                  ),

                  const SizedBox(height: 16),

                  // 型式入力
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
                      final normalized = tag.toLowerCase().trim().replaceAll(RegExp(r'^#+'), '');
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

                  // 投稿ボタン
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
          // ナンバープレート検出中オーバーレイ
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
          // アップロード中オーバーレイ
          if (isUploading.value)
            Container(
              color: Colors.black38,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'メディアをアップロード中...',
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
