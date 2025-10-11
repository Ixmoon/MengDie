import '../../domain/models/models.dart';
import '../../app/tools/xml_processor.dart';

/// 根据消息和聊天设置，生成统一的预览文本。
String generatePreviewText(Message? message, Chat chat) {
  if (message == null) {
    return chat.isTemplate ? '模板' : '';
  }
  // 1. 首先根据规则剔除被忽略的XML内容 (此步仍需处理全文以保证逻辑正确)
  final filteredText = XmlProcessor.stripIgnoredXmlContent(
    message.modelsText,
    chat.xmlRules,
  );

  // 2. 性能优化：初步截取一个合理的长度用于后续处理，避免处理超长文本
  const int preliminaryLength = 200;
  final truncatedText = filteredText.length > preliminaryLength
      ? filteredText.substring(0, preliminaryLength)
      : filteredText;

  // 3. 在短字符串上进行清理：移除所有剩余XML标签，并将所有连续的空白（包括换行）替换为单个空格
  final previewText = XmlProcessor.stripXmlContent(
    truncatedText,
  ).replaceAll(RegExp(r'\s+'), ' ').trim();

  if (previewText.isEmpty && chat.isTemplate) {
    return '模板';
  }
  return previewText;
}
