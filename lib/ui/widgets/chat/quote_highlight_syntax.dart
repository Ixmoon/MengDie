import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_markdown/flutter_markdown.dart';

/// 自定义的 Markdown 语法，用于识别被引号包裹的内容
class QuoteHighlightSyntax extends md.InlineSyntax {
  // 支持中文直角引号（「」）、中英文双引号（“ ” 和 " "），并支持未闭合的情况。
  // 限制为不跨段落（不包含换行），使用非贪婪匹配并添加长度上限（200）。
  QuoteHighlightSyntax()
      : super(r'([“"「])([^\n“”"「」]{0,200})([”"」])?');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final openQuote = match.group(1) ?? '';
    final inner = match.group(2) ?? '';
    final closeQuote = match.group(3) ?? '';

    // 创建自定义元素节点；将内部文本作为属性以便构建器可以读取并渲染。
    final element = md.Element.withTag('quote_highlight');
    element.attributes['open'] = openQuote;
    element.attributes['close'] = closeQuote;
    element.attributes['content'] = inner;
    parser.addNode(element);
    return true;
  }
}

/// 自定义的 Markdown 构建器，用于渲染高亮的引号内容
class QuoteHighlightBuilder extends MarkdownElementBuilder {
  final Color textColor;

  QuoteHighlightBuilder(this.textColor);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final open = element.attributes['open'] ?? '';
    final content = element.attributes['content'] ?? '';
    final close = element.attributes['close'] ?? '';

    // 简单内联 Markdown 解析（支持 **bold** 和 *italic*）以保留常见格式，
    // 同时保证整体内容使用橙黄色前景色。
    TextStyle baseStyle = (preferredStyle ?? const TextStyle()).copyWith(
      color: Colors.orange,
    );

    List<InlineSpan> parseInline(String s) {
      final List<InlineSpan> spans = [];
      int idx = 0;
      final boldRegex = RegExp(r'\*\*(.+?)\*\*');
      final italicRegex = RegExp(r'\*(.+?)\*');

      // 简单实现：先处理 bold，再在剩余文本中处理 italic（对复杂嵌套不保证正确）
      while (true) {
        final m = boldRegex.firstMatch(s.substring(idx));
        if (m == null) {
          // 处理剩余 italic 与普通文本
          String rest = s.substring(idx);
          int lastPos = 0;
          for (final im in italicRegex.allMatches(rest)) {
            if (im.start > lastPos) {
              spans.add(
                TextSpan(
                  text: rest.substring(lastPos, im.start),
                  style: baseStyle,
                ),
              );
            }
            spans.add(
              TextSpan(
                text: im.group(1),
                style: baseStyle.merge(
                  const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            );
            lastPos = im.end;
          }
          if (lastPos < rest.length) {
            spans.add(
              TextSpan(text: rest.substring(lastPos), style: baseStyle),
            );
          }
          break;
        } else {
          final start = idx + m.start;
          final end = idx + m.end;
          if (start > idx) {
            spans.addAll(parseInline(s.substring(idx, start)));
          }
          spans.add(
            TextSpan(
              text: m.group(1),
              style: baseStyle.merge(
                const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
          idx = end;
          if (idx >= s.length) break;
        }
      }
      return spans.isEmpty ? [TextSpan(text: s, style: baseStyle)] : spans;
    }

    final parsedSpans = parseInline(content);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: open, style: preferredStyle),
          ...parsedSpans,
          TextSpan(text: close, style: preferredStyle),
        ],
      ),
    );
  }
}
