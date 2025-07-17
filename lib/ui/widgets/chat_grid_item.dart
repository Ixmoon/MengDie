// --- 文件功能 ---
// 本文件定义了在网格视图中展示单个聊天或文件夹的 Widget。
//
// --- 主要功能 ---
// 1. **差异化显示**: 能根据项目是聊天还是文件夹，展示不同的背景和图标。
// 2. **信息展示**:
//    - 对话：显示封面图、标题和最新消息预览。
//    - 文件夹：显示文件夹图标和名称。
// 3. **异步加载**: 使用 `ConsumerWidget` 和 `ref.watch` 异步获取并显示聊天的第一条消息，并优雅地处理加载和错误状态。
// 4. **多选支持**: 根据 `isSelected` 状态，通过叠加层和边框来清晰地指示选中状态。
// 5. **图像缓存**: 使用 `CachedImageFromBase64` 来高效加载和显示封面图。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import '../../app/providers/chat_state_providers.dart';
import 'cached_image.dart';
import '../../app/providers/chat_state/chat_data_providers.dart';

/// 网格视图中的聊天项小部件
class ChatGridItem extends ConsumerWidget {
  final Chat chat;
  final bool isSelected;
  final VoidCallback onTap;

  const ChatGridItem({
    super.key,
    required this.chat,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstModelMessageAsync = ref.watch(firstModelMessageProvider(chat.id));

    Widget displayWidget;
    if (chat.isFolder) {
      displayWidget = Container(
        color: Colors.amber.shade100,
        child: Icon(Icons.folder_outlined, color: Colors.amber.shade800, size: 50),
      );
    } else {
      if (chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty) {
        displayWidget = CachedImageFromBase64(
          base64String: chat.coverImageBase64!,
          fit: BoxFit.cover,
          cacheWidth: 240,
          cacheHeight: 360,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey.shade300,
            child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
          ),
        );
      } else {
        displayWidget = Container(
          color: Colors.grey.shade300,
          child: const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 40),
        );
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: GridTile(
        footer: GridTileBar(
          backgroundColor: Colors.black54,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                chat.title ?? (chat.isFolder ? '未命名文件夹' : '无标题'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!chat.isFolder && chat.updatedAt.millisecondsSinceEpoch >= 1000)
                firstModelMessageAsync.when(
                  data: (message) {
                    if (message == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        message.displayText,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade300),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                  loading: () => const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (e, s) => const Icon(Icons.error_outline, color: Colors.red, size: 14),
                ),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: displayWidget,
            ),
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((255 * 0.3).round()),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                ),
                child: Icon(Icons.check_circle, color: Colors.white.withAlpha((255 * 0.8).round()), size: 30),
              ),
          ],
        ),
      ),
    );
  }
}