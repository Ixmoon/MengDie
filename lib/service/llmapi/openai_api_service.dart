import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// 数据模型，用于解析从 API 返回的模型信息
class OpenAIModel {
	final String id;
	final String object;
	final int created;
	final String ownedBy;

	OpenAIModel({
		required this.id,
		required this.object,
		required this.created,
		required this.ownedBy,
	});

	factory OpenAIModel.fromJson(Map<String, dynamic> json) {
		return OpenAIModel(
			id: json['id'] ?? 'unknown',
			object: json['object'] ?? 'unknown',
			created: json['created'] ?? 0,
			ownedBy: json['owned_by'] ?? 'unknown',
		);
	}
}

// API 服务类，封装了获取模型列表的网络请求
class OpenaiApiService {
	final Dio _dio;

	// 构造函数，可以传入一个 Dio 实例，方便测试
	OpenaiApiService({Dio? dio}) : _dio = dio ?? Dio();

	// 异步方法，用于从指定的 OpenAI 兼容端点获取模型列表
	Future<List<OpenAIModel>> fetchModels({
		required String baseUrl,
		required String apiKey,
	}) async {
		try {
			// 确保 baseUrl 的格式正确
			final correctedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
			final response = await _dio.get(
				'${correctedBaseUrl}models',
				options: Options(
					headers: {
						'Authorization': 'Bearer $apiKey',
						'Content-Type': 'application/json',
					},
				),
			);

			if (response.statusCode == 200 && response.data != null) {
				// 解析返回的 JSON 数据
				final data = response.data['data'] as List;
				final models = data.map((modelJson) => OpenAIModel.fromJson(modelJson)).toList();
				// 按模型 ID 排序
				models.sort((a, b) => a.id.compareTo(b.id));
				return models;
			} else {
				// 处理非 200 状态码
				throw Exception('Failed to load models: Status code ${response.statusCode}');
			}
		} on DioException catch (e) {
			// 处理网络请求相关的异常
			debugPrint('Error fetching OpenAI models: $e');
			throw Exception('Failed to fetch models: ${e.message}');
		} catch (e) {
			// 处理其他未知异常
			debugPrint('An unexpected error occurred: $e');
			throw Exception('An unexpected error occurred while fetching models.');
		}
	}
}