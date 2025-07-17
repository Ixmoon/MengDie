// 本文件定义了与大型语言模型 (LLM) 服务交互时使用的通用、抽象的数据结构。
// 这些结构旨在将核心业务逻辑与特定 LLM API (如 Gemini, OpenAI) 的实现细节解耦。

import 'package:flutter/foundation.dart';

// 导入本地数据模型，例如用于数据转换的 Message 和 MessagePart
import '../../domain/models/models.dart';

// --- 通用 LLM 数据结构 ---
// 这些结构抽象了底层 LLM API 的具体细节 (例如 Gemini)。

/// 表示发送到或从 LLM 接收的一段内容。
/// 相当于 genai.Content
@immutable
class LlmContent {
  final String role; // 例如, "user", "model", "system"
  final List<LlmPart> parts;

  const LlmContent(this.role, this.parts);

  /// 从本地的 Message 对象创建一个 LlmContent 实例。
  factory LlmContent.fromMessage(Message message) {
    final parts = message.parts.map((part) {
      switch (part.type) {
        case MessagePartType.text:
          return LlmTextPart(part.text!);
        case MessagePartType.image:
          return LlmDataPart(part.mimeType!, part.base64Data!);
        case MessagePartType.audio:
          return LlmAudioPart(part.mimeType!, part.base64Data!);
        case MessagePartType.file:
           // 假设未来 MessagePart 会包含 fileUri
           // if (part.fileUri != null) {
           //   return LlmFilePart(part.mimeType!, part.fileUri!);
           // }
           return null; // 当前暂时忽略
        case MessagePartType.generatedImage:
          // 将生成的图片作为多模态上下文的一部分发送给 LLM。
          // 这与处理用户上传的图片（MessagePartType.image）行为一致。
          return LlmDataPart(part.mimeType!, part.base64Data!);
      }
    }).whereType<LlmPart>().toList(); // 使用 whereType 过滤掉 null

    // 将本地的 MessageRole 转换为 API 期望的字符串角色 ("user" 或 "model")
    final roleString = message.role == MessageRole.user ? 'user' : 'model';
    
    return LlmContent(roleString, parts);
  }
}

/// 不同类型内容部分 (文本、图片等) 的基类。
/// 相当于 genai.Part
@immutable
abstract class LlmPart {
  const LlmPart();
}

/// 表示内容的文本部分。
/// 相当于 genai.TextPart
@immutable
class LlmTextPart extends LlmPart {
  final String text;
  const LlmTextPart(this.text);
}

/// 表示内容的数据部分 (例如，一张图片)。
/// 相当于 genai.DataPart
@immutable
class LlmDataPart extends LlmPart {
  final String mimeType;
  final String base64Data; // 保持为 base64 字符串以保持一致性
  const LlmDataPart(this.mimeType, this.base64Data);
}

/// 表示内容的音频部分。
/// 相当于 OpenAI 的 "input_audio"
@immutable
class LlmAudioPart extends LlmPart {
  final String mimeType;
  final String base64Data;
  const LlmAudioPart(this.mimeType, this.base64Data);
}

/// 表示通过 File API 上传的文件部分。
/// 相当于 genai.FilePart
@immutable
class LlmFilePart extends LlmPart {
  final String mimeType;
  final String fileUri; // The URI returned by the File API
  const LlmFilePart(this.mimeType, this.fileUri);
}


/// 表示 LLM 的通用安全设置。
/// 相当于 genai.SafetySetting
@immutable
class LlmSafetySetting {
  final LocalHarmCategory category; // 使用本地枚举
  final LocalHarmBlockThreshold threshold; // 使用本地枚举

  const LlmSafetySetting(this.category, this.threshold);
}

/// 表示 LLM 的通用生成配置。
/// 相当于 genai.GenerationConfig
@immutable
class LlmGenerationConfig {
  final double? temperature;
  final double? topP;
  final int? topK;
  final int? maxOutputTokens;
  final List<String>? stopSequences;

  const LlmGenerationConfig({
    this.temperature,
    this.topP,
    this.topK,
    this.maxOutputTokens,
    this.stopSequences,
  });
}


/// 表示来自 LLM 的流式响应的一个块。
@immutable
class LlmStreamChunk {
  final String textChunk;
  final String accumulatedText;
  final bool isFinished;
  final String? error;
  final DateTime timestamp;

  const LlmStreamChunk({
    required this.textChunk,
    required this.accumulatedText,
    required this.timestamp,
    this.isFinished = false,
    this.error,
  });

  /// 创建一个错误块。
  factory LlmStreamChunk.error(String message, String accumulatedText) {
    return LlmStreamChunk(
      textChunk: '',
      accumulatedText: accumulatedText,
      error: message,
      isFinished: true,
      timestamp: DateTime.now(),
    );
  }
}

/// 表示来自 LLM 的单个、完整的响应。
@immutable
class LlmResponse {
  final List<MessagePart> parts;
  final bool isSuccess;
  final String? error;

  // 为方便访问文本内容而设的 Getter，用于兼容
  String get rawText => parts.where((p) => p.type == MessagePartType.text).map((p) => p.text ?? '').join();

  const LlmResponse({
    required this.parts,
    this.isSuccess = true,
    this.error,
  });

  /// 创建一个错误响应。
  const LlmResponse.error(String message) :
    parts = const [],
    isSuccess = false,
    error = message;
}

// --- Provider-Specific Models ---

/// Represents the data structure for a single model returned by the OpenAI `/models` endpoint.
@immutable
class OpenAIModel {
final String id;
final String object;
final int created;
final String ownedBy;

const OpenAIModel({
required this.id,
required this.object,
required this.created,
required this.ownedBy,
});

factory OpenAIModel.fromJson(Map<String, dynamic> json) {
return OpenAIModel(
  id: json['id'] ?? '',
  object: json['object'] ?? '',
  created: json['created'] ?? 0,
  ownedBy: json['owned_by'] ?? '',
);
}
}

/// 表示图像生成请求的响应。
@immutable
class LlmImageResponse {
  final List<String> base64Images; // A list of base64 encoded image strings
  final String? text; // Add a field for the text response
  final bool isSuccess;
  final String? error;

  const LlmImageResponse({
    this.base64Images = const [],
    this.text,
    this.isSuccess = true,
    this.error,
  });

  const LlmImageResponse.error(String message)
      : base64Images = const [],
        text = null,
        isSuccess = false,
        error = message;
}