import 'package:tiktoken/tiktoken.dart' as tiktoken;
import '../../domain/models/api_config.dart';
import '../../domain/enums.dart';
import 'llm_models.dart';

/// A utility class for calculating token counts for various LLM providers.
///
/// This centralizes the logic for token estimation, including handling
/// different content types (text, image, etc.) and provider-specific rules.
class TokenCalculator {
  // --- Constants for token estimation ---
  // Based on OpenAI's official guidance for high-res images.
  static const int _openAIImageTokenCost = 765;
  // Based on common knowledge for Gemini's image input cost.
  static const int _geminiImageTokenCost = 258;
  // A conservative placeholder estimate for other complex media types.
  static const int _otherMediaTokenCost = 1000;

  /// Calculates the total token count for a list of [LlmContent].
  ///
  /// This method iterates through all parts of the content, applies the
  /// correct tokenization for text, and uses provider-specific estimates
  /// for multimodal content like images.
  static Future<int> countTokens({
    required List<LlmContent> llmContext,
    required ApiConfig apiConfig,
  }) async {
    final encoding = _getEncoding(apiConfig.model);
    int totalTokens = 0;
    
    final imageCost = apiConfig.apiType == LlmType.openai 
        ? _openAIImageTokenCost 
        : _geminiImageTokenCost;

    for (final message in llmContext) {
      for (final part in message.parts) {
        if (part is LlmTextPart) {
          totalTokens += encoding.encode(part.text).length;
        } else if (part is LlmDataPart) {
          totalTokens += imageCost;
        } else if (part is LlmAudioPart || part is LlmFilePart) {
          totalTokens += _otherMediaTokenCost;
        }
      }
    }
    return totalTokens;
  }

  /// Selects the appropriate tiktoken encoding based on the model name.
  ///
  /// Falls back to a default encoding if the model-specific one is not found.
  static tiktoken.Tiktoken _getEncoding(String model) {
    try {
      return tiktoken.encodingForModel(model);
    } catch (_) {
      // Fallback for models not explicitly listed in tiktoken, like Gemini models.
      return tiktoken.getEncoding('cl100k_base');
    }
  }
}