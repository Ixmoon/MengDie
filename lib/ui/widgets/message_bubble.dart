import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // 用于渲染 Markdown 文本
import 'package:url_launcher/url_launcher.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:xml/xml.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull
import 'cached_image.dart';
import 'chat/quote_highlight_syntax.dart';

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
  final bool highlightQuotes; // 新增：是否高亮引号内容
  final int? totalTokens; // Add totalTokens to display the token count
  final String?
      carriedOverXml; // The synthesized XML context for the latest user message
  final bool isPseudoStreamMode;
  final double pseudoStreamSpeed;
  final bool isLastMessageInList;

  const MessageBubble({
    super.key,
    required this.message,
    required this.xmlRules,
    this.isStreaming = false,
    this.onTap,
    this.isTransparent = false,
    this.isHalfWidth = false,
    this.highlightQuotes = false,
    this.totalTokens,
    this.carriedOverXml,
    this.isPseudoStreamMode = false,
    this.pseudoStreamSpeed = 1.0,
    this.isLastMessageInList = false,
  });

  // --- 私有辅助方法 ---

  void _onTapLink(String text, String? href, String title) {
    if (href != null) {
      final uri = Uri.tryParse(href);
      if (uri != null) {
        launchUrl(uri);
      }
    }
  }

  MarkdownStyleSheet _getMarkdownStyleSheet(
    BuildContext context,
    Color textColor,
  ) {
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
      code: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withAlpha(128),
      ),
      blockquote: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: textColor.withAlpha((255 * 0.85).round()),
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

  /// 获取带引号高亮的 Markdown 扩展配置
  List<md.InlineSyntax> _getMarkdownInlineSyntaxes() {
    if (highlightQuotes) {
      return [QuoteHighlightSyntax()];
    }
    return [];
  }

  /// 获取带引号高亮的 Markdown 构建器配置
  Map<String, MarkdownElementBuilder> _getMarkdownBuilders(Color textColor) {
    if (highlightQuotes) {
      return {'quote_highlight': QuoteHighlightBuilder(textColor)};
    }
    return {};
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
      final textOnlyChild =
          node.children.length == 1 && node.children.first is XmlText;
      final textContent = node.value?.trim() ?? '';

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

  /// 根据XML规则递归地解析和渲染文本内容。
  /// 此方法通过查找成对的顶层XML标签来分块处理文本。
  /// 无效或未闭合的XML内容将被当作纯文本处理。
  List<Widget> _renderTextContent(
    BuildContext context,
    String textContent,
    List<XmlRule> rules,
    Color textColor,
    bool isStreaming,
  ) {
    final List<Widget> widgets = [];
    var remainingText = textContent.trim();

    // 优化：如果文本不包含任何可能的XML标记，则直接作为Markdown渲染。
    if (!remainingText.contains('<')) {
      if (remainingText.isEmpty) return [];
      return [
        MarkdownBody(
          data: remainingText.replaceAll('\n', '  \n'),
          selectable: false,
          styleSheet: _getMarkdownStyleSheet(context, textColor),
          inlineSyntaxes: _getMarkdownInlineSyntaxes(),
          builders: _getMarkdownBuilders(textColor),
          onTapLink: _onTapLink,
        ),
      ];
    }

    final knownTagNames =
        rules.map((r) => r.tagName).whereNotNull().join('|');
    if (knownTagNames.isEmpty) {
      // 如果没有规则，则全部视为Markdown
      return [
        MarkdownBody(
          data: remainingText.replaceAll('\n', '  \n'),
          selectable: false,
          styleSheet: _getMarkdownStyleSheet(context, textColor),
          inlineSyntaxes: _getMarkdownInlineSyntaxes(),
          builders: _getMarkdownBuilders(textColor),
          onTapLink: _onTapLink,
        ),
      ];
    }

    // 正则表达式，用于查找任何已知标签（开始、结束或自闭合）。
    final tagRegex = RegExp(
      r'<\s*(\/?)\s*(' + knownTagNames + r')\b[^>]*?(\/?)>',
      caseSensitive: false,
      dotAll: true,
    );

    while (remainingText.isNotEmpty) {
      final firstMatch = tagRegex.firstMatch(remainingText);

      if (firstMatch == null) {
        // 剩余文本中没有更多已知标签，全部作为Markdown处理。
        if (remainingText.isNotEmpty) {
          widgets.add(MarkdownBody(
            data: remainingText.replaceAll('\n', '  \n'),
            selectable: false,
            styleSheet: _getMarkdownStyleSheet(context, textColor),
            inlineSyntaxes: _getMarkdownInlineSyntaxes(),
            builders: _getMarkdownBuilders(textColor),
            onTapLink: _onTapLink,
          ));
        }
        break;
      }

      final isClosingTag = firstMatch.group(1) == '/';
      final tagName = firstMatch.group(2)!;
      final isSelfClosing = firstMatch.group(3) == '/';

      // 处理第一个匹配项之前的文本
      final precedingText = remainingText.substring(0, firstMatch.start);
      if (precedingText.isNotEmpty) {
        widgets.addAll(_renderTextContent(
            context, precedingText, rules, textColor, isStreaming));
      }

      if (isClosingTag || isSelfClosing) {
        // 发现一个独立的闭合标签或自闭合标签，将其视为纯文本。
        widgets.add(MarkdownBody(
          data: firstMatch.group(0)!.replaceAll('\n', '  \n'),
          selectable: false,
          styleSheet: _getMarkdownStyleSheet(context, textColor),
          inlineSyntaxes: _getMarkdownInlineSyntaxes(),
          builders: _getMarkdownBuilders(textColor),
          onTapLink: _onTapLink,
        ));
        remainingText = remainingText.substring(firstMatch.end);
        continue;
      }

      // 这是一个开始标签。现在查找与之匹配的结束标签。
      final tagStack = [tagName];
      int searchIndex = firstMatch.end;
      Match? endMatch;

      while (tagStack.isNotEmpty && searchIndex < remainingText.length) {
        final nextMatch = tagRegex.firstMatch(remainingText.substring(searchIndex));
        if (nextMatch == null) {
          // 没有更多标签了，无法闭合
          break;
        }

        final nextIsClosing = nextMatch.group(1) == '/';
        final nextTagName = nextMatch.group(2)!;
        final nextIsSelfClosing = nextMatch.group(3) == '/';
        
        if (nextTagName == tagName && !nextIsSelfClosing) {
          if (nextIsClosing) {
            tagStack.removeLast();
            if (tagStack.isEmpty) {
              endMatch = nextMatch;
            }
          } else {
            tagStack.add(nextTagName);
          }
        }
        searchIndex += nextMatch.end;
      }

      if (endMatch != null) {
        // 找到了成对的标签
        final contentStart = firstMatch.end;
        final contentEnd = searchIndex - endMatch.group(0)!.length;
        final innerContent = remainingText.substring(contentStart, contentEnd);

        final rule = rules.firstWhereOrNull(
          (r) => r.tagName?.toLowerCase() == tagName.toLowerCase(),
        );

        if (rule?.action == XmlAction.content) {
          widgets.addAll(_renderTextContent(
              context, innerContent, rules, textColor, isStreaming));
        } else {
          widgets.add(
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: isStreaming,
                tilePadding: EdgeInsets.zero,
                title: Text(
                  tagName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _renderTextContent(
                          context, innerContent, rules, textColor, isStreaming),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        remainingText = remainingText.substring(searchIndex);
      } else {
        // 未找到匹配的结束标签
        if (isStreaming) {
          // 在流式传输中，将未闭合的标签渲染为展开的Tile
          final innerContent = remainingText.substring(firstMatch.end);
          widgets.add(
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                title: Text(
                  tagName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _renderTextContent(
                          context, innerContent, rules, textColor, isStreaming),
                    ),
                  ),
                ],
              ),
            ),
          );
          break; // 渲染完这个流式标签后，终止循环
        } else {
          // 非流式传输，将开始标签和之后的所有内容视为纯文本
          widgets.add(MarkdownBody(
            data: remainingText.replaceAll('\n', '  \n'),
            selectable: false,
            styleSheet: _getMarkdownStyleSheet(context, textColor),
            inlineSyntaxes: _getMarkdownInlineSyntaxes(),
            builders: _getMarkdownBuilders(textColor),
            onTapLink: _onTapLink,
          ));
          break;
        }
      }
    }
    return widgets;
  }

  Widget _buildTextPart(
    BuildContext context,
    Color textColor,
    bool isUser,
    bool isStreaming,
  ) {
    final textContent = message.modelsText.isEmpty && isStreaming && !isUser
        ? "..."
        : message.modelsText;

    if (isPseudoStreamMode && !isUser && isLastMessageInList) {
      return _TypewriterText(
        key: ValueKey(message.id), // Ensure widget rebuilds for new messages
        fullText: textContent,
        speed: pseudoStreamSpeed,
        isStreaming: isStreaming,
        textColor: textColor,
        xmlRules: xmlRules, // Pass the XML rules down
        builder: (context, displayedText) {
          final widgets = _renderTextContent(
            context,
            displayedText,
            xmlRules,
            textColor,
            isStreaming,
          );
          if (widgets.isEmpty) return const SizedBox.shrink();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widgets,
          );
        },
      );
    } else {
      final widgets = _renderTextContent(
        context,
        textContent,
        xmlRules,
        textColor,
        isStreaming,
      );
      if (widgets.isEmpty) return const SizedBox.shrink();

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: widgets,
      );
    }
  }

  Widget _buildNonTextPart(
    BuildContext context,
    MessagePart part,
    Color textColor,
  ) {
    switch (part.type) {
      case MessagePartType.image:
      case MessagePartType.generatedImage:
        if (part.base64Data != null) {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: CachedImageFromBase64(
              base64String: part.base64Data!,
              fit: BoxFit.contain,
              cacheHeight: (400 * MediaQuery.of(context).devicePixelRatio)
                  .round(),
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

  Widget _buildMessageContent(
    BuildContext context,
    Color textColor,
    bool isUser,
    bool isStreaming,
  ) {
    final hasText = message.modelsText.isNotEmpty;
    final nonTextParts = message.parts
        .where((p) => p.type != MessagePartType.text)
        .toList();
    final originalXml = message.originalXmlContent;
    final secondaryXml = message.secondaryXmlContent;

    return SelectionArea(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (hasText)
              _buildTextPart(context, textColor, isUser, isStreaming),
            ...nonTextParts.map((part) {
              return Padding(
                padding: const EdgeInsets.only(top: 0),
                child: _buildNonTextPart(context, part, textColor),
              );
            }),
            if (originalXml != null && originalXml.isNotEmpty)
              _buildXmlExpansionTile(
                context,
                '原生XML内容',
                originalXml,
                textColor,
                isStreaming,
                MessagePartType.text,
              ),
            if (secondaryXml != null && secondaryXml.isNotEmpty)
              _buildXmlExpansionTile(
                context,
                '再生XML内容',
                secondaryXml,
                textColor,
                isStreaming,
                MessagePartType.text,
              ),
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

  Widget _buildXmlExpansionTile(
    BuildContext context,
    String title,
    String xmlContent,
    Color textColor,
    bool isStreaming,
    MessagePartType partType,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: isStreaming,
        tilePadding: EdgeInsets.zero,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor.withAlpha((255 * 0.7).round()),
            fontSize: 12,
          ),
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
                  styleSheet: _getMarkdownStyleSheet(
                    context,
                    textColor.withAlpha((255 * 0.85).round()),
                  ),
                  inlineSyntaxes: _getMarkdownInlineSyntaxes(),
                  builders: _getMarkdownBuilders(
                    textColor.withAlpha((255 * 0.85).round()),
                  ),
                  onTapLink: _onTapLink,
                );
              } catch (e) {
                // 如果解析失败，则回退到原始的代码块显示
                return MarkdownBody(
                  data: '```xml\n$xmlContent\n```',
                  selectable: false,
                  styleSheet: _getMarkdownStyleSheet(context, textColor),
                  inlineSyntaxes: _getMarkdownInlineSyntaxes(),
                  builders: _getMarkdownBuilders(textColor),
                  onTapLink: _onTapLink,
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
      child: IntrinsicWidth(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isHalfWidth ? screenWidth * 2 / 3 : screenWidth,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withAlpha((255 * 0.2).round()),
                width: 0.8,
              ),
            ),
            color: color,
            elevation: 0,
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight:
                      24, // Ensure a minimum tappable height for empty messages
                  minWidth:
                      48, // Ensure a minimum tappable width for empty messages
                ),
                child: _buildMessageContent(
                  context,
                  textColor,
                  isUser,
                  isStreaming,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (isUser && carriedOverXml != null && carriedOverXml!.isNotEmpty) {
      final xmlBubble = Align(
        alignment: alignment,
        child: IntrinsicWidth(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isHalfWidth ? screenWidth * 2 / 3 : screenWidth,
            ),
            margin: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 4.0),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withAlpha((255 * 0.1).round()),
                  width: 0.8,
                ),
              ),
              color: color.withAlpha(180),
              elevation: 0,
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: _buildXmlExpansionTile(
                  context,
                  '合成XML',
                  carriedOverXml!,
                  textColor,
                  isStreaming,
                  MessagePartType.text,
                ),
              ),
            ),
          ),
        ),
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [xmlBubble, messageCard],
      );
    }

    return messageCard;
  }
}

