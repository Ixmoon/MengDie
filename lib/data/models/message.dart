import 'package:flutter/foundation.dart';
import 'enums.dart';
import '../../service/process/xml_processor.dart';

// --- 消息内容部分模型 ---
@immutable
class MessagePart {
  final MessagePartType type;
  final String? text; // For text content
  final String? mimeType; // For image/file content
  final String? base64Data; // For image/file content (base64 encoded)
  final String? fileName; // For file content

  const MessagePart({
    required this.type,
    this.text,
    this.mimeType,
    this.base64Data,
    this.fileName,
  });

  // Factory constructor for text part
  factory MessagePart.text(String text) {
    return MessagePart(type: MessagePartType.text, text: text);
  }

  // Factory constructor for image part
  factory MessagePart.image({required String mimeType, required String base64Data, String? fileName}) {
    return MessagePart(
      type: MessagePartType.image,
      mimeType: mimeType,
      base64Data: base64Data,
      fileName: fileName,
    );
  }

  // Factory constructor for file part
  factory MessagePart.file({required String mimeType, required String base64Data, required String fileName}) {
    return MessagePart(
      type: MessagePartType.file,
      mimeType: mimeType,
      base64Data: base64Data,
      fileName: fileName,
    );
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'text': text,
      'mimeType': mimeType,
      'base64Data': base64Data,
      'fileName': fileName,
    };
  }

  // JSON deserialization
  factory MessagePart.fromJson(Map<String, dynamic> json) {
    final type = MessagePartType.values.byName(json['type']);
    return MessagePart(
      type: type,
      text: json['text'],
      mimeType: json['mimeType'],
      base64Data: json['base64Data'],
      fileName: json['fileName'],
    );
  }
}


// --- 消息模型 ---
@immutable
class Message {
  final int id;
  final int chatId;
  final List<MessagePart> parts;
  final MessageRole role;
  final DateTime timestamp;
  final String? originalXmlContent;
  final String? secondaryXmlContent;
  final String displayText;

  Message({
    this.id = 0,
    required this.chatId,
    required this.parts,
    required this.role,
    DateTime? timestamp,
    this.originalXmlContent,
    this.secondaryXmlContent,
  })  : timestamp = timestamp ?? DateTime.now(),
        displayText = XmlProcessor.stripXmlContent(
            parts.where((p) => p.type == MessagePartType.text).map((p) => p.text ?? '').join('\n'));

  String get rawText {
    return parts.where((p) => p.type == MessagePartType.text).map((p) => p.text).join('\n');
  }

  Message copyWith(Map<String, dynamic> updates) {
    return Message(
      id: updates.containsKey('id') ? updates['id'] : id,
      chatId: updates.containsKey('chatId') ? updates['chatId'] : chatId,
      parts: updates.containsKey('parts') ? updates['parts'] : parts,
      role: updates.containsKey('role') ? updates['role'] : role,
      timestamp: updates.containsKey('timestamp') ? updates['timestamp'] : timestamp,
      originalXmlContent: updates.containsKey('originalXmlContent') ? updates['originalXmlContent'] : originalXmlContent,
      secondaryXmlContent: updates.containsKey('secondaryXmlContent') ? updates['secondaryXmlContent'] : secondaryXmlContent,
    );
  }
}