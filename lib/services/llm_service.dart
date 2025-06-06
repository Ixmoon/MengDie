import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_generative_ai/google_generative_ai.dart' as genai; // REMOVED

// Import local models and services
import '../models/models.dart'; // Access to Chat, Message, GenerationConfig, LlmType, OpenAIAPIConfig etc.
import '../data/database/drift/models/drift_generation_config.dart'; // Import for DriftGenerationConfig
import 'gemini_service.dart'; // Access to the specific Gemini implementation
import 'openai_service.dart'; // 新增：Access to the specific OpenAI implementation
import '../providers/api_key_provider.dart'; // Needed for API key access and OpenAI configs

// --- Generic LLM Data Structures ---
// These structures abstract away the specifics of the underlying LLM API (e.g., Gemini)

/// Represents a piece of content sent to or received from the LLM.
/// Equivalent to genai.Content
@immutable
class LlmContent {
  final String role; // e.g., "user", "model"
  final List<LlmPart> parts;

  const LlmContent(this.role, this.parts);

  // REMOVED: toGenaiContent method
}

/// Base class for different types of content parts (text, image, etc.).
/// Equivalent to genai.Part
@immutable
abstract class LlmPart {
  const LlmPart();
}

/// Represents a text part of the content.
/// Equivalent to genai.TextPart
@immutable
class LlmTextPart extends LlmPart {
  final String text;
  const LlmTextPart(this.text);
}

// TODO: Define other LlmPart types as needed (e.g., LlmImagePart)
// @immutable
// class LlmImagePart extends LlmPart {
//   final Uint8List bytes;
//   const LlmImagePart(this.bytes);
// }


/// Represents a generic safety setting for the LLM.
/// Equivalent to genai.SafetySetting
@immutable
class LlmSafetySetting {
  final LocalHarmCategory category; // Use local enum
  final LocalHarmBlockThreshold threshold; // Use local enum

  const LlmSafetySetting(this.category, this.threshold);

  // REMOVED: toGenaiSafetySetting method and mapping helpers
}

/// Represents a generic generation configuration for the LLM.
/// Equivalent to genai.GenerationConfig
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

  // REMOVED: toGenaiGenerationConfig method
}


/// Represents a chunk of a streaming response from the LLM.
/// Equivalent to GeminiStreamChunk but more generic.
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

  /// Creates an LlmStreamChunk from a GeminiStreamChunk.
  factory LlmStreamChunk.fromGeminiChunk(GeminiStreamChunk geminiChunk) {
    return LlmStreamChunk(
      textChunk: geminiChunk.textChunk,
      accumulatedText: geminiChunk.accumulatedText,
      timestamp: geminiChunk.timestamp,
      isFinished: geminiChunk.isFinished,
      error: geminiChunk.error,
    );
  }

  /// Creates an error chunk.
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

/// Represents a single, complete response from the LLM.
/// Equivalent to GeminiResponse but more generic.
@immutable
class LlmResponse {
  final String rawText;
  final bool isSuccess;
  final String? error;

  const LlmResponse({
    required this.rawText,
    this.isSuccess = true,
    this.error,
  });

  /// Creates an LlmResponse from a GeminiResponse.
  factory LlmResponse.fromGeminiResponse(GeminiResponse geminiResponse) {
    return LlmResponse(
      rawText: geminiResponse.rawText,
      isSuccess: geminiResponse.isSuccess,
      error: geminiResponse.error,
    );
  }

  /// Creates an error response.
  const LlmResponse.error(String message) :
    rawText = '',
    isSuccess = false,
    error = message;
}


// --- LLM Service Provider ---
final llmServiceProvider = Provider<LlmService>((ref) {
  // LlmService now depends on GeminiService, OpenAIService, and ApiKeyNotifier
  final geminiService = ref.watch(geminiServiceProvider);
  final openAIService = ref.watch(openaiServiceProvider); // 新增依赖
  final apiKeyNotifier = ref.watch(apiKeyNotifierProvider.notifier);
  return LlmService(ref, geminiService, openAIService, apiKeyNotifier); // 传递 openAIService
});


// --- LLM Service Implementation ---
// This service acts as a facade, providing a generic interface
// for interacting with different LLMs.
class LlmService {
  final Ref _ref;
  final GeminiService _geminiService;
  final OpenAIService _openAIService; // 新增 OpenAIService 实例
  final ApiKeyNotifier _apiKeyNotifier;

