import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import '../enums.dart';
import '../../app/tools/xml_processor.dart';

part 'message.g.dart';

// --- 消息内容部分模型 ---
@JsonSerializable()
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

  // Factory constructor for audio part
  factory MessagePart.audio({required String mimeType, required String base64Data, required String fileName}) {
    return MessagePart(
      type: MessagePartType.audio,
      mimeType: mimeType,
      base64Data: base64Data,
      fileName: fileName,
    );
  }

  // Factory constructor for a generated image part
  factory MessagePart.generatedImage({required String base64Data, String? prompt}) {
    // Generated images are typically PNG, but we store them as base64.
    // The 'prompt' can be stored in the 'text' field for convenience.
    return MessagePart(
      type: MessagePartType.generatedImage,
      mimeType: 'image/png', // Assuming PNG format for generated images
      base64Data: base64Data,
      text: prompt, // Use text field to store the prompt
    );
  }

  factory MessagePart.fromJson(Map<String, dynamic> json) => _$MessagePartFromJson(json);

  Map<String, dynamic> toJson() => _$MessagePartToJson(this);
}


// --- 消息模型 ---
@JsonSerializable(explicitToJson: true)
@immutable
class Message {
  final int id;
  final int chatId;
  final List<MessagePart> parts;
  final MessageRole role;
  final DateTime timestamp;
  final DateTime? updatedAt;
  final String? originalXmlContent;
  final String? secondaryXmlContent;
  final String displayText;

  Message({
    this.id = 0,
    required this.chatId,
    required this.parts,
    required this.role,
    DateTime? timestamp,
    this.updatedAt,
    this.originalXmlContent,
    this.secondaryXmlContent,
  })  : timestamp = timestamp ?? DateTime.now(),
        displayText = XmlProcessor.stripXmlContent(
            parts.where((p) => p.type == MessagePartType.text).map((p) => p.text ?? '').join('\n'));

  String get rawText {
    return parts.where((p) => p.type == MessagePartType.text).map((p) => p.text ?? '').join('\n');
  }

  Message copyWith({
    int? id,
    int? chatId,
    List<MessagePart>? parts,
    MessageRole? role,
    DateTime? timestamp,
    DateTime? updatedAt,
    String? originalXmlContent,
    String? secondaryXmlContent,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      parts: parts ?? this.parts,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      updatedAt: updatedAt ?? this.updatedAt,
      originalXmlContent: originalXmlContent ?? this.originalXmlContent,
      secondaryXmlContent: secondaryXmlContent ?? this.secondaryXmlContent,
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);

  Map<String, dynamic> toJson() => _$MessageToJson(this);
}