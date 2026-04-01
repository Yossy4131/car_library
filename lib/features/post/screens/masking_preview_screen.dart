import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// マスキング領域を手動調整するプレビュー画面
class MaskingPreviewScreen extends HookWidget {
  final Uint8List imageBytes;
  final List<MaskingRect> detectedRects;

  const MaskingPreviewScreen({
    super.key,
    required this.imageBytes,
    required this.detectedRects,
  });

  /// 画像をデコードして実際のサイズを取得
  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  Widget build(BuildContext context) {
    final maskingRects = useState<List<MaskingRect>>([]); // 表示座標系
    final selectedIndex = useState<int?>(null);
    final imageKey = useMemoized(() => GlobalKey());
    final naturalImageSize = useState<Size?>(null);
    final displayImageSize = useState<Size?>(null);
    final isInitialized = useState(false);

    // 画像の実際のサイズを取得
    useEffect(() {
      _decodeImage(imageBytes).then((image) {
        naturalImageSize.value = Size(
          image.width.toDouble(),
          image.height.toDouble(),
        );
      });
      return null;
    }, []);

    // 画像が表示されたら、ピクセル座標を表示座標に変換
    useEffect(() {
      if (naturalImageSize.value != null && !isInitialized.value) {
        // 次のフレームで表示サイズを取得
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = imageKey.currentContext;
          if (context != null) {
            final renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              displayImageSize.value = renderBox.size;

              // ピクセル座標を表示座標に変換
              final scaleX =
                  displayImageSize.value!.width / naturalImageSize.value!.width;
              final scaleY =
                  displayImageSize.value!.height /
                  naturalImageSize.value!.height;

              maskingRects.value = detectedRects.map((rect) {
                return MaskingRect(
                  x: rect.x * scaleX,
                  y: rect.y * scaleY,
                  width: rect.width * scaleX,
                  height: rect.height * scaleY,
                );
              }).toList();

              isInitialized.value = true;
            }
          }
        });
      }
      return null;
    }, [naturalImageSize.value]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('マスキング調整'),
        actions: [
          TextButton.icon(
            onPressed: () {
              // 新しい矩形を追加（画像中央に配置）
              final context = imageKey.currentContext;
              if (context != null) {
                final renderBox = context.findRenderObject() as RenderBox;
                final displaySize = renderBox.size;

                maskingRects.value = [
                  ...maskingRects.value,
                  MaskingRect(
                    x: (displaySize.width - 200) / 2,
                    y: (displaySize.height - 100) / 2,
                    width: 200,
                    height: 100,
                  ),
                ];
              } else {
                // Fallback
                maskingRects.value = [
                  ...maskingRects.value,
                  MaskingRect(x: 100, y: 100, width: 200, height: 100),
                ];
              }
            },
            icon: const Icon(Icons.add_box, color: Colors.white),
            label: const Text('領域追加', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {
              // 表示座標を元画像のピクセル座標に変換
              if (naturalImageSize.value != null) {
                final context = imageKey.currentContext;
                if (context != null) {
                  final renderBox = context.findRenderObject() as RenderBox;
                  final displaySize = renderBox.size;

                  final scaleX =
                      naturalImageSize.value!.width / displaySize.width;
                  final scaleY =
                      naturalImageSize.value!.height / displaySize.height;

                  // 座標を変換
                  final convertedRects = maskingRects.value.map((rect) {
                    return MaskingRect(
                      x: rect.x * scaleX,
                      y: rect.y * scaleY,
                      width: rect.width * scaleX,
                      height: rect.height * scaleY,
                    );
                  }).toList();

                  Navigator.pop(context, convertedRects);
                  return;
                }
              }

              // Fallback: 変換せずにそのまま返す
              Navigator.pop(context, maskingRects.value);
            },
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('確定', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // ヘルプテキスト
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'マスキング領域をドラッグで移動、角をドラッグでサイズ変更できます。不要な領域は選択してDeleteキーで削除できます。',
                    style: TextStyle(color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),

          // 画像とマスキング領域表示
          Expanded(
            child: InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return MaskingCanvas(
                      key: imageKey,
                      imageBytes: imageBytes,
                      maskingRects: maskingRects.value,
                      selectedIndex: selectedIndex.value,
                      onRectUpdated: (index, rect) {
                        final updated = List<MaskingRect>.from(
                          maskingRects.value,
                        );
                        updated[index] = rect;
                        maskingRects.value = updated;
                      },
                      onRectSelected: (index) {
                        selectedIndex.value = index;
                      },
                      onRectDeleted: (index) {
                        final updated = List<MaskingRect>.from(
                          maskingRects.value,
                        );
                        updated.removeAt(index);
                        maskingRects.value = updated;
                        selectedIndex.value = null;
                      },
                    );
                  },
                ),
              ),
            ),
          ),

          // コントロールパネル
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  'マスキング領域: ${maskingRects.value.length}個',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (selectedIndex.value != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      final updated = List<MaskingRect>.from(
                        maskingRects.value,
                      );
                      updated.removeAt(selectedIndex.value!);
                      maskingRects.value = updated;
                      selectedIndex.value = null;
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('削除'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// マスキング矩形データ
class MaskingRect {
  final double x;
  final double y;
  final double width;
  final double height;

  MaskingRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  MaskingRect copyWith({double? x, double? y, double? width, double? height}) {
    return MaskingRect(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

/// マスキング領域を表示・操作するCanvas
class MaskingCanvas extends StatelessWidget {
  final Uint8List imageBytes;
  final List<MaskingRect> maskingRects;
  final int? selectedIndex;
  final Function(int, MaskingRect) onRectUpdated;
  final Function(int) onRectSelected;
  final Function(int) onRectDeleted;

  const MaskingCanvas({
    super.key,
    required this.imageBytes,
    required this.maskingRects,
    required this.selectedIndex,
    required this.onRectUpdated,
    required this.onRectSelected,
    required this.onRectDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 元画像
        Image.memory(imageBytes),

        // マスキング矩形
        ...maskingRects.asMap().entries.map((entry) {
          final index = entry.key;
          final rect = entry.value;
          final isSelected = selectedIndex == index;

          return Positioned(
            left: rect.x,
            top: rect.y,
            child: GestureDetector(
              onTap: () => onRectSelected(index),
              onPanUpdate: (details) {
                onRectUpdated(
                  index,
                  rect.copyWith(
                    x: rect.x + details.delta.dx,
                    y: rect.y + details.delta.dy,
                  ),
                );
              },
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: rect.width,
                    height: rect.height,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.red,
                        width: isSelected ? 3 : 2,
                      ),
                    ),
                    child: isSelected
                        ? Stack(
                            children: [
                              // リサイズハンドル（右下）
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    onRectUpdated(
                                      index,
                                      rect.copyWith(
                                        width: (rect.width + details.delta.dx)
                                            .clamp(50, 1000),
                                        height: (rect.height + details.delta.dy)
                                            .clamp(50, 1000),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    color: Colors.blue,
                                    child: const Icon(
                                      Icons.zoom_out_map,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