  LlmService(this._ref, this._geminiService, this._openAIService, this._apiKeyNotifier);

  // Helper to create a Map of generation parameters based on DriftGenerationConfig
  Map<String, dynamic> _prepareGenerationParametersMap(DriftGenerationConfig appDriftConfig) {
    final Map<String, dynamic> params = {};

    if (appDriftConfig.useCustomTemperature && appDriftConfig.temperature != null) {
      params['temperature'] = appDriftConfig.temperature;
    }
    if (appDriftConfig.useCustomTopP && appDriftConfig.topP != null) {
      params['topP'] = appDriftConfig.topP;
    }
    if (appDriftConfig.useCustomTopK && appDriftConfig.topK != null) {
      params['topK'] = appDriftConfig.topK;
    }
    // maxOutputTokens is often a required or always-present parameter,
    // but if it can be omitted when null, this check can be more stringent.
    // Assuming for now it's okay to pass null if the API handles it, or it has a default.
    // To strictly omit if null: if (appDriftConfig.maxOutputTokens != null)
    if (appDriftConfig.maxOutputTokens != null) { // Let's be strict and only add if not null
        params['maxOutputTokens'] = appDriftConfig.maxOutputTokens;
    }

    if (appDriftConfig.stopSequences != null && appDriftConfig.stopSequences!.isNotEmpty) {
      params['stopSequences'] = appDriftConfig.stopSequences;
    }
    return params;
  }

  // REMOVED: _buildApiContext method

  /// Sends messages and gets a streaming response.
  Stream<LlmStreamChunk> sendMessageStream({
    required List<LlmContent> llmContext, // Use generic LlmContent
    required Chat chat, // Still need Chat for some general info, but config is handled
  }) {
    // 1. Select the LLM based on chat.apiType
    final llmType = chat.apiType;
    // Prepare the generation parameters map
    final generationParams = _prepareGenerationParametersMap(chat.generationConfig);

    // 2. Delegate to the appropriate service
    switch (llmType) {
      case LlmType.gemini:
        try {
          // GeminiService now needs to accept Map<String, dynamic>
          return _geminiService.sendMessageStream(llmContext: llmContext, chat: chat, generationParams: generationParams)
              .map(LlmStreamChunk.fromGeminiChunk)
              .handleError((error, stackTrace) {
                debugPrint("Error in Gemini stream during mapping: $error\n$stackTrace");
                return LlmStreamChunk.error("Gemini Stream Error: $error", '');
              });
        } catch (e) {
          debugPrint("Error setting up Gemini stream: $e");
          return Stream.value(LlmStreamChunk.error("Failed to start Gemini stream: $e", ''));
        }
      case LlmType.openai:
        final configId = chat.selectedOpenAIConfigId;
        if (configId == null) {
          return Stream.value(LlmStreamChunk.error("OpenAI config ID not selected for this chat.", ''));
        }
        final apiConfig = _apiKeyNotifier.getOpenAIConfigById(configId);
        if (apiConfig == null) {
          return Stream.value(LlmStreamChunk.error("Selected OpenAI config (ID: $configId) not found.", ''));
        }
        if (apiConfig.apiKey == null || apiConfig.apiKey!.isEmpty) {
          return Stream.value(LlmStreamChunk.error("API Key for OpenAI config '${apiConfig.name}' is missing.", ''));
        }
        try {
          // OpenAIService is expected to return LlmStreamChunk directly
          // It will also need to be updated to accept Map<String, dynamic>
          return _openAIService.sendMessageStream(llmContext: llmContext, chat: chat, apiConfig: apiConfig, generationParams: generationParams);
        } catch (e) {
          debugPrint("Error setting up OpenAI stream: $e");
          return Stream.value(LlmStreamChunk.error("Failed to start OpenAI stream: $e", ''));
        }
      default:
        debugPrint("Error: LLM type $llmType not implemented yet for sendMessageStream.");
        return Stream.value(LlmStreamChunk.error("Unsupported LLM type: $llmType", ''));
    }
  }


