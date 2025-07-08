
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // 用于渲染 Markdown 文本
import './cached_image.dart';

// 导入模型
import '../models/models.dart'; // 需要 Message, MessageRole

// 本文件包含用于显示单条聊天消息气泡的小部件。

// --- 消息气泡小部件 ---
// 根据消息的角色（用户或模型）显示不同样式和对齐方式的气泡。
// 支持显示普通文本和 Markdown 格式的文本。
// 还包含一个可选的 onTap 回调，用于处理气泡点击事件。
class MessageBubble extends StatelessWidget {
  final Message message; // 要显示的消息对象
  final bool isStreaming; // 指示此气泡是否用于显示正在流式传输的临时文本
  final VoidCallback? onTap; // 点击气泡时的回调函数
  final bool isTransparent; // 新增：气泡是否半透明
  final bool isHalfWidth; // 新增：气泡是否只占一半宽度
  final int? totalTokens; // Add totalTokens to display the token count

  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false, // 默认为 false
    this.onTap, // 可选的回调
    this.isTransparent = false, // 默认不透明
    this.isHalfWidth = false, // 默认全宽
    this.totalTokens, // Initialize totalTokens
  });

  @override
  Widget build(BuildContext context) {
    // 判断消息是否由用户发送
    bool isUser = message.role == MessageRole.user;
    // 根据发送者和宽度模式设置对齐方式
    var alignment = isUser
        ? (isHalfWidth ? Alignment.topRight : Alignment.centerRight) // 半宽时靠上右，全宽时居中右
        : (isHalfWidth ? Alignment.topLeft : Alignment.centerLeft); // 半宽时靠上左，全宽时居中左

    // 根据发送者选择基础气泡颜色
    var baseColor = isUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.secondaryContainer;

    // 如果需要透明，则调整颜色透明度
    var color = isTransparent ? baseColor.withAlpha(180) : baseColor; // 约 70% 不透明度

    // 根据发送者选择文本颜色，确保对比度
    var textColor = isUser
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSecondaryContainer;

    // 获取屏幕宽度，用于计算半宽
    final screenWidth = MediaQuery.of(context).size.width;

    // 使用 Align 控制气泡在聊天列表中的水平位置
    return Align(
      alignment: alignment,
      // 使用 Container 约束宽度
      child: Container(
        constraints: BoxConstraints(
          // 如果是半宽模式，最大宽度为屏幕宽度的 2/3，否则不限制
          maxWidth: isHalfWidth ? screenWidth * 2 / 3 : double.infinity,
        ),
        // 使用 InkWell 包裹 Card，以提供点击效果和处理 onTap 回调
        child: InkWell(
          onTap: onTap, // 绑定 onTap 回调
          hoverColor: Colors.transparent, // 禁用悬停颜色效果
          focusColor: Colors.transparent, // 禁用聚焦颜色效果
          highlightColor: Colors.transparent, // 可选：禁用按下时的高亮颜色
          splashColor: Theme.of(context).splashColor.withAlpha(25), // 使用 withAlpha 替代 withOpacity(0.1)
          // 设置圆角以匹配 Card 的形状，使水波纹效果更自然
          borderRadius: BorderRadius.circular(12.0),
          child: Card( // 使用 Card 实现气泡的基本外观
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), // 确保 Card 本身有圆角
            color: color, // 设置气泡背景色
            elevation: 1.0, // 设置轻微阴影
            // 设置外边距，用于控制气泡之间的间距
            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), // const
            child: Padding(
              padding: const EdgeInsets.all(10.0), // const: 设置气泡内部边距
              // 使用 Column 垂直排列消息内容和（未来可能的）时间戳等信息
              child: _buildMessageContent(context, textColor, isUser, isStreaming),
            ),
          ), // 结束 Card
        ), // 结束 InkWell
      ), // 结束 Container
    ); // 结束 Align
  }

Widget _buildMessageContent(BuildContext context, Color textColor, bool isUser, bool isStreaming) {
  final hasText = message.displayText.isNotEmpty;
  final nonTextParts = message.parts.where((p) => p.type != MessagePartType.text).toList();

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (hasText)
        _buildTextPart(context, textColor, isUser, isStreaming),
      ...nonTextParts.map((part) {
        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: _buildNonTextPart(context, part, textColor),
        );
      }),
      // Display token count if available
      if (totalTokens != null && totalTokens! > 0)
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            "上下文 Tokens: $totalTokens",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor.withAlpha(179),
                ),
          ),
        ),
    ],
  );
}

Widget _buildTextPart(BuildContext context, Color textColor, bool isUser, bool isStreaming) {
  if (isUser) {
    return SelectableText(message.displayText, style: TextStyle(color: textColor));
  } else {
    return MarkdownBody(
      data: message.displayText.isEmpty && isStreaming ? "..." : message.displayText,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
        code: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
            ),
      ),
    );
  }
}

Widget _buildNonTextPart(BuildContext context, MessagePart part, Color textColor) {
  switch (part.type) {
    case MessagePartType.image:
      if (part.base64Data != null) {
        return ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 300, // Limit image height
          ),
          child: CachedImageFromBase64(
            base64String: part.base64Data!,
            fit: BoxFit.contain,
          ),
        );
      }
      return const SizedBox.shrink();
    case MessagePartType.file:
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined, color: textColor, size: 24),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              part.fileName ?? '未知文件',
              style: TextStyle(color: textColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    case MessagePartType.text:
      return const SizedBox.shrink(); // Text parts are handled separately
  }
}
}
