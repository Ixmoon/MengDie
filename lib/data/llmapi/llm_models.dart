// 本文件定义了与大型语言模型 (LLM) 服务交互时使用的通用、抽象的数据结构。
// 这些结构旨在将核心业务逻辑与特定 LLM API (如 Gemini, OpenAI) 的实现细节解耦。

import 'dart:convert';
import 'package:meta/meta.dart';
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
  final int? messageId; // 新增：用于追踪此内容块的来源消息ID

  const LlmContent(this.role, this.parts, {this.messageId});

  /// 从本地的 Message 对象创建一个 LlmContent 实例。
  factory LlmContent.fromMessage(Message message) {
    final parts = LlmContent.toLlmParts(message.parts);
    final roleString = message.role == MessageRole.user ? 'user' : 'model';
    return LlmContent(roleString, parts, messageId: message.id);
  }

  /// 抽象统一转换：将 MessagePart 列表转换为 LlmPart 列表（支持 text/image/audio/generatedImage/file）
  static List<LlmPart> toLlmParts(List<MessagePart> parts) {
    return parts
        .map((part) {
          switch (part.type) {
            case MessagePartType.text:
              return part.text != null ? LlmTextPart(part.text!) : null;
            case MessagePartType.image:
              return (part.mimeType != null && part.base64Data != null)
                  ? LlmDataPart(part.mimeType!, part.base64Data!)
                  : null;
            case MessagePartType.generatedImage:
              return (part.mimeType != null && part.base64Data != null)
                  ? LlmDataPart(part.mimeType!, part.base64Data!)
                  : null;
            case MessagePartType.audio:
              return (part.mimeType != null && part.base64Data != null)
                  ? LlmAudioPart(part.mimeType!, part.base64Data!)
                  : null;
            case MessagePartType.file:
              // PDF: 直接作为视觉内容传递
              if (part.mimeType == 'application/pdf') {
                if (part.base64Data != null) {
                  // 直接用 base64 传递 PDF 内容
                  return LlmDataPart(part.mimeType!, part.base64Data!);
                }
                return null;
              }
              // 其他文件类型：尝试解析 base64Data 为纯文本
              if (part.base64Data != null && part.base64Data!.isNotEmpty) {
                try {
                  final decoded = utf8.decode(base64.decode(part.base64Data!));
                  if (decoded.isNotEmpty) {
                    return LlmTextPart(decoded);
                  }
                } catch (e) {
                  // 解码失败则跳过
                  return null;
                }
              }
              // 兜底：如果 text 字段有内容则用 text
              if (part.text != null && part.text!.isNotEmpty) {
                return LlmTextPart(part.text!);
              }
              // 解析失败则跳过
              return null;
          }
        })
        .whereType<LlmPart>()
        .toList();
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

/// 表示内容的URL部分
@immutable
class LlmUrlPart extends LlmPart {
  final String url;
  const LlmUrlPart(this.url);
}

/// 表示可执行代码的部分
@immutable
class LlmExecutableCodePart extends LlmPart {
  final String language;
  final String code;
  const LlmExecutableCodePart({required this.language, required this.code});
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
enum LlmStreamChunkType { text, error, finishReason }

@immutable
class LlmStreamChunk {
  final String textChunk;
  final String accumulatedText;
  final bool isFinished;
  final String? error;
  final DateTime timestamp;
  final LlmStreamChunkType type;
  final Map<String, dynamic>? groundingMetadata; // For Gemini grounding

  const LlmStreamChunk({
    required this.textChunk,
    required this.accumulatedText,
    required this.timestamp,
    this.isFinished = false,
    this.error,
    this.type = LlmStreamChunkType.text,
    this.groundingMetadata,
  });

  /// 创建一个错误块。
  factory LlmStreamChunk.error(String message, String accumulatedText) {
    return LlmStreamChunk(
      textChunk: '',
      accumulatedText: accumulatedText,
      error: message,
      isFinished: true,
      timestamp: DateTime.now(),
      type: LlmStreamChunkType.error,
    );
  }

  /// 创建一个表示中断原因的块。
  factory LlmStreamChunk.finishReason(String reason, String accumulatedText) {
    return LlmStreamChunk(
      textChunk: reason, // 将原因放在 textChunk 中以便 UI 显示
      accumulatedText: accumulatedText,
      isFinished: true,
      timestamp: DateTime.now(),
      type: LlmStreamChunkType.finishReason,
    );
  }
}

/// 表示来自 LLM 的单个、完整的响应。
@immutable
class LlmResponse {
  final List<MessagePart> parts;
  final bool isSuccess;
  final String? error;
  final Map<String, dynamic>? groundingMetadata; // For Gemini grounding

  // 为方便访问文本内容而设的 Getter，用于兼容
  String get rawText => parts
      .where((p) => p.type == MessagePartType.text)
      .map((p) => p.text ?? '')
      .join();

  const LlmResponse({
    required this.parts,
    this.isSuccess = true,
    this.error,
    this.groundingMetadata,
  });

  /// 创建一个错误响应。
  const LlmResponse.error(String message)
    : parts = const [],
      isSuccess = false,
      error = message,
      groundingMetadata = null;
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

/// Represents the data structure for a single model returned by the Gemini `/models` endpoint.
@immutable
class GeminiModel {
  final String name; // e.g., "models/gemini-1.5-flash-001"
  final String? displayName;
  final List<String> supportedGenerationMethods;

  const GeminiModel({
    required this.name,
    this.displayName,
    this.supportedGenerationMethods = const [],
  });

  /// Extracts the actual model ID (e.g., "gemini-1.5-flash-001") from the full resource name.
  String get modelId => name.startsWith('models/') ? name.substring(7) : name;

  factory GeminiModel.fromJson(Map<String, dynamic> json) {
    return GeminiModel(
      name: json['name'] ?? '',
      displayName: json['displayName'] as String?,
      supportedGenerationMethods:
          (json['supportedGenerationMethods'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
    );
  }
}
