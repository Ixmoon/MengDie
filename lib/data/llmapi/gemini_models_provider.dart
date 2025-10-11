import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import 'llm_models.dart';
import 'llm_service/gemini_service.dart';
import '../../domain/models/api_config.dart';

@immutable
class GeminiModelsState {
  final AsyncValue<List<GeminiModel>> models;
  final String? selectedConfigId;

  const GeminiModelsState({
    this.models = const AsyncValue.data([]),
    this.selectedConfigId,
  });

  GeminiModelsState copyWith({
    AsyncValue<List<GeminiModel>>? models,
    String? selectedConfigId,
  }) {
    return GeminiModelsState(
      models: models ?? this.models,
      selectedConfigId: selectedConfigId ?? this.selectedConfigId,
    );
  }
}

class GeminiModelsNotifier extends StateNotifier<GeminiModelsState> {
  final GeminiService _apiService;

  GeminiModelsNotifier(this._apiService) : super(const GeminiModelsState());

  void selectConfig(ApiConfig? config) {
    if (config == null) {
      state = state.copyWith(
        selectedConfigId: null,
        models: const AsyncValue.data([]),
      );
    } else {
      state = state.copyWith(selectedConfigId: config.id);
      fetchModels(config);
    }
  }

  void resetState() {
    state = const GeminiModelsState();
  }

  Future<void> fetchModels(ApiConfig config) async {
    final apiKey = config.apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      state = state.copyWith(
        models: AsyncValue.error('API 密钥未设置。', StackTrace.current),
      );
      return;
    }
    state = state.copyWith(models: const AsyncValue.loading());
    try {
      final models = await _apiService.fetchModels(
        baseUrl: config.baseUrl ?? '',
        apiKey: apiKey,
      );
      state = state.copyWith(models: AsyncValue.data(models));
    } catch (e, stack) {
      state = state.copyWith(models: AsyncValue.error(e, stack));
    }
  }
}

final geminiModelsProvider =
    StateNotifierProvider.autoDispose<GeminiModelsNotifier, GeminiModelsState>((
      ref,
    ) {
      final apiService = ref.watch(geminiServiceProvider);
      return GeminiModelsNotifier(apiService);
    });
