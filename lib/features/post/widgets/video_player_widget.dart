import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:video_player/video_player.dart';

/// ネットワーク動画を再生するウィジェット（Flutter Web / Mobile 対応）
class VideoPlayerWidget extends HookWidget {
  final String url;

  const VideoPlayerWidget({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final controller = useMemoized(
      () => VideoPlayerController.networkUrl(Uri.parse(url)),
      [url],
    );
    final isInitialized = useState(false);
    final isPlaying = useState(false);
    final hasError = useState(false);
    final position = useState(Duration.zero);
    final duration = useState(Duration.zero);

    useEffect(() {
      controller
          .initialize()
          .then((_) {
            isInitialized.value = true;
            duration.value = controller.value.duration;
          })
          .catchError((_) {
            hasError.value = true;
          });

      void listener() {
        position.value = controller.value.position;
        isPlaying.value = controller.value.isPlaying;
      }

      controller.addListener(listener);
      return () {
        controller.removeListener(listener);
        controller.dispose();
      };
    }, [controller]);

    if (hasError.value) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 64, color: Colors.white38),
            SizedBox(height: 12),
            Text('動画を読み込めませんでした', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    if (!isInitialized.value) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    final totalSeconds = duration.value.inSeconds;
    final currentSeconds = position.value.inSeconds.clamp(0, totalSeconds);

    String _formatDuration(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // 動画本体（残りの高さをすべて使う）
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
                AnimatedOpacity(
                  opacity: isPlaying.value ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // コントロールバー
        Container(
          color: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // 再生/一時停止ボタン
              IconButton(
                icon: Icon(
                  isPlaying.value ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                },
              ),

              // 現在位置
              Text(
                _formatDuration(position.value),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),

              // シークバー
              Expanded(
                child: Slider(
                  value: totalSeconds > 0
                      ? currentSeconds.toDouble()
                      : 0.0,
                  min: 0.0,
                  max: totalSeconds > 0 ? totalSeconds.toDouble() : 1.0,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white30,
                  onChanged: totalSeconds > 0
                      ? (value) {
                          controller.seekTo(
                            Duration(seconds: value.toInt()),
                          );
                        }
                      : null,
                ),
              ),

              // 合計時間
              Text(
                _formatDuration(duration.value),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ],
    );
  }
}