// Helper class to hold segments of text for typewriter animation.
class _TextSegment {
  final String content;
  final bool isInstant; // True if the segment should appear instantly.

  _TextSegment(this.content, {this.isInstant = false});
}

class _TypewriterText extends StatefulWidget {
  final String fullText;
  final double speed;
  final bool isStreaming;
  final Color textColor;
  final List<XmlRule> xmlRules; // Add xmlRules
  final Widget Function(BuildContext, String) builder;

  const _TypewriterText({
    super.key,
    required this.fullText,
    required this.speed,
    required this.isStreaming,
    required this.textColor,
    required this.xmlRules, // Add xmlRules
    required this.builder,
  });

  @override
  _TypewriterTextState createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText>
    with SingleTickerProviderStateMixin {
  String _displayedText = "";
  Timer? _timer;

  List<_TextSegment> _segments = [];
  int _segmentIndex = 0;
  int _charIndex = 0;
  bool _wasInstant = false; // Tracks if the last state was instant display

  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;


  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _updateText();
  }

  @override
  void didUpdateWidget(_TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fullText != oldWidget.fullText ||
        widget.speed != oldWidget.speed) {
      _updateText();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  /// Determines if the text contains an unclosed collapsible component.
  bool _hasUnclosedComponent(String text) {
    if ((text.split('```').length - 1) % 2 != 0) {
      return true;
    }
    final tagStack = <String>[];
    final tagRegex = RegExp(r'<(/?)(\w+)[^>]*?>');
    for (final match in tagRegex.allMatches(text)) {
      if (text.substring(match.start, match.end).endsWith('/>')) {
        continue; // Skip self-closing tags
      }
      final isClosing = match.group(1) == '/';
      final tagName = match.group(2)!;
      if (isClosing) {
        if (tagStack.isNotEmpty && tagStack.last == tagName) {
          tagStack.removeLast();
        }
      } else {
        tagStack.add(tagName);
      }
    }
    return tagStack.isNotEmpty;
  }

  /// Central logic to decide whether to animate or display instantly.
  void _updateText() {
    bool isInstantNow = _hasUnclosedComponent(widget.fullText);

    if (isInstantNow) {
      _timer?.cancel();
      if (_displayedText != widget.fullText) {
        setState(() => _displayedText = widget.fullText);
      }
    } else {
      if (_wasInstant || !widget.fullText.startsWith(_displayedText)) {
        _resetAndStartAnimation();
      } else {
        _continueAnimation();
      }
    }
    _wasInstant = isInstantNow;
  }

  List<_TextSegment> _segmentText(String text) {
    final segments = <_TextSegment>[];
    if (text.isEmpty) return segments;

    final combinedRegex = RegExp(
      r'(```[\s\S]*?```)|(<(\w+)[^>]*>[\s\S]*?</\3>)|(<[^>]+>)',
      multiLine: true,
    );

    int lastMatchEnd = 0;

    for (final match in combinedRegex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        segments.add(_TextSegment(text.substring(lastMatchEnd, match.start)));
      }

      final codeBlock = match.group(1);
      final xmlBlock = match.group(2);
      final singleXmlTag = match.group(4);

      if (codeBlock != null) {
        segments.add(_TextSegment(codeBlock, isInstant: true));
      } else if (xmlBlock != null) {
        final tagName = match.group(3)!.toLowerCase();
        final rule = widget.xmlRules.firstWhereOrNull(
          (r) => r.tagName?.toLowerCase() == tagName,
        );

        if (rule?.action == XmlAction.content) {
          final startTagMatch = RegExp(r'^<[^>]+>').firstMatch(xmlBlock)!;
          final endTagMatch = RegExp(r'</[^>]+>$').firstMatch(xmlBlock)!;
          final startTag = startTagMatch.group(0)!;
          final endTag = endTagMatch.group(0)!;
          final content = xmlBlock.substring(startTagMatch.end, endTagMatch.start);

          segments.add(_TextSegment(startTag, isInstant: true));
          segments.addAll(_segmentText(content)); // Safe recursive call
          segments.add(_TextSegment(endTag, isInstant: true));
        } else {
          segments.add(_TextSegment(xmlBlock, isInstant: true));
        }
      } else if (singleXmlTag != null) {
        segments.add(_TextSegment(singleXmlTag, isInstant: true));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      segments.add(_TextSegment(text.substring(lastMatchEnd)));
    }
    return segments;
  }

  String _buildDisplayedText() {
    if (_wasInstant) return _displayedText;
    final buffer = StringBuffer();
    for (int i = 0; i < _segmentIndex; i++) {
      if (i < _segments.length) buffer.write(_segments[i].content);
    }
    if (_segmentIndex < _segments.length && !_segments[_segmentIndex].isInstant) {
      buffer.write(_segments[_segmentIndex].content.substring(0, _charIndex));
    }
    return buffer.toString();
  }

  void _restoreAnimationState() {
    int len = _displayedText.length;
    int cumulativeLen = 0;
    for (int i = 0; i < _segments.length; i++) {
      final segment = _segments[i];
      final segmentLen = segment.content.length;
      if (cumulativeLen + segmentLen >= len) {
        _segmentIndex = i;
        _charIndex = len - cumulativeLen;
        return;
      }
      cumulativeLen += segmentLen;
    }
    _segmentIndex = _segments.length;
    _charIndex = 0;
  }

  void _resetAndStartAnimation() {
    _timer?.cancel();
    _displayedText = "";
    _segmentIndex = 0;
    _charIndex = 0;
    _segments = _segmentText(widget.fullText);
    _startAnimation();
  }

  void _continueAnimation() {
    _timer?.cancel();
    _segments = _segmentText(widget.fullText);
    _restoreAnimationState();
    if (_buildDisplayedText().length >= widget.fullText.length) {
      return;
    }
    _startAnimation();
  }

  void _startAnimation() {
    _timer?.cancel();
    if (_buildDisplayedText().length >= widget.fullText.length) return;

    const baseDelay = 50;
    final delay = (baseDelay / (widget.speed * widget.speed)).clamp(1, 500).toInt();

    _timer = Timer.periodic(Duration(milliseconds: delay), (timer) {
      if (_segmentIndex >= _segments.length) {
        timer.cancel();
        return;
      }

      final currentSegment = _segments[_segmentIndex];
      if (currentSegment.isInstant) {
        _segmentIndex++;
        _charIndex = 0;
      } else {
        if (_charIndex < currentSegment.content.length) {
          _charIndex++;
        } else {
          _segmentIndex++;
          _charIndex = 0;
        }
      }

      final currentBuiltText = _buildDisplayedText();
      setState(() => _displayedText = currentBuiltText);

      if (currentBuiltText.length >= widget.fullText.length) {
        timer.cancel();
      }
    });
  }

  void _skipAnimation() {
    _timer?.cancel();
    if (_displayedText != widget.fullText) {
      setState(() {
        _displayedText = widget.fullText;
        _wasInstant = true; // Skipping is an instant display
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showSkipButton = _displayedText != widget.fullText;
    final builtContent = widget.builder(context, _displayedText);

    if (builtContent is SizedBox && (builtContent.width == 0 || builtContent.height == 0)) {
      return builtContent;
    }

    return Stack(
      children: [
        builtContent,
        if (showSkipButton)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: _skipAnimation,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: Icon(
                  Icons.arrow_drop_down,
                  size: 24,
                  color: widget.textColor.withOpacity(0.6),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
