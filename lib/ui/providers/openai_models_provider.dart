import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../service/llmapi/openai_service.dart'; // Updated import
import '../../data/models/api_config.dart';

@immutable
class OpenAIModelsState {
  final AsyncValue<List<OpenAIModel>> models;
  final String? selectedConfigId;

  const OpenAIModelsState({
    this.models = const AsyncValue.loading(),
    this.selectedConfigId,
  });

  OpenAIModelsState copyWith({
    AsyncValue<List<OpenAIModel>>? models,
    String? selectedConfigId,
  }) {
    return OpenAIModelsState(
      models: models ?? this.models,
      selectedConfigId: selectedConfigId ?? this.selectedConfigId,
    );
  }
}

class OpenAIModelsNotifier extends StateNotifier<OpenAIModelsState> {
  final OpenAIService _apiService;

  OpenAIModelsNotifier(this._apiService) : super(const OpenAIModelsState());

  void selectConfig(ApiConfig? config) {
    if (config == null) {
      state = state.copyWith(selectedConfigId: null, models: const AsyncValue.data([]));
    } else {
      state = state.copyWith(selectedConfigId: config.id);
      fetchModels(config);
    }
  }

  Future<void> fetchModels(ApiConfig config) async {
    if (config.baseUrl == null || config.baseUrl!.isEmpty || config.apiKey == null || config.apiKey!.isEmpty) {
      state = state.copyWith(models: AsyncValue.error('API基础URL或密钥未设置。', StackTrace.current));
      return;
    }
    state = state.copyWith(models: const AsyncValue.loading());
    try {
      final models = await _apiService.fetchModels(
        baseUrl: config.baseUrl!,
        apiKey: config.apiKey!,
      );
      state = state.copyWith(models: AsyncValue.data(models));
    } catch (e, stack) {
      state = state.copyWith(models: AsyncValue.error(e, stack));
    }
  }
}

final openAIModelsProvider = StateNotifierProvider<OpenAIModelsNotifier, OpenAIModelsState>((ref) {
  // Now depends on the globally provided OpenAIService
  final apiService = ref.watch(openaiServiceProvider);
  return OpenAIModelsNotifier(apiService);
});