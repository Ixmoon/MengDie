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

  /// 根据XML规则解析并渲染文本内容为一系列Widget。
  /// 此方法通过清理、高亮错误和自动闭合未完成的标签来健壮地支持流式传输。
  List<Widget> _renderTextContent(
    BuildContext context,
    String textContent,
    List<XmlRule> rules,
    Color textColor,
    bool isStreaming,
  ) {
    var inputText = textContent.trim();
    if (!inputText.contains('<') && !inputText.contains('```')) {
      if (inputText.isEmpty) return [];
      final mdData = inputText.replaceAll('\n', '  \n');
      return [
        MarkdownBody(
          data: mdData,
          selectable: false,
          styleSheet: _getMarkdownStyleSheet(context, textColor),
          inlineSyntaxes: _getMarkdownInlineSyntaxes(),
          builders: _getMarkdownBuilders(textColor),
          onTapLink: _onTapLink,
        ),
      ];
    }

    const errorStartMarker = '__{{XML_ERROR_START}}__';
    const errorEndMarker = '__{{XML_ERROR_END}}__';

    // --- 步骤 1: 隔离流式传输中末尾的不完整标签 ---
    String stableText = inputText;
    String? partialTag;
    final lastLt = inputText.lastIndexOf('<');
    if (lastLt != -1 && inputText.lastIndexOf('>') < lastLt) {
      stableText = inputText.substring(0, lastLt);
      partialTag = inputText.substring(lastLt);
    }

    // --- 步骤 2: 对稳定部分进行清理、标记错误和自动闭合 ---
    final tagStack = <String>[];
    final generalTagRegex = RegExp(r'<[^>]*>');
    final validTagStructureRegex = RegExp(r"^<(/)?(\w+)([^>]*?)(\/)?>$");
    final cleanedBuffer = StringBuffer();
    int lastIndex = 0;

    for (final match in generalTagRegex.allMatches(stableText)) {
      cleanedBuffer.write(stableText.substring(lastIndex, match.start));
      lastIndex = match.end;

      final tagString = match.group(0)!;
      final validationMatch = validTagStructureRegex.firstMatch(tagString);

      if (validationMatch != null) {
        final isClosingTag = validationMatch.group(1) == '/';
        final tagName = validationMatch.group(2)!;
        final isSelfClosing = validationMatch.group(4) == '/';

        if (isClosingTag) {
          if (tagStack.isNotEmpty && tagStack.last == tagName) {
            tagStack.removeLast();
            cleanedBuffer.write(tagString);
          } else {
            final escapedTag = tagString
                .replaceAll('<', '<')
                .replaceAll('>', '>');
            cleanedBuffer.write('$errorStartMarker$escapedTag$errorEndMarker');
          }
        } else if (isSelfClosing) {
          cleanedBuffer.write(tagString);
        } else {
          tagStack.add(tagName);
          cleanedBuffer.write(tagString);
        }
      } else {
        final escapedTag = tagString.replaceAll('<', '<').replaceAll('>', '>');
        cleanedBuffer.write('$errorStartMarker$escapedTag$errorEndMarker');
      }
    }
    cleanedBuffer.write(stableText.substring(lastIndex));

    var processedText = cleanedBuffer.toString();

    if (tagStack.isNotEmpty) {
      processedText += tagStack.reversed.map((tag) => '</$tag>').join('');
    }

    // --- 步骤 3: 解析和渲染 ---
    try {
      final document = XmlDocument.parse('<root>$processedText</root>');
      final List<Widget> widgets = [];

      for (final node in document.rootElement.children) {
        if (node is XmlText) {
          widgets.addAll(
            _buildTextWidgetsWithErrors(
              context,
              node.value,
              textColor,
              errorStartMarker,
              errorEndMarker,
              isStreaming,
            ),
          );
        } else if (node is XmlElement) {
          final tagNameLower = node.name.local.toLowerCase();
          final rule = rules.firstWhereOrNull(
            (r) => r.tagName?.toLowerCase() == tagNameLower,
          );

          if (rule?.action == XmlAction.content) {
            widgets.addAll(
              _renderTextContent(
                context,
                node.innerXml,
                rules,
                textColor,
                isStreaming,
              ),
            );
          } else {
            final markdownContent = node.children
                .map((child) => _buildMarkdownFromXmlNode(child, 0))
                .join();
            if (markdownContent.trim().isNotEmpty) {
              widgets.add(
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: isStreaming,
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      node.name.local,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 14,
                      ),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: () {
                          final mdData = markdownContent;
                          return MarkdownBody(
                            data: mdData,
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
                        }(),
                      ),
                    ],
                  ),
                ),
              );
            }
          }
        }
      }

      // --- 步骤 4: 追加之前隔离的不完整标签作为普通文本 ---
      if (partialTag != null) {
        widgets.add(
          Text(
            partialTag,
            style: TextStyle(
              color: textColor.withAlpha((255 * 0.7).round()),
            ), // 以稍浅的颜色显示
          ),
        );
      }

      return widgets;
    } catch (e) {
      final fallbackWidgets = _buildTextWidgetsWithErrors(
        context,
        processedText,
        textColor,
        errorStartMarker,
        errorEndMarker,
        isStreaming,
      );
      if (partialTag != null) {
        fallbackWidgets.add(
          Text(
            partialTag,
            style: TextStyle(color: textColor.withAlpha((255 * 0.7).round())),
          ),
        );
      }
      return fallbackWidgets;
    }
  }

  /// 将可能包含错误标记和代码块的文本构建成一个Widget列表。
  List<Widget> _buildTextWidgetsWithErrors(
    BuildContext context,
    String text,
    Color textColor,
    String errorStartMarker,
    String errorEndMarker,
    bool isStreaming,
  ) {
    final List<Widget> widgets = [];
    final codeBlockRegex = RegExp(r'```(\w*)((?:\s*\n)?[\s\S]*?)```');
    int lastIndex = 0;

    for (final match in codeBlockRegex.allMatches(text)) {
      // 1. 处理代码块之前的部分
      if (match.start > lastIndex) {
        final precedingText = text.substring(lastIndex, match.start);
        widgets.addAll(
          _splitTextByErrors(
            context,
            precedingText,
            textColor,
            errorStartMarker,
            errorEndMarker,
          ),
        );
      }

      // 2. 添加代码块本身
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
                fontSize: 14,
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: MarkdownBody(
                  data: codeBlockContent,
                  selectable: false,
                  styleSheet: _getMarkdownStyleSheet(
                    context,
                    textColor.withAlpha((255 * 0.85).round()),
                  ),
                  onTapLink: _onTapLink,
                ),
              ),
            ],
          ),
        ),
      );
      lastIndex = match.end;
    }

    // 3. 处理最后一个代码块之后的部分
    if (lastIndex < text.length) {
      final remainingText = text.substring(lastIndex);
      widgets.addAll(
        _splitTextByErrors(
          context,
          remainingText,
          textColor,
          errorStartMarker,
          errorEndMarker,
        ),
      );
    }

    return widgets;
  }

  /// 将纯文本（无代码块）按错误标记分割成Markdown和高亮Text Widget。
  List<Widget> _splitTextByErrors(
    BuildContext context,
    String text,
    Color textColor,
    String errorStartMarker,
    String errorEndMarker,
  ) {
    final List<Widget> widgets = [];
    final errorRegex = RegExp(
      RegExp.escape(errorStartMarker) +
          r'(.*?)' +
          RegExp.escape(errorEndMarker),
      dotAll: true,
    );
    int lastIndex = 0;

    for (final match in errorRegex.allMatches(text)) {
      // 添加错误之前的部分
      if (match.start > lastIndex) {
        final normalPart = text.substring(lastIndex, match.start).trim();
        if (normalPart.isNotEmpty) {
          final mdData = normalPart.replaceAll('\n', '  \n');
          widgets.add(
            MarkdownBody(
              data: mdData,
              selectable: false,
              styleSheet: _getMarkdownStyleSheet(context, textColor),
              inlineSyntaxes: _getMarkdownInlineSyntaxes(),
              builders: _getMarkdownBuilders(textColor),
              onTapLink: _onTapLink,
            ),
          );
        }
      }
      // 添加高亮显示的错误部分
      final errorPart = match.group(1) ?? '';
      if (errorPart.isNotEmpty) {
        widgets.add(
          Text(
            errorPart,
            style: TextStyle(
              color: Colors.orange, // 错误高亮颜色
              backgroundColor: Colors.orange.withAlpha((255 * 0.15).round()),
              fontFamily: 'monospace',
            ),
          ),
        );
      }
      lastIndex = match.end;
    }

    // 添加最后一个错误之后的部分
    if (lastIndex < text.length) {
      final remainingPart = text.substring(lastIndex).trim();
      if (remainingPart.isNotEmpty) {
        final mdData = remainingPart.replaceAll('\n', '  \n');
        widgets.add(
          MarkdownBody(
            data: mdData,
            selectable: false,
            styleSheet: _getMarkdownStyleSheet(context, textColor),
            inlineSyntaxes: _getMarkdownInlineSyntaxes(),
            builders: _getMarkdownBuilders(textColor),
            onTapLink: _onTapLink,
          ),
        );
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

class _TypewriterText extends StatefulWidget {
  final String fullText;
  final double speed;
  final bool isStreaming;
  final Color textColor;
  final Widget Function(BuildContext, String) builder;

  const _TypewriterText({
    super.key,
    required this.fullText,
    required this.speed,
    required this.isStreaming,
    required this.textColor,
    required this.builder,
  });

  @override
  _TypewriterTextState createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText>
    with SingleTickerProviderStateMixin {
  String _displayedText = "";
  Timer? _timer;
  int _charIndex = 0;

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

    _startAnimation();
  }

  @override
  void didUpdateWidget(_TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the text or speed changes, restart the timer to continue animating.
    // This handles both incoming new text during streaming and the final text after streaming ends.
    if (widget.fullText != oldWidget.fullText ||
        widget.speed != oldWidget.speed) {
      _startAnimation();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startAnimation() {
    _timer?.cancel();
    if (_charIndex >= widget.fullText.length) {
      // Already displayed everything
      if (_displayedText != widget.fullText) {
        setState(() {
          _displayedText = widget.fullText;
        });
      }
      return;
    }

    const baseDelay = 50; // Milliseconds per character at 1x speed
    final delay = (baseDelay / (widget.speed * widget.speed)).clamp(1, 500).toInt();

    _timer = Timer.periodic(Duration(milliseconds: delay), (timer) {
      if (_charIndex < widget.fullText.length) {
        _charIndex++;
        setState(() {
          _displayedText = widget.fullText.substring(0, _charIndex);
        });
      } else {
        timer.cancel();
        // If it's not a streaming message, ensure the final full text is displayed
        // in case of any timing discrepancies.
        if (!widget.isStreaming && _displayedText != widget.fullText) {
          setState(() {
            _displayedText = widget.fullText;
          });
        }
      }
    });
  }

  void _skipAnimation() {
    _timer?.cancel();
    if (_displayedText != widget.fullText) {
      setState(() {
        _charIndex = widget.fullText.length;
        _displayedText = widget.fullText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showSkipButton = _charIndex < widget.fullText.length;
    final builtContent = widget.builder(context, _displayedText);

    // Avoid showing the button on an empty placeholder
    if (builtContent is SizedBox &&
        (builtContent.width == 0 || builtContent.height == 0)) {
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
