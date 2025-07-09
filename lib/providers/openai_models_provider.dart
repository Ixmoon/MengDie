import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/openai_api_service.dart';

// --- State ---
class OpenAIModelsState {
  final AsyncValue<List<OpenAIModel>> models;
  final String? lastError;

  OpenAIModelsState({
    this.models = const AsyncValue.loading(),
    this.lastError,
  });

  OpenAIModelsState copyWith({
    AsyncValue<List<OpenAIModel>>? models,
    String? lastError,
  }) {
    return OpenAIModelsState(
      models: models ?? this.models,
      lastError: lastError ?? this.lastError,
    );
  }
}

// --- Notifier ---
class OpenAIModelsNotifier extends StateNotifier<OpenAIModelsState> {
  final OpenaiApiService _apiService;

  OpenAIModelsNotifier(this._apiService) : super(OpenAIModelsState());

  Future<void> fetchModels({required String baseUrl, required String apiKey}) async {
    state = state.copyWith(models: const AsyncValue.loading());
    try {
      final models = await _apiService.fetchModels(baseUrl: baseUrl, apiKey: apiKey);
      state = state.copyWith(models: AsyncValue.data(models));
    } catch (e) {
      state = state.copyWith(models: AsyncValue.error(e, StackTrace.current), lastError: e.toString());
    }
  }

  void resetState() {
    state = OpenAIModelsState();
  }
}

// --- Provider ---
final openaiModelsProvider = StateNotifierProvider<OpenAIModelsNotifier, OpenAIModelsState>((ref) {
  // We create the ApiService here, it has no dependencies.
  return OpenAIModelsNotifier(OpenaiApiService());
});