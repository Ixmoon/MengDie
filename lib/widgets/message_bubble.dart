import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // 用于渲染 Markdown 文本
import '../services/xml_processor.dart'; // 导入 XmlProcessor 服务

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

  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false, // 默认为 false
    this.onTap, // 可选的回调
    this.isTransparent = false, // 默认不透明
    this.isHalfWidth = false, // 默认全宽
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

    // 确定要显示的文本：
    // 使用 XmlProcessor.stripXmlContent 过滤掉 XML 标签
    final String strippedText = XmlProcessor.stripXmlContent(message.rawText);
    final displayText = strippedText;


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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // 内容左对齐
                children: [
                  // 根据消息类型选择渲染方式
                  isUser
                      // 用户消息：使用 SelectableText 显示纯文本，允许用户复制
                      ? SelectableText(displayText, style: TextStyle(color: textColor))
                      // AI 消息或流式消息：使用 MarkdownBody 渲染 Markdown 格式
                      : MarkdownBody(
                          // 如果是流式传输且初始为空，显示省略号作为占位符
                          data: displayText.isEmpty && isStreaming ? "..." : displayText,
                          selectable: true, // 允许选择和复制 Markdown 内容 - 恢复选择功能
                          // 应用主题样式，并根据需要进行定制
                         styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            // 设置段落文本样式
                            p: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
                            // 示例：自定义代码块样式
                            code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontFamily: 'monospace', // 使用等宽字体
                                  // 设置代码块背景色
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128), // 使用 withAlpha
                                ),
                            // 可以根据需要添加更多元素的样式，如 h1, h2, blockquote 等
                          ),
                         ), // 修正：补上缺失的右括号
                  // 注意：当前设计中，时间戳等元信息不在气泡内显示，
                  // 如果需要显示，可以在这里添加 Text 小部件。
                  // 例如：
                  // if (!isStreaming) // 不在流式气泡中显示时间戳
                  //   Padding(
                  //     padding: const EdgeInsets.only(top: 4.0),
                  //     child: Text(
                  //       DateFormat.Hm().format(message.timestamp), // 格式化时间
                  //       style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor.withOpacity(0.7)),
                  //     ),
                  //   ),
                ],
              ),
            ),
          ), // 结束 Card
        ), // 结束 InkWell
      ), // 结束 Container
    ); // 结束 Align
  }
}
