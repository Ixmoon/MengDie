import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // 用于渲染 Markdown 文本
import 'package:xml/xml.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull
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
  final String? carriedOverXml; // The synthesized XML context for the latest user message

  const MessageBubble({
    super.key,
    required this.message,
    required this.xmlRules,
    this.isStreaming = false, // 默认为 false
    this.onTap, // 可选的回调
    this.isTransparent = false, // 默认不透明
    this.isHalfWidth = false, // 默认全宽
    this.totalTokens, // Initialize totalTokens
    this.carriedOverXml,
  });

  // --- 私有辅助方法 ---

  MarkdownStyleSheet _getMarkdownStyleSheet(BuildContext context, Color textColor) {
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
      code: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
          ),
      blockquote: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: textColor.withOpacity(0.85),
          ),
      blockquoteDecoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(128),
            width: 4,
          ),
        ),
      ),
    );
  }

  /// [Recursive] 将XML节点及其子节点转换为格式化的Markdown字符串。
  String _buildMarkdownFromXmlNode(XmlNode node, int depth) {
    final buffer = StringBuffer();
    final indent = '  ' * depth;

    if (node is XmlElement) {
      // 对于XML元素，创建一个带项目符号的列表项
      var title = node.name.local;
      if (node.attributes.isNotEmpty) {
        final attr = node.attributes.first;
        title += ' (${attr.name.local}: ${attr.value})';
      }
      buffer.write('$indent* **$title:**');
      
      // 检查它是否只包含一个文本节点（简单标签）
      final textOnlyChild = node.children.length == 1 && node.children.first is XmlText;
      final textContent = node.text.trim();

      if (textOnlyChild && textContent.isNotEmpty) {
        // 如果是简单标签，将文本内容放在同一行
        buffer.writeln(' $textContent');
      } else if (node.children.isNotEmpty) {
        // 如果有子元素，则换行并递归处理
        buffer.writeln();
        for (final child in node.children) {
          buffer.write(_buildMarkdownFromXmlNode(child, depth + 1));
        }
      } else {
        // 如果是空标签，则只换行
        buffer.writeln();
      }
    } else if (node is XmlText) {
      final text = node.value.trim();
      if (text.isNotEmpty) {
        // 对于文本节点，添加缩进并换行
        buffer.writeln('$indent$text');
      }
    }
    // 其他类型的节点（如注释）将被忽略
    return buffer.toString();
  }

  /// 根据XML规则解析并渲染文本内容为一系列Widget。
  /// 此方法通过自动闭合未完成的标签来支持流式传输。
  List<Widget> _renderTextContent(BuildContext context, String textContent, List<XmlRule> rules, Color textColor, bool isStreaming) {
    var processedText = textContent.trim();
    if (!processedText.contains('<') && !processedText.contains('```')) {
      if (processedText.isEmpty) return [];
      return [MarkdownBody(data: processedText.replaceAll('\n', '  \n'), selectable: false, styleSheet: _getMarkdownStyleSheet(context, textColor))];
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

      for (final node in document.rootElement.children) {
        if (node is XmlText) {
          final text = node.value;
          // 更换为更健壮的正则表达式，以正确处理语言标识符后的可选空格和换行符。
          // 捕获组 1: (\w*) - 语言标识符 (例如 "python")
          // 捕获组 2: ((?:\s*\n)?[\s\S]*?) - 代码内容, 包括可选的前导换行符
          final codeBlockRegex = RegExp(r'```(\w*)((?:\s*\n)?[\s\S]*?)```');
          var lastIndex = 0;

          for (final match in codeBlockRegex.allMatches(text)) {
            // 1. 添加代码块之前的所有普通文本
            if (match.start > lastIndex) {
              final precedingText = text.substring(lastIndex, match.start).trim();
              if (precedingText.isNotEmpty) {
                widgets.add(MarkdownBody(data: precedingText.replaceAll('\n', '  \n'), selectable: false, styleSheet: _getMarkdownStyleSheet(context, textColor)));
              }
            }

            // 2. 为代码块本身创建一个可折叠组件
            final codeBlockContent = match.group(0)!;
            final language = (match.group(1) ?? '').trim();
            widgets.add(
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: isStreaming,
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    language.isNotEmpty ? language : '代码块',
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: MarkdownBody(
                        data: codeBlockContent, // 包含```的完整代码块
                        selectable: false,
                        styleSheet: _getMarkdownStyleSheet(context, textColor.withOpacity(0.85)),
                      ),
                    ),
                  ],
                ),
              ),
            );

            lastIndex = match.end;
          }

          // 3. 添加最后一个代码块之后的所有剩余文本
          if (lastIndex < text.length) {
            final remainingText = text.substring(lastIndex).trim();
            if (remainingText.isNotEmpty) {
              widgets.add(MarkdownBody(data: remainingText.replaceAll('\n', '  \n'), selectable: false, styleSheet: _getMarkdownStyleSheet(context, textColor)));
            }
          }
        } else if (node is XmlElement) {
          final tagNameLower = node.name.local.toLowerCase();
          final rule = rules.firstWhereOrNull((r) => r.tagName?.toLowerCase() == tagNameLower);

          if (rule?.action == XmlAction.content) {
            // 规则: content -> 递归渲染内部节点
            widgets.addAll(_renderTextContent(context, node.innerXml, rules, textColor, isStreaming));
          } else {
            // 默认行为 (collapsible, save, update, ignore, null) -> 创建可折叠组件
            // 使用新的递归函数将XML子树转换为Markdown
            final markdownContent = node.children.map((child) => _buildMarkdownFromXmlNode(child, 0)).join();
            if (markdownContent.trim().isNotEmpty) {
              widgets.add(
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: isStreaming,
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      node.name.local,
                      style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: MarkdownBody(
                          data: markdownContent,
                          selectable: false,
                          styleSheet: _getMarkdownStyleSheet(context, textColor.withOpacity(0.85)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          }
        }
      }
      return widgets;
    } catch (e) {
      final fallbackContent = XmlProcessor.stripXmlContent(textContent);
      if (fallbackContent.isEmpty) return [];
      return [MarkdownBody(data: fallbackContent.replaceAll('\n', '  \n'), selectable: false, styleSheet: _getMarkdownStyleSheet(context, textColor))];
    }
  }

  Widget _buildTextPart(BuildContext context, Color textColor, bool isUser, bool isStreaming) {
    final textContent = message.modelsText.isEmpty && isStreaming && !isUser ? "..." : message.modelsText;
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
              maxHeight: 400,
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
        return const SizedBox.shrink();
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
        initiallyExpanded: isStreaming,
        tilePadding: EdgeInsets.zero,
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor.withOpacity(0.7), fontSize: 12),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: () {
              try {
                // 复用将XML节点转换为Markdown的递归逻辑
                final document = XmlDocument.parse('<root>$xmlContent</root>');
                final markdownContent = document.rootElement.children
                    .map((node) => _buildMarkdownFromXmlNode(node, 0))
                    .join();
                return MarkdownBody(
                  data: markdownContent,
                  selectable: false,
                  styleSheet: _getMarkdownStyleSheet(context, textColor.withOpacity(0.85)),
                );
              } catch (e) {
                // 如果解析失败，则回退到原始的代码块显示
                return MarkdownBody(
                  data: '```xml\n$xmlContent\n```',
                  selectable: false,
                  styleSheet: _getMarkdownStyleSheet(context, textColor),
                );
              }
            }(),
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
        ? Theme.of(context).colorScheme.secondaryContainer
        : Theme.of(context).cardColor.withAlpha((255 * 0.95).round());

    var color = isTransparent ? baseColor.withAlpha(180) : baseColor;

    var textColor = isUser
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSecondaryContainer;

    final screenWidth = MediaQuery.of(context).size.width;

    final messageCard = Align(
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

    if (isUser && carriedOverXml != null && carriedOverXml!.isNotEmpty) {
      final xmlBubble = Align(
        alignment: alignment,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isHalfWidth ? screenWidth * 2 / 3 : double.infinity,
          ),
          margin: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 4.0),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline.withAlpha((255 * 0.1).round()),
                width: 0.8,
              ),
            ),
            color: color.withAlpha(180),
            elevation: 0,
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: _buildXmlExpansionTile(context, '合成XML', carriedOverXml!, textColor, isStreaming),
            ),
          ),
        ),
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          xmlBubble,
          messageCard,
        ],
      );
    }

    return messageCard;
  }
}
