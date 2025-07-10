import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import local models and services
import 'package:drift/drift.dart' as drift;
import '../../data/models/models.dart';
import '../../data/models/api_config.dart'; // Import the new domain model
import 'gemini_service.dart';
import 'openai_service.dart';
import '../../data/providers/api_key_provider.dart';

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

  /// Creates an LlmContent instance from a local Message object.
  factory LlmContent.fromMessage(Message message) {
    final parts = message.parts.map((part) {
      switch (part.type) {
        case MessagePartType.text:
          return LlmTextPart(part.text!);
        case MessagePartType.image:
          return LlmDataPart(part.mimeType!, part.base64Data!);
        case MessagePartType.file:
          // Files are not sent to the LLM, so we return null and filter it out later.
          return null;
      }
    }).whereType<LlmPart>().toList(); // Use whereType to filter out nulls
    
    // Convert local MessageRole to the string role expected by APIs ("user" or "model")
    final roleString = message.role == MessageRole.user ? 'user' : 'model';
    
    return LlmContent(roleString, parts);
  }
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

/// Represents a data part of the content (e.g., an image).
/// Equivalent to genai.DataPart
@immutable
class LlmDataPart extends LlmPart {
  final String mimeType;
  final String base64Data; // Keep as base64 string for consistency
  const LlmDataPart(this.mimeType, this.base64Data);
}


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
  final List<MessagePart> parts;
  final bool isSuccess;
  final String? error;

  // Getter for easy access to text content, for compatibility
  String get rawText => parts.where((p) => p.type == MessagePartType.text).map((p) => p.text).join();

  const LlmResponse({
    required this.parts,
    this.isSuccess = true,
    this.error,
  });

  /// Creates an LlmResponse from a GeminiResponse.
  factory LlmResponse.fromGeminiResponse(GeminiResponse geminiResponse) {
    // This now needs to handle the possibility of GeminiResponse also returning parts
    // For now, assuming it returns a single text part.
    final responseParts = (geminiResponse.rawText.isNotEmpty)
        ? [MessagePart.text(geminiResponse.rawText)]
        : <MessagePart>[];

    return LlmResponse(
      parts: responseParts,
      isSuccess: geminiResponse.isSuccess,
      error: geminiResponse.error,
    );
  }

  /// Creates an error response.
  const LlmResponse.error(String message) :
    parts = const [],
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
  // ignore: unused_field
  final Ref _ref;
  final GeminiService _geminiService;
  final OpenAIService _openAIService; // 新增 OpenAIService 实例
  final ApiKeyNotifier _apiKeyNotifier;

  // --- Cancellation State ---
  LlmType? _activeServiceType;

  LlmService(this._ref, this._geminiService, this._openAIService, this._apiKeyNotifier);

  /// Retrieves the API configuration for a given chat and prepares generation parameters.
  (ApiConfig?, Map<String, dynamic>) _getApiConfigAndParams(Chat chat, {String? apiConfigIdOverride}) {
    final configId = apiConfigIdOverride ?? chat.apiConfigId;
    if (configId == null) {
      return (null, {});
    }
    final apiConfig = _apiKeyNotifier.getConfigById(configId);
    if (apiConfig == null) {
      return (null, {});
    }

    final Map<String, dynamic> params = {
      if (apiConfig.useCustomTemperature && apiConfig.temperature != null) 'temperature': apiConfig.temperature,
      if (apiConfig.useCustomTopP && apiConfig.topP != null) 'topP': apiConfig.topP,
      if (apiConfig.useCustomTopK && apiConfig.topK != null) 'topK': apiConfig.topK,
      if (apiConfig.maxOutputTokens != null) 'maxOutputTokens': apiConfig.maxOutputTokens,
      if (apiConfig.stopSequences != null && apiConfig.stopSequences!.isNotEmpty) 'stopSequences': apiConfig.stopSequences,
    };
    return (apiConfig, params);
  }

  /// Sends messages and gets a streaming response.
  Stream<LlmStreamChunk> sendMessageStream({
    required List<LlmContent> llmContext,
    required Chat chat,
    String? apiConfigIdOverride,
  }) {
    final (apiConfig, generationParams) = _getApiConfigAndParams(chat, apiConfigIdOverride: apiConfigIdOverride);

    if (apiConfig == null) {
      return Stream.value(LlmStreamChunk.error("API configuration not found for this chat.", ''));
    }

    _activeServiceType = apiConfig.apiType;
    debugPrint("LlmService: Set active service to $_activeServiceType for potential cancellation.");

    switch (apiConfig.apiType) {
      case LlmType.gemini:
        try {
          return _geminiService.sendMessageStream(llmContext: llmContext, apiConfig: apiConfig, generationParams: generationParams)
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
        if (apiConfig.apiKey == null || apiConfig.apiKey!.isEmpty) {
          return Stream.value(LlmStreamChunk.error("API Key for OpenAI config '${apiConfig.name}' is missing.", ''));
        }
        try {
          return _openAIService.sendMessageStream(llmContext: llmContext, apiConfig: apiConfig, generationParams: generationParams);
        } catch (e) {
          debugPrint("Error setting up OpenAI stream: $e");
          return Stream.value(LlmStreamChunk.error("Failed to start OpenAI stream: $e", ''));
        }
    }
  }

  /// Sends messages and gets a single, complete response.
  Future<LlmResponse> sendMessageOnce({
    required List<LlmContent> llmContext,
    required Chat chat,
    String? apiConfigIdOverride,
  }) async {
    final (apiConfig, generationParams) = _getApiConfigAndParams(chat, apiConfigIdOverride: apiConfigIdOverride);

    if (apiConfig == null) {
      return const LlmResponse.error("API configuration not found for this chat.");
    }

    _activeServiceType = apiConfig.apiType;
    debugPrint("LlmService: Set active service to $_activeServiceType for potential cancellation.");

    switch (apiConfig.apiType) {
      case LlmType.gemini:
        try {
          final geminiResponse = await _geminiService.sendMessageOnce(llmContext: llmContext, apiConfig: apiConfig, generationParams: generationParams);
          return LlmResponse.fromGeminiResponse(geminiResponse);
        } catch (e) {
          debugPrint("Error during Gemini sendMessageOnce: $e");
          return LlmResponse.error("Gemini API Error: $e");
        }
      case LlmType.openai:
        if (apiConfig.apiKey == null || apiConfig.apiKey!.isEmpty) {
          return LlmResponse.error("API Key for OpenAI config '${apiConfig.name}' is missing.");
        }
        try {
          return await _openAIService.sendMessageOnce(llmContext: llmContext, apiConfig: apiConfig, generationParams: generationParams);
        } catch (e) {
          debugPrint("Error during OpenAI sendMessageOnce: $e");
          return LlmResponse.error("OpenAI API Error: $e");
        }
    }
  }

  /// Counts tokens for a given context.
  Future<int> countTokens({
    required List<LlmContent> llmContext,
    required Chat chat,
  }) async {
    final (apiConfig, _) = _getApiConfigAndParams(chat);

    if (apiConfig == null) {
      debugPrint("LlmService.countTokens Error: API configuration not found.");
      return -1;
    }

    switch (apiConfig.apiType) {
      case LlmType.gemini:
        try {
          return await _geminiService.countTokens(llmContext: llmContext, apiConfig: apiConfig);
        } catch (e) {
          debugPrint("Error during Gemini countTokens: $e");
          return -1;
        }
      case LlmType.openai:
        if (apiConfig.apiKey == null || apiConfig.apiKey!.isEmpty) {
           debugPrint("LlmService.countTokens (OpenAI) Error: API Key for config '${apiConfig.name}' is missing.");
          return -1;
        }
        try {
          return await _openAIService.countTokens(llmContext: llmContext, apiConfig: apiConfig);
        } catch (e) {
          debugPrint("Error during OpenAI countTokens: $e");
          return -1;
        }
    }
  }

  // --- Placeholder for future methods ---
  // Future<List<String>> listAvailableModels(LlmType type, {OpenAIAPIConfig? openAIConfig}) async { ... }
  /// Cancels the ongoing request on the currently active service.
  Future<void> cancelActiveRequest() async {
    debugPrint("LlmService: Received cancellation request for active service: $_activeServiceType");
    if (_activeServiceType == null) {
      debugPrint("LlmService: Cancellation request ignored, no active service.");
      return;
    }

    if (_activeServiceType == LlmType.openai) {
      await _openAIService.cancelRequest();
    } else if (_activeServiceType == LlmType.gemini) {
      await _geminiService.cancelRequest();
    }
    // Reset the active service type after cancellation to prevent dangling state
    _activeServiceType = null;
    debugPrint("LlmService: Active service has been cancelled and reset.");
  }
}

// REMOVED Enum for LLM Types as it's defined in models/enums.dart
