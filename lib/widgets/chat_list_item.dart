import 'dart:convert'; // 用于 base64Decode
import 'dart:typed_data'; // 用于 Uint8List
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 用于日期格式化

// 导入模型
import '../models/models.dart'; // 需要 Chat 模型

// 本文件包含用于在聊天列表中显示单个聊天项的小部件。

// --- 聊天列表项小部件 ---
// 显示聊天的封面图片（如果存在）、标题和最后更新时间。
// 提供 onTap 回调以处理点击事件（例如导航到聊天屏幕）。
class ChatListItem extends StatelessWidget {
  final Chat chat; // 要显示的聊天对象
  final VoidCallback onTap; // 点击列表项时的回调函数

  const ChatListItem({
    super.key,
    required this.chat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
     Widget leadingWidget; // 用于显示封面图或默认图标的小部件

     if (chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty) {
        try {
          final Uint8List imageBytes = base64Decode(chat.coverImageBase64!);
          leadingWidget = Image.memory(
             imageBytes,
             width: 50, // 固定宽度
             height: 50, // 固定高度
             cacheWidth: 100, // 优化：为图片解码指定缓存宽度 (物理像素)
             cacheHeight: 100, // 优化：为图片解码指定缓存高度 (物理像素)
             fit: BoxFit.cover, // 图片填充方式为覆盖
             // 处理图片加载错误 (例如 Base64 字符串不是有效的图片数据)
             errorBuilder: (context, error, stackTrace) {
                // debugPrint("从 Base64 加载封面图片时出错: $error"); // 可以保留用于调试
                // 显示破损图片图标作为回退
                return const Icon(Icons.broken_image, size: 50, color: Colors.grey);
             }
          );
        } catch (e) {
          // debugPrint("解码 Base64 封面图片时异常: $e");
          // 解码失败，显示默认图标
          leadingWidget = const Icon(Icons.broken_image, size: 50, color: Colors.grey);
        }
     } else {
        // 如果没有封面图片 Base64 数据，显示默认图标
        leadingWidget = const Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey);
     }

    // 使用 ListTile 构建列表项的基本结构
    return ListTile(
      // 左侧显示圆形头像区域，包含封面图或图标
      leading: CircleAvatar(
         radius: 25, // 头像半径
         backgroundColor: (chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty && !(leadingWidget is Icon && (leadingWidget as Icon).icon == Icons.broken_image))
             ? Colors.transparent // 如果有有效图片，背景设为透明
             : Theme.of(context).colorScheme.primaryContainer, // 否则使用主题颜色
         // 直接将 leadingWidget 作为 child，CircleAvatar 会进行圆形裁剪
         child: leadingWidget,
      ),
      // 显示聊天标题，最多一行，超出部分显示省略号
      title: Text(chat.title ?? '无标题聊天', maxLines: 1, overflow: TextOverflow.ellipsis),
      // 显示最后更新时间，格式化后显示，最多一行，超出部分显示省略号
      subtitle: Text(
        '更新于: ${DateFormat.yMd().add_jm().format(chat.updatedAt)}', // 使用 intl 包格式化日期时间
        style: Theme.of(context).textTheme.bodySmall, // 使用较小的字体样式
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // 绑定 onTap 回调到 ListTile 的 onTap 事件
      onTap: onTap,
      // 注意：原代码中的 trailing 删除按钮已移除，删除操作通过长按手势处理
    );
  }
}