  /// Sends messages and gets a single, complete response.
  Future<LlmResponse> sendMessageOnce({
    required List<LlmContent> llmContext, // Use generic LlmContent
    required Chat chat, // Still need Chat for some general info
  }) async {
    final llmType = chat.apiType;
    // Prepare the generation parameters map
    final generationParams = _prepareGenerationParametersMap(chat.generationConfig);

    switch (llmType) {
      case LlmType.gemini:
        try {
          // GeminiService now needs to accept Map<String, dynamic>
          final geminiResponse = await _geminiService.sendMessageOnce(llmContext: llmContext, chat: chat, generationParams: generationParams);
          return LlmResponse.fromGeminiResponse(geminiResponse);
        } catch (e) {
          debugPrint("Error during Gemini sendMessageOnce or context conversion: $e");
          return LlmResponse.error("Gemini API Error: $e");
        }
      case LlmType.openai:
        final configId = chat.selectedOpenAIConfigId;
        if (configId == null) {
          return const LlmResponse.error("OpenAI config ID not selected for this chat.");
        }
        final apiConfig = _apiKeyNotifier.getOpenAIConfigById(configId);
        if (apiConfig == null) {
          return LlmResponse.error("Selected OpenAI config (ID: $configId) not found.");
        }
        if (apiConfig.apiKey == null || apiConfig.apiKey!.isEmpty) {
          return LlmResponse.error("API Key for OpenAI config '${apiConfig.name}' is missing.");
        }
        try {
          // OpenAIService is expected to return LlmResponse directly
          // It will also need to be updated to accept Map<String, dynamic>
          return await _openAIService.sendMessageOnce(llmContext: llmContext, chat: chat, apiConfig: apiConfig, generationParams: generationParams);
        } catch (e) {
          debugPrint("Error during OpenAI sendMessageOnce: $e");
          return LlmResponse.error("OpenAI API Error: $e");
        }
      default:
        debugPrint("Error: LLM type $llmType not implemented yet for sendMessageOnce.");
        return LlmResponse.error("Unsupported LLM type: $llmType");
    }
  }

  /// Counts tokens for a given context.
  Future<int> countTokens({
    required List<LlmContent> llmContext,
    required Chat chat, // Pass the whole chat object
    // required String modelName, // Model name is now derived from chat or config
  }) async {
    final llmType = chat.apiType;

    switch (llmType) {
      case LlmType.gemini:
        final apiKey = _apiKeyNotifier.getNextApiKey(); // For Gemini, we still use the rotating key
        if (apiKey == null) {
          debugPrint("LlmService.countTokens (Gemini) Error: No API Key available.");
          return -1;
        }
        try {
          return await _geminiService.countTokens(
            llmContext: llmContext,
            modelName: chat.generationConfig.modelName, // Gemini model from chat's generation config
            apiKey: apiKey,
          );
        } catch (e) {
          debugPrint("Error during Gemini countTokens: $e");
          return -1;
        }
      case LlmType.openai:
        final configId = chat.selectedOpenAIConfigId;
        if (configId == null) {
          debugPrint("LlmService.countTokens (OpenAI) Error: OpenAI config ID not selected.");
          return -1;
        }
        final apiConfig = _apiKeyNotifier.getOpenAIConfigById(configId);
        if (apiConfig == null) {
          debugPrint("LlmService.countTokens (OpenAI) Error: Selected OpenAI config (ID: $configId) not found.");
          return -1;
        }
        // Note: OpenAI's modelName comes from apiConfig.modelName
        // The apiKey is also in apiConfig
        if (apiConfig.apiKey == null || apiConfig.apiKey!.isEmpty) {
           debugPrint("LlmService.countTokens (OpenAI) Error: API Key for config '${apiConfig.name}' is missing.");
          return -1;
        }
        try {
          return await _openAIService.countTokens(
            llmContext: llmContext,
            apiConfig: apiConfig, // Pass the whole config
          );
        } catch (e) {
          debugPrint("Error during OpenAI countTokens: $e");
          return -1;
        }
      default:
        debugPrint("Error: Token counting for LLM type $llmType not implemented yet.");
        return -1;
    }
  }

  // --- Placeholder for future methods ---
  // Future<List<String>> listAvailableModels(LlmType type, {OpenAIAPIConfig? openAIConfig}) async { ... }
}

// REMOVED Enum for LLM Types as it's defined in models/enums.dart
