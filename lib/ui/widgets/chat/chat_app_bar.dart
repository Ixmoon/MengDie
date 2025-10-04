import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/models/models.dart';
import '../../../app/tools/chat_export_import.dart';
import '../../../app/providers/chat_state_providers.dart';

// _ChatAppBar 提取为公有 Widget
class ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final Chat chat;
  final VoidCallback onSetCoverImage;
  final VoidCallback onExportCoverImage;
  final VoidCallback onRemoveCoverImage;
  final VoidCallback onForcePush;
  final bool isPushing;
  final Function(MessageRole) onAddMessageAtEnd;
  final VoidCallback? onBackButtonPressed; // 新增：自定义返回按钮回调

  const ChatAppBar({
    super.key,
    required this.chat,
    required this.onSetCoverImage,
    required this.onExportCoverImage,
    required this.onRemoveCoverImage,
    required this.onForcePush,
    required this.isPushing,
    required this.onAddMessageAtEnd,
    this.onBackButtonPressed, // 新增
  });

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required IconData icon,
    required String label,
    bool enabled = true,
  }) {
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        dense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatId = chat.id;
    final chatState = ref.watch(chatStateNotifierProvider(chatId));

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(
        shadows: <Shadow>[
          Shadow(color: Colors.black.withAlpha((255 * 0.5).round()), blurRadius: 1.0)
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: '返回列表',
        onPressed: onBackButtonPressed ?? () { // 修改：优先使用自定义回调
          ref.read(activeChatIdProvider.notifier).state = null;
          context.go('/list');
        },
      ),
      title: Text(
        chat.title ?? '聊天',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          shadows: <Shadow>[
            Shadow(color: Colors.black.withAlpha((255 * 0.5).round()), blurRadius: 1.0)
          ],
        ),
      ),
      actions: [
        isPushing
            ? const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.upload_outlined),
                tooltip: '上传本地变更',
                onPressed: onForcePush,
              ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          tooltip: '更多选项',
          onPressed: () async {
            final renderBox = context.findRenderObject() as RenderBox;
            final position = renderBox.localToGlobal(Offset.zero) & renderBox.size;

            final String? result = await showMenu<String>(
              context: context,
              position: RelativeRect.fromLTRB(position.right, position.top, position.right, position.bottom),
              items: <PopupMenuEntry<String>>[
                _buildPopupMenuItem(value: 'settings', icon: Icons.tune, label: '聊天设置'),
                const PopupMenuDivider(),
                _buildPopupMenuItem(value: 'setCoverImage', icon: Icons.photo_library_outlined, label: '设置封面'),
                _buildPopupMenuItem(
                  value: 'exportCoverImage',
                  icon: Icons.upload_file_outlined,
                  label: '导出封面',
                  enabled: chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty,
                ),
                _buildPopupMenuItem(
                  value: 'removeCoverImage',
                  icon: Icons.delete_outline,
                  label: '移除封面',
                  enabled: chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty,
                ),
                const PopupMenuDivider(),
                _buildPopupMenuItem(value: 'toggleOutputMode', icon: chatState.isStreamMode ? Icons.stream : Icons.chat_bubble, label: chatState.isStreamMode ? '切换为一次性输出' : '切换为流式输出'),
                _buildPopupMenuItem(value: 'toggleBubbleTransparency', icon: chatState.isBubbleTransparent ? Icons.opacity : Icons.opacity_outlined, label: chatState.isBubbleTransparent ? '切换为不透明气泡' : '切换为半透明气泡'),
                _buildPopupMenuItem(value: 'toggleBubbleWidth', icon: chatState.isBubbleHalfWidth ? Icons.width_normal : Icons.width_wide, label: chatState.isBubbleHalfWidth ? '切换为全宽气泡' : '切换为半宽气泡'),
                _buildPopupMenuItem(value: 'toggleMessageListHeight', icon: chatState.isAutoHeightEnabled ? Icons.dynamic_feed : Icons.height, label: chatState.isAutoHeightEnabled ? '关闭智能半高' : '开启智能半高'),
                _buildPopupMenuItem(value: 'toggleHighlightQuotes', icon: chatState.highlightQuotes ? Icons.format_quote : Icons.format_quote_outlined, label: chatState.highlightQuotes ? '关闭引号高亮' : '开启引号高亮'),
                const PopupMenuDivider(),
                _buildPopupMenuItem(value: 'exportChat', icon: Icons.file_download_outlined, label: '导出到文件'),
                _buildPopupMenuItem(value: 'exportAsTemplate', icon: Icons.flip_to_front_outlined, label: '另存为模板'),
                _buildPopupMenuItem(value: 'exportAsChat', icon: Icons.control_point_duplicate_outlined, label: '克隆为新聊天'),
                const PopupMenuDivider(),
                _buildPopupMenuItem(value: 'add_user_message', icon: Icons.add_comment_outlined, label: '添加用户消息'),
                _buildPopupMenuItem(value: 'add_model_message', icon: Icons.add_comment_outlined, label: '添加模型消息'),
                const PopupMenuDivider(),
                _buildPopupMenuItem(value: 'debug', icon: Icons.bug_report_outlined, label: '调试页面'),
              ],
            );

            if (result == null || !context.mounted) return;

            final notifier = ref.read(chatStateNotifierProvider(chatId).notifier);
            switch (result) {
              case 'settings':
                context.push('/chat/settings');
                break;
              case 'setCoverImage':
                onSetCoverImage();
                break;
              case 'exportCoverImage':
                onExportCoverImage();
                break;
              case 'removeCoverImage':
                onRemoveCoverImage();
                break;
              case 'toggleOutputMode':
                notifier.toggleOutputMode();
                break;
              case 'debug':
                context.push('/chat/debug');
                break;
              case 'toggleBubbleTransparency':
                notifier.toggleBubbleTransparency();
                break;
              case 'toggleBubbleWidth':
                notifier.toggleBubbleWidthMode();
                break;
              case 'toggleMessageListHeight':
                notifier.toggleMessageListHeightMode();
                break;
              case 'toggleHighlightQuotes':
                notifier.toggleHighlightQuotes();
                break;
              case 'exportChat':
                notifier.showTopMessage('正在准备导出文件...', backgroundColor: Colors.blueGrey, duration: const Duration(days: 1));
                try {
                  final finalExportPath = await ref.read(chatExportImportServiceProvider).exportChat(chat.id);
                  if (!context.mounted) return;
                  if (finalExportPath != null) {
                    notifier.showTopMessage('聊天已成功导出到: $finalExportPath', backgroundColor: Colors.green, duration: const Duration(seconds: 4));
                  } else if (!kIsWeb) {
                    notifier.showTopMessage('导出操作已取消或未能成功完成。', backgroundColor: Colors.orange, duration: const Duration(seconds: 3));
                  }
                } catch (e) {
                  debugPrint("导出聊天时发生错误: $e");
                  if (context.mounted) {
                    notifier.showTopMessage('导出失败: $e', backgroundColor: Colors.red);
                  }
                } finally {
                  if (context.mounted && ref.read(chatStateNotifierProvider(chat.id)).topMessageText == '正在准备导出文件...') {
                    notifier.clearTopMessage();
                  }
                }
                break;
              case 'exportAsTemplate':
                // 统一调用 ChatStateNotifier 的方法
                await notifier.duplicateChat(upToMessageId: 0, asTemplate: true);
                break;
              case 'exportAsChat':
                // 统一调用 ChatStateNotifier 的方法
                await notifier.duplicateChat(upToMessageId: 0, asTemplate: false);
                break;
              case 'add_user_message':
                onAddMessageAtEnd(MessageRole.user);
                break;
              case 'add_model_message':
                onAddMessageAtEnd(MessageRole.model);
                break;
            }
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}