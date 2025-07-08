import 'package:flutter/foundation.dart'; // for listEquals

import 'enums.dart'; // 导入本地枚举

// --- DTO for XmlRule ---
@immutable
class XmlRuleDto {
  final String? tagName;
  final XmlAction action;

  const XmlRuleDto({
    this.tagName,
    this.action = XmlAction.ignore, // 更新默认值为 ignore
  });

  factory XmlRuleDto.fromJson(Map<String, dynamic> json) {
    return XmlRuleDto(
      tagName: json['tagName'] as String?,
      action: XmlAction.values.firstWhere(
        (e) => e.toString() == json['action'],
        orElse: () => XmlAction.ignore, // 更新 orElse 默认值为 ignore
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tagName': tagName,
      'action': action.toString(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XmlRuleDto &&
          runtimeType == other.runtimeType &&
          tagName == other.tagName &&
          action == other.action;

  @override
  int get hashCode => tagName.hashCode ^ action.hashCode;
}

// --- DTO for SafetySettingRule ---
@immutable
class SafetySettingRuleDto {
  final LocalHarmCategory category;
  final LocalHarmBlockThreshold threshold;

  const SafetySettingRuleDto({
    this.category = LocalHarmCategory.harassment,
    this.threshold = LocalHarmBlockThreshold.none,
  });

  factory SafetySettingRuleDto.fromJson(Map<String, dynamic> json) {
    return SafetySettingRuleDto(
      category: LocalHarmCategory.values.firstWhere(
        (e) => e.toString() == json['category'],
        orElse: () => LocalHarmCategory.unknown, // 默认值
      ),
      threshold: LocalHarmBlockThreshold.values.firstWhere(
        (e) => e.toString() == json['threshold'],
        orElse: () => LocalHarmBlockThreshold.unspecified, // 默认值
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category.toString(),
      'threshold': threshold.toString(),
    };
  }

   @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SafetySettingRuleDto &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          threshold == other.threshold;

  @override
  int get hashCode => category.hashCode ^ threshold.hashCode;
}

// --- DTO for GenerationConfig ---
@immutable
class GenerationConfigDto {
  final String modelName;
  final double? temperature;
  final double? topP;
  final int? topK;
  final int? maxOutputTokens;
  final List<String>? stopSequences;
  final List<SafetySettingRuleDto> safetySettings;
  final bool useCustomTemperature; // 新增
  final bool useCustomTopP; // 新增
  final bool useCustomTopK; // 新增

  const GenerationConfigDto({
    this.modelName = 'gemini-2.5-pro-exp-03-25',
    this.temperature,
    this.topP,
    this.topK,
    this.maxOutputTokens = 2048,
    this.stopSequences,
    this.useCustomTemperature = false, // 新增
    this.useCustomTopP = false, // 新增
    this.useCustomTopK = false, // 新增
    this.safetySettings = const [ // 提供默认值
      SafetySettingRuleDto(category: LocalHarmCategory.harassment, threshold: LocalHarmBlockThreshold.none),
      SafetySettingRuleDto(category: LocalHarmCategory.hateSpeech, threshold: LocalHarmBlockThreshold.none),
      SafetySettingRuleDto(category: LocalHarmCategory.sexuallyExplicit, threshold: LocalHarmBlockThreshold.none),
      SafetySettingRuleDto(category: LocalHarmCategory.dangerousContent, threshold: LocalHarmBlockThreshold.none),
    ],
  });

  factory GenerationConfigDto.fromJson(Map<String, dynamic> json) {
    return GenerationConfigDto(
      modelName: json['modelName'] as String? ?? 'gemini-2.5-pro-exp-03-25',
      temperature: (json['temperature'] as num?)?.toDouble(),
      topP: (json['topP'] as num?)?.toDouble(),
      topK: json['topK'] as int?,
      maxOutputTokens: json['maxOutputTokens'] as int? ?? 2048,
      stopSequences: (json['stopSequences'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      useCustomTemperature: json['useCustomTemperature'] as bool? ?? false, // 新增
      useCustomTopP: json['useCustomTopP'] as bool? ?? false, // 新增
      useCustomTopK: json['useCustomTopK'] as bool? ?? false, // 新增
      safetySettings: (json['safetySettings'] as List<dynamic>?)
              ?.map((e) => SafetySettingRuleDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [ // 解析失败或缺失时的默认值
            SafetySettingRuleDto(category: LocalHarmCategory.harassment, threshold: LocalHarmBlockThreshold.none),
            SafetySettingRuleDto(category: LocalHarmCategory.hateSpeech, threshold: LocalHarmBlockThreshold.none),
            SafetySettingRuleDto(category: LocalHarmCategory.sexuallyExplicit, threshold: LocalHarmBlockThreshold.none),
            SafetySettingRuleDto(category: LocalHarmCategory.dangerousContent, threshold: LocalHarmBlockThreshold.none),
          ],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'modelName': modelName,
      'temperature': temperature,
      'topP': topP,
      'topK': topK,
      'maxOutputTokens': maxOutputTokens,
      'stopSequences': stopSequences,
      'useCustomTemperature': useCustomTemperature, // 新增
      'useCustomTopP': useCustomTopP, // 新增
      'useCustomTopK': useCustomTopK, // 新增
      'safetySettings': safetySettings.map((e) => e.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenerationConfigDto &&
          runtimeType == other.runtimeType &&
          modelName == other.modelName &&
          temperature == other.temperature &&
          topP == other.topP &&
          topK == other.topK &&
          maxOutputTokens == other.maxOutputTokens &&
          listEquals(stopSequences, other.stopSequences) &&
          useCustomTemperature == other.useCustomTemperature && // 新增
          useCustomTopP == other.useCustomTopP && // 新增
          useCustomTopK == other.useCustomTopK && // 新增
          listEquals(safetySettings, other.safetySettings);

  @override
  int get hashCode =>
      modelName.hashCode ^
      temperature.hashCode ^
      topP.hashCode ^
      topK.hashCode ^
      maxOutputTokens.hashCode ^
      stopSequences.hashCode ^
      useCustomTemperature.hashCode ^ // 新增
      useCustomTopP.hashCode ^ // 新增
      useCustomTopK.hashCode ^ // 新增
      safetySettings.hashCode;
}

// --- DTO for ContextConfig ---
@immutable
class ContextConfigDto {
  final ContextManagementMode mode;
  final int maxTurns;
  final int? maxContextTokens;

  const ContextConfigDto({
    this.mode = ContextManagementMode.turns,
    this.maxTurns = 10,
    this.maxContextTokens,
  });

  factory ContextConfigDto.fromJson(Map<String, dynamic> json) {
    return ContextConfigDto(
      mode: ContextManagementMode.values.firstWhere(
        (e) => e.toString() == json['mode'],
        orElse: () => ContextManagementMode.turns, // 默认值
      ),
      maxTurns: json['maxTurns'] as int? ?? 10, // 默认值
      maxContextTokens: json['maxContextTokens'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.toString(),
      'maxTurns': maxTurns,
      'maxContextTokens': maxContextTokens,
    };
  }

   @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContextConfigDto &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          maxTurns == other.maxTurns &&
          maxContextTokens == other.maxContextTokens;

  @override
  int get hashCode =>
      mode.hashCode ^ maxTurns.hashCode ^ maxContextTokens.hashCode;
}

// --- DTO for Message ---
@immutable
class MessageExportDto {
  final String rawText; // Kept for backward compatibility
  final MessageRole role;
  final List<Map<String, dynamic>>? parts; // New field for multi-part content
  final String? originalXmlContent; // New field

  const MessageExportDto({
    required this.rawText,
    required this.role,
    this.parts,
    this.originalXmlContent,
  });

  factory MessageExportDto.fromJson(Map<String, dynamic> json) {
    return MessageExportDto(
      rawText: json['rawText'] as String? ?? '',
      role: MessageRole.values.byName(json['role'] ?? 'user'),
      parts: (json['parts'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      originalXmlContent: json['originalXmlContent'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rawText': rawText,
      'role': role.name, // Use .name for clean enum string
      'parts': parts,
      'originalXmlContent': originalXmlContent,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageExportDto &&
          runtimeType == other.runtimeType &&
          rawText == other.rawText &&
          role == other.role &&
          listEquals(parts, other.parts) &&
          originalXmlContent == other.originalXmlContent;

  @override
  int get hashCode =>
      rawText.hashCode ^
      role.hashCode ^
      parts.hashCode ^
      originalXmlContent.hashCode;
}

// --- DTO for Chat ---
@immutable
class ChatExportDto {
  final String? title;
  final String? systemPrompt;
  // final String? coverImagePath; // Cover image is the exported image itself
  // final String? backgroundImagePath; // Background image might be complex to export/import
  final bool isFolder; // Keep folder status if needed, though import might always create a chat
  final GenerationConfigDto generationConfig;
  final ContextConfigDto contextConfig;
  final List<XmlRuleDto> xmlRules;
  final List<MessageExportDto> messages; // Include messages within the chat DTO
  final LlmType apiType; // 新增
  final String? selectedOpenAIConfigId; // 新增
  final String? coverImageBase64; // 新增: 存储封面图片的 Base64 字符串
  final bool enablePreprocessing;
  final String? preprocessingPrompt;
  final bool enablePostprocessing;
  final String? postprocessingPrompt;
  final String? contextSummary; // Export current summary

  const ChatExportDto({
    this.title,
    this.systemPrompt,
    this.isFolder = false, // Default to false on import
    required this.generationConfig,
    required this.contextConfig,
    required this.xmlRules,
    required this.messages,
    this.apiType = LlmType.gemini, // 新增，提供默认值
    this.selectedOpenAIConfigId, // 新增
    this.coverImageBase64, // 新增
    this.enablePreprocessing = false,
    this.preprocessingPrompt,
    this.enablePostprocessing = false,
    this.postprocessingPrompt,
    this.contextSummary,
  });

  factory ChatExportDto.fromJson(Map<String, dynamic> json) {
    return ChatExportDto(
      title: json['title'] as String?,
      systemPrompt: json['systemPrompt'] as String?,
      isFolder: json['isFolder'] as bool? ?? false,
      generationConfig: GenerationConfigDto.fromJson(json['generationConfig'] as Map<String, dynamic>),
      contextConfig: ContextConfigDto.fromJson(json['contextConfig'] as Map<String, dynamic>),
      xmlRules: (json['xmlRules'] as List<dynamic>)
          .map((e) => XmlRuleDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      messages: (json['messages'] as List<dynamic>)
          .map((e) => MessageExportDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      apiType: LlmType.values.firstWhere(
        (e) => e.toString() == json['apiType'],
        orElse: () => LlmType.gemini,
      ),
      selectedOpenAIConfigId: json['selectedOpenAIConfigId'] as String?,
      coverImageBase64: json['coverImageBase64'] as String?, // 新增
      enablePreprocessing: json['enablePreprocessing'] as bool? ?? false,
      preprocessingPrompt: json['preprocessingPrompt'] as String?,
      enablePostprocessing: json['enablePostprocessing'] as bool? ?? false,
      postprocessingPrompt: json['postprocessingPrompt'] as String?,
      contextSummary: json['contextSummary'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'systemPrompt': systemPrompt,
      'isFolder': isFolder,
      'generationConfig': generationConfig.toJson(),
      'contextConfig': contextConfig.toJson(),
      'xmlRules': xmlRules.map((e) => e.toJson()).toList(),
      'messages': messages.map((e) => e.toJson()).toList(),
      'apiType': apiType.toString(),
      'selectedOpenAIConfigId': selectedOpenAIConfigId,
      'coverImageBase64': coverImageBase64, // 新增
      'enablePreprocessing': enablePreprocessing,
      'preprocessingPrompt': preprocessingPrompt,
      'enablePostprocessing': enablePostprocessing,
      'postprocessingPrompt': postprocessingPrompt,
      'contextSummary': contextSummary,
    };
  }

   @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatExportDto &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          systemPrompt == other.systemPrompt &&
          isFolder == other.isFolder &&
          generationConfig == other.generationConfig &&
          contextConfig == other.contextConfig &&
          listEquals(xmlRules, other.xmlRules) &&
          listEquals(messages, other.messages) &&
          apiType == other.apiType &&
          selectedOpenAIConfigId == other.selectedOpenAIConfigId &&
          coverImageBase64 == other.coverImageBase64 && // 新增
          enablePreprocessing == other.enablePreprocessing &&
          preprocessingPrompt == other.preprocessingPrompt &&
          enablePostprocessing == other.enablePostprocessing &&
          postprocessingPrompt == other.postprocessingPrompt &&
          contextSummary == other.contextSummary;

  @override
  int get hashCode =>
      title.hashCode ^
      systemPrompt.hashCode ^
      isFolder.hashCode ^
      generationConfig.hashCode ^
      contextConfig.hashCode ^
      xmlRules.hashCode ^
      messages.hashCode ^
      apiType.hashCode ^
      selectedOpenAIConfigId.hashCode ^
      coverImageBase64.hashCode ^ // 新增
      enablePreprocessing.hashCode ^
      preprocessingPrompt.hashCode ^
      enablePostprocessing.hashCode ^
      postprocessingPrompt.hashCode ^
      contextSummary.hashCode;
}
