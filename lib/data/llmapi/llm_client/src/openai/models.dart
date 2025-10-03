// lib/src/openai/models.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// 模仿 `dart_openai` 库的公共数据模型。
library;

/// 表示聊天消息的角色。
enum OpenAIChatMessageRole {
  system,
  user,
  assistant,
  tool, // [新增]
}

/// 表示聊天补全请求中的一条消息。
class OpenAIChatCompletionChoiceMessageModel {
  final OpenAIChatMessageRole role;
  // [修改] 将 content 定义为更通用的 dynamic
  final dynamic content;
  final String? toolCallId; // [新增]
  final List<OpenAIToolCall>? toolCalls; // [新增]

  OpenAIChatCompletionChoiceMessageModel({
    required this.role,
    this.content,
    this.toolCallId,
    this.toolCalls,
  });
}

/// 聊天消息内容的基类。
abstract class OpenAIChatCompletionChoiceMessageContentItemModel {
  const OpenAIChatCompletionChoiceMessageContentItemModel();

  /// 一个方便的工厂构造函数，用于创建文本内容。
  factory OpenAIChatCompletionChoiceMessageContentItemModel.text(String text) {
    return OpenAITextMessageContent(text);
  }
}

/// 聊天消息的文本内容部分。
class OpenAITextMessageContent
    extends OpenAIChatCompletionChoiceMessageContentItemModel {
  final String text;
  const OpenAITextMessageContent(this.text);
}

// [新增] 聊天消息的图片内容部分
class OpenAIImageUrlMessageContent
    extends OpenAIChatCompletionChoiceMessageContentItemModel {
  final String url;
  const OpenAIImageUrlMessageContent(this.url);
}

/// 代表一个工具调用结果的消息内容部分。
class OpenAIToolCallMessageContentItemModel
    extends OpenAIChatCompletionChoiceMessageContentItemModel {
  final List<OpenAIToolCall> toolCalls;
  const OpenAIToolCallMessageContentItemModel(this.toolCalls);
}


/// 表示聊天补全 API 的响应。
class OpenAIChatCompletionModel {
  /// 唯一的请求 ID。
  final String id;
  /// API 返回的选项列表。
  final List<OpenAIChatCompletionChoiceModel> choices;
  /// 创建时间戳。
  final DateTime created;
  /// 使用的模型名称。
  final String model;
  /// [新增] token 使用情况
  final OpenAIUsage? usage;

  OpenAIChatCompletionModel({
    required this.id,
    required this.choices,
    required this.created,
    required this.model,
    this.usage,
  });
}

/// 聊天补全响应中的一个选项。
class OpenAIChatCompletionChoiceModel {
  /// 选项的索引。
  final int index;
  /// 模型返回的消息。
  final OpenAIChatCompletionChoiceMessageModel message;
  /// [新增] 流式响应中的消息增量
  final OpenAIChatCompletionChoiceMessageModel? delta;
  /// 选项结束的原因。
  final String? finishReason;

  OpenAIChatCompletionChoiceModel({
    required this.index,
    required this.message,
    this.delta,
    this.finishReason,
  });
}

/// 图像生成 API 的响应。
class OpenAIImageModel {
  /// 创建时间戳。
  final DateTime created;
  /// 生成的图像数据列表。
  final List<OpenAIImageData> data;

  OpenAIImageModel({required this.created, required this.data});
}

/// 单个生成的图像数据。
class OpenAIImageData {
  /// Base64 编码的图像数据。
  final String? b64Json;
  /// 或者，图像的 URL。
  final String? url;

  OpenAIImageData({this.b64Json, this.url});
}

/// 定义DALL-E生成的图片尺寸。
enum OpenAIImageSize {
  size256,
  size512,
  size1024,
}

/// 定义DALL-E返回的图片格式。
enum OpenAIImageResponseFormat {
  url,
  b64Json,
}

// --- Tool-related Models ---

/// 定义一个可供模型调用的工具。
class OpenAITool {
  final String type; // "function"
  final OpenAIFunction function;

  const OpenAITool({required this.function, this.type = 'function'});
}

/// 单个函数的定义。
class OpenAIFunction {
  final String name;
  final String? description;
  final Map<String, dynamic> parameters; // OpenAPI Schema

  const OpenAIFunction({
    required this.name,
    this.description,
    required this.parameters,
  });
}

/// 模型返回的工具调用。
class OpenAIToolCall {
  final String id;
  final String type; // "function"
  final OpenAIFunctionCall function;

  const OpenAIToolCall({
    required this.id,
    required this.type,
    required this.function,
  });
}

/// 具体的函数调用信息。
class OpenAIFunctionCall {
  final String? name;
  final String? arguments;

  const OpenAIFunctionCall({this.name, this.arguments});
}

/// 表示嵌入 API 的响应。
class OpenAIEmbeddingModel {
  final List<OpenAIEmbedding> data;
  final String model;

  OpenAIEmbeddingModel({required this.data, required this.model});
}

/// 表示单个嵌入向量。
class OpenAIEmbedding {
  final int index;
  final List<double> embedding;

  OpenAIEmbedding({required this.index, required this.embedding});
}

/// 表示从 /models 端点获取的单个模型的信息。
class OpenAIModelInfo {
  final String id;
  final DateTime created;
  final String ownedBy;

  OpenAIModelInfo({required this.id, required this.created, required this.ownedBy});
}

/// [新增] 表示 API 调用的 token 使用情况。
class OpenAIUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  OpenAIUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });
}