
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // 用于渲染 Markdown 文本
import 'cached_image.dart';

// 导入模型
import '../../data/models/models.dart'; // 需要 Message, MessageRole

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
    bool isUser = message.role == MessageRole.user;
    var alignment = isUser
        ? (isHalfWidth ? Alignment.topRight : Alignment.centerRight)
        : (isHalfWidth ? Alignment.topLeft : Alignment.centerLeft);

    var baseColor = isUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.secondaryContainer;

    var color = isTransparent ? baseColor.withAlpha(180) : baseColor;

    var textColor = isUser
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSecondaryContainer;

    final screenWidth = MediaQuery.of(context).size.width;

    // Card 本身是气泡。我们将其包装在 Container 中以应用约束和边距。
    // InkWell 放置在 Card 内部，使整个可见区域都可点击。
    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isHalfWidth ? screenWidth * 2 / 3 : double.infinity,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withAlpha((255 * 0.2).round()),
              width: 0.8,
            ),
          ),
          color: color,
          elevation: 0,
          margin: EdgeInsets.zero, // 边距现在位于外部容器上
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: _buildMessageContent(context, textColor, isUser, isStreaming),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, Color textColor, bool isUser, bool isStreaming) {
    final hasText = message.displayText.isNotEmpty;
    final nonTextParts = message.parts.where((p) => p.type != MessagePartType.text).toList();

    // 使用 SelectionArea 包装所有内容以实现统一选择。
    // 在其内部使用 GestureDetector 来处理点击事件，避免与 SelectionArea 冲突。
    return SelectionArea(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque, // 确保整个内容区域都可点击
        child: Column(
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
        ),
      ),
    );
  }

  Widget _buildTextPart(BuildContext context, Color textColor, bool isUser, bool isStreaming) {
    // 将用户和模型消息统一为使用 MarkdownBody，以实现一致的渲染、
    // 多行选择，并解决手势冲突。
    final textContent = message.displayText.isEmpty && isStreaming && !isUser
        ? "..." // 仅为流式模型响应显示省略号
        : message.displayText;

    return MarkdownBody(
      data: textContent,
      selectable: false, // 由父级的 SelectionArea 处理选择
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
        code: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
            ),
      ),
    );
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
            cacheHeight: (300 * MediaQuery.of(context).devicePixelRatio).round(),
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
