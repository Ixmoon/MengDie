// --- 文件功能 ---
// 本文件定义了在列表视图中展示单个聊天或文件夹的 Widget。
//
// --- 主要功能 ---
// 1. **差异化显示**: 能根据项目是聊天还是文件夹，展示不同的图标和布局。
// 2. **信息展示**:
//    - 对话：显示封面图、标题、最新消息预览和更新时间。
//    - 文件夹：显示文件夹图标、名称和类型信息。
// 3. **异步加载**: 使用 `ConsumerWidget` 和 `ref.watch` 异步获取并显示聊天的第一条消息，并优雅地处理加载和错误状态。
// 4. **多选支持**: 根据 `isMultiSelectMode` 和 `isSelected` 状态，显示或隐藏复选框和高亮背景。
// 5. **图像缓存**: 使用 `CachedImageFromBase64` 来高效加载和显示封面图。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/models.dart';
import '../providers/chat_state_providers.dart';
import 'cached_image.dart';

/// 列表视图中的聊天项小部件
class ChatListItem extends ConsumerWidget {
  final Chat chat;
  final bool isSelected;
  final bool isMultiSelectMode;
  final VoidCallback onTap;

  const ChatListItem({
    super.key,
    required this.chat,
    required this.isSelected,
    required this.isMultiSelectMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstModelMessageAsync = ref.watch(firstModelMessageProvider(chat.id));

    return Container(
      color: isSelected ? Theme.of(context).highlightColor : null,
      child: InkWell(
        onTap: onTap,
        child: chat.isFolder
            ? ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(chat.title ?? '未命名文件夹'),
                subtitle: Text(
                  chat.updatedAt.millisecondsSinceEpoch < 1000
                      ? '文件夹'
                      : '文件夹 - ${DateFormat.yMd().add_Hm().format(chat.updatedAt)}',
                ),
                trailing: isMultiSelectMode ? Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank) : null,
              )
            : ListTile(
                leading: _buildLeading(context, chat),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            chat.title ?? '无标题聊天',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (chat.updatedAt.millisecondsSinceEpoch >= 1000)
                          Text(
                            DateFormat.yMd().add_jm().format(chat.updatedAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chat.updatedAt.millisecondsSinceEpoch < 1000
                          ? '模板'
                          : firstModelMessageAsync.when(
                              data: (message) => message?.displayText ?? '',
                              loading: () => '...',
                              error: (err, st) => '!',
                            ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: chat.updatedAt.millisecondsSinceEpoch < 1000 ? Theme.of(context).colorScheme.primary : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                trailing: isMultiSelectMode ? Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank) : null,
              ),
      ),
    );
  }

  Widget _buildLeading(BuildContext context, Chat chat) {
    final bool hasImage = chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty;
    Widget leadingWidget;
    if (hasImage) {
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      leadingWidget = CachedImageFromBase64(
        base64String: chat.coverImageBase64!,
        width: 50,
        height: 50,
        cacheWidth: (50 * pixelRatio).round(),
        cacheHeight: (50 * pixelRatio).round(),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
      );
    } else {
      leadingWidget = const Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey);
    }
    return CircleAvatar(
      radius: 25,
      backgroundColor: hasImage ? Colors.transparent : Theme.of(context).colorScheme.primaryContainer,
      child: ClipOval(child: leadingWidget),
    );
  }
}