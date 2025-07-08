import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/openai_api_service.dart';

// 用于传递参数给 Provider 的不可变类
class OpenAIModelsProviderParams {
	final String baseUrl;
	final String apiKey;

	OpenAIModelsProviderParams({required this.baseUrl, required this.apiKey});

	@override
	bool operator ==(Object other) =>
		identical(this, other) ||
		other is OpenAIModelsProviderParams &&
			runtimeType == other.runtimeType &&
			baseUrl == other.baseUrl &&
			apiKey == other.apiKey;

	@override
	int get hashCode => baseUrl.hashCode ^ apiKey.hashCode;
}

// Service Provider，提供 OpenaiApiService 的单例
final openaiApiServiceProvider = Provider<OpenaiApiService>((ref) {
	return OpenaiApiService();
});

// FutureProvider，用于异步获取模型列表
// 使用 .autoDispose 来自动管理状态，当不再被监听时销毁
// 使用 .family 来传递参数
final openAIModelsProvider = FutureProvider.autoDispose.family<List<OpenAIModel>, OpenAIModelsProviderParams>(
	(ref, params) async {
		// 监视 service provider
		final apiService = ref.watch(openaiApiServiceProvider);
		// 调用 service 的方法来获取数据
		return apiService.fetchModels(baseUrl: params.baseUrl, apiKey: params.apiKey);
	},
);