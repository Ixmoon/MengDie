import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // 用于渲染 Markdown 文本
import 'package:xml/xml.dart';
import 'cached_image.dart';
import '../../app/tools/xml_processor.dart';

// 导入模型
import '../../domain/models/models.dart'; // 需要 Message, MessageRole

// 本文件包含用于显示单条聊天消息气泡的小部件。

// --- 消息气泡小部件 ---
class MessageBubble extends StatelessWidget {
  final Message message; // 要显示的消息对象
  final List<XmlRule> xmlRules;
  final bool isStreaming; // 指示此气泡是否用于显示正在流式传输的临时文本
  final VoidCallback? onTap; // 点击气泡时的回调函数
  final bool isTransparent; // 新增：气泡是否半透明
  final bool isHalfWidth; // 新增：气泡是否只占一半宽度
  final int? totalTokens; // Add totalTokens to display the token count

  const MessageBubble({
    super.key,
    required this.message,
    required this.xmlRules,
    this.isStreaming = false, // 默认为 false
    this.onTap, // 可选的回调
    this.isTransparent = false, // 默认不透明
    this.isHalfWidth = false, // 默认全宽
    this.totalTokens, // Initialize totalTokens
  });

  // --- 私有辅助方法 ---

  MarkdownStyleSheet _getMarkdownStyleSheet(BuildContext context, Color textColor) {
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
      code: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
          ),
    );
  }

  /// 根据XML规则解析并渲染文本内容为一系列Widget。
  /// 此方法通过自动闭合未完成的标签来支持流式传输。
  List<Widget> _renderTextContent(BuildContext context, String textContent, List<XmlRule> rules, Color textColor, bool isStreaming) {
    var processedText = textContent.trim();
    if (!processedText.contains('<') || !processedText.contains('>')) {
      if (processedText.isEmpty) return [];
      return [MarkdownBody(data: processedText, selectable: false, styleSheet: _getMarkdownStyleSheet(context, textColor))];
    }

    // --- 自动闭合标签以处理流式文本 ---
    final tagStack = <String>[];
    final tagRegex = RegExp(r"<(/?)(\w+)[^>]*>");
    for (final match in tagRegex.allMatches(processedText)) {
      final isClosingTag = match.group(1) == '/';
      final tagName = match.group(2)!;
      if (isClosingTag) {
        if (tagStack.isNotEmpty && tagStack.last == tagName) {
          tagStack.removeLast();
        }
      } else {
        tagStack.add(tagName);
      }
    }
    // 为堆栈中剩余的所有标签添加闭合标签
    if (tagStack.isNotEmpty) {
      processedText += tagStack.reversed.map((tag) => '</$tag>').join('');
    }
    // --- 自动闭合结束 ---

    try {
      final document = XmlDocument.parse('<root>$processedText</root>');
      final List<Widget> widgets = [];
      final ruleMap = { for (var rule in rules) rule.tagName?.toLowerCase(): rule.action };
      final innerXmlTextColor = textColor.withOpacity(0.7);

      for (final node in document.rootElement.children) {
        if (node is XmlText) {
          if (node.value.trim().isNotEmpty) {
            widgets.add(MarkdownBody(data: node.value, selectable: false, styleSheet: _getMarkdownStyleSheet(context, textColor)));
          }
        } else if (node is XmlElement) {
          final tagNameLower = node.name.local.toLowerCase();
          final action = ruleMap[tagNameLower];

          switch (action) {
            case XmlAction.collapsible:
              final content = node.text.trim();
              if (content.isNotEmpty) {
                widgets.add(
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent), // 隐藏默认的分割线
                    child: ExpansionTile(
                      initiallyExpanded: isStreaming, // 流式传输时展开，结束后折叠
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        node.name.local,
                        style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14),
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: MarkdownBody(
                            data: content,
                            selectable: false,
                            styleSheet: _getMarkdownStyleSheet(context, innerXmlTextColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              break;
            case XmlAction.ignore:
              // 规则: ignore -> UI不显示任何内容
              break;
            case null: // No rule found
            default:
              // 规则: 没有规则 -> UI显示剥离标签的内部文本
              final content = node.text.trim();
              if (content.isNotEmpty) {
                widgets.add(MarkdownBody(data: content, selectable: false, styleSheet: _getMarkdownStyleSheet(context, innerXmlTextColor)));
              }
              break;
          }
        }
      }
      return widgets;
    } catch (e) {
      // 如果解析失败，作为回退，尝试剥离所有标签并显示
      final fallbackContent = XmlProcessor.stripXmlContent(textContent);
      if (fallbackContent.isEmpty) return [];
      return [MarkdownBody(data: fallbackContent, selectable: false, styleSheet: _getMarkdownStyleSheet(context, textColor))];
    }
  }

  Widget _buildTextPart(BuildContext context, Color textColor, bool isUser, bool isStreaming) {
    final textContent = message.modelsText.isEmpty && isStreaming && !isUser ? "..." : message.modelsText;

    // 统一使用 _renderTextContent 来处理所有情况
    final widgets = _renderTextContent(context, textContent, xmlRules, textColor, isStreaming);
    if (widgets.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildNonTextPart(BuildContext context, MessagePart part, Color textColor) {
    switch (part.type) {
      case MessagePartType.image:
      case MessagePartType.generatedImage:
        if (part.base64Data != null) {
          return ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 400, // Allow larger images
            ),
            child: CachedImageFromBase64(
              base64String: part.base64Data!,
              fit: BoxFit.contain,
              cacheHeight: (400 * MediaQuery.of(context).devicePixelRatio).round(),
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
      case MessagePartType.audio:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.audiotrack_outlined, color: textColor, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                part.fileName ?? '音频文件',
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

  Widget _buildMessageContent(BuildContext context, Color textColor, bool isUser, bool isStreaming) {
    final hasText = message.modelsText.isNotEmpty;
    final nonTextParts = message.parts.where((p) => p.type != MessagePartType.text).toList();
    final originalXml = message.originalXmlContent;
    final secondaryXml = message.secondaryXmlContent;

    return SelectionArea(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasText)
              _buildTextPart(context, textColor, isUser, isStreaming),
            ...nonTextParts.map((part) {
              return Padding(
                padding: const EdgeInsets.only(top:0),
                child: _buildNonTextPart(context, part, textColor),
              );
            }),
            if (originalXml != null && originalXml.isNotEmpty)
              _buildXmlExpansionTile(context, '原生XML内容', originalXml, textColor, isStreaming),
            if (secondaryXml != null && secondaryXml.isNotEmpty)
              _buildXmlExpansionTile(context, '再生XML内容', secondaryXml, textColor, isStreaming),
            if (totalTokens != null && totalTokens! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "Tokens: $totalTokens",
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

  Widget _buildXmlExpansionTile(BuildContext context, String title, String xmlContent, Color textColor, bool isStreaming) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: isStreaming, // 流式传输时展开，结束后折叠
        tilePadding: EdgeInsets.zero,
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor.withOpacity(0.7), fontSize: 12),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: MarkdownBody(
              data: '```xml\n$xmlContent\n```',
              selectable: false,
              styleSheet: _getMarkdownStyleSheet(context, textColor),
            ),
          ),
        ],
      ),
    );
  }

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
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: _buildMessageContent(context, textColor, isUser, isStreaming),
          ),
        ),
      ),
    );
  }
}
