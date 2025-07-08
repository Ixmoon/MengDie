import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart'; // For generating unique IDs

import '../data/database/drift/models/drift_openai_api_config.dart'; // Import DriftOpenAIAPIConfig
import '../providers/api_key_provider.dart'; // ApiKeyNotifier
import '../providers/openai_models_provider.dart';
import '../services/openai_api_service.dart';

// 本文件包含管理 OpenAI API 配置的屏幕界面。

class OpenAIAPIConfigsScreen extends ConsumerWidget {
	const OpenAIAPIConfigsScreen({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final apiKeyState = ref.watch(apiKeyNotifierProvider);
		final openAIConfigs = apiKeyState.openAIConfigs;

		return Scaffold(
			appBar: AppBar(
				title: const Text('OpenAI API 配置'),
			),
			body: Column(
				children: [
					if (apiKeyState.error != null && apiKeyState.error!.contains("OpenAI"))
						Padding(
							padding: const EdgeInsets.all(8.0),
							child: Text(
								apiKeyState.error!,
								style: TextStyle(color: Theme.of(context).colorScheme.error),
							),
						),
					Expanded(
						child: openAIConfigs.isEmpty
							? const Center(child: Text('未添加任何 OpenAI API 配置。'))
							: ListView.builder(
									itemCount: openAIConfigs.length,
									itemBuilder: (context, index) {
										final config = openAIConfigs[index];
										return ListTile(
											leading: const Icon(Icons.settings_ethernet_rounded),
											title: Text(config.name),
											subtitle: Text(
												'URL: ${config.baseUrl}\nModel: ${config.model}\nID: ${config.id.substring(0, 8)}...'),
											isThreeLine: true,
											trailing: Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													IconButton(
														icon: const Icon(Icons.edit_outlined),
														tooltip: '编辑配置',
														onPressed: () {
															_showEditOpenAIConfigDialog(context, ref, existingConfig: config);
														},
													),
													IconButton(
														icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
														tooltip: '删除配置',
														onPressed: () => _confirmDeleteConfig(context, ref, config),
													),
												],
											),
											onTap: () {
												_showEditOpenAIConfigDialog(context, ref, existingConfig: config);
											},
										);
									},
								),
					),
				],
			),
			floatingActionButton: FloatingActionButton.extended(
				icon: const Icon(Icons.add_rounded),
				label: const Text('添加配置'),
				onPressed: () {
					_showEditOpenAIConfigDialog(context, ref);
				},
			),
		);
	}

	void _confirmDeleteConfig(BuildContext context, WidgetRef ref, DriftOpenAIAPIConfig config) {
		showDialog(
			context: context,
			builder: (BuildContext dialogContext) {
				return AlertDialog(
					title: const Text('确认删除'),
					content: Text('您确定要删除配置 "${config.name}" 吗？此操作无法撤销。'),
					actions: <Widget>[
						TextButton(
							child: const Text('取消'),
							onPressed: () {
								Navigator.of(dialogContext).pop();
							},
						),
						TextButton(
							style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
							child: const Text('删除'),
							onPressed: () {
								ref.read(apiKeyNotifierProvider.notifier).deleteOpenAIConfig(config.id);
								Navigator.of(dialogContext).pop();
								ScaffoldMessenger.of(context).showSnackBar(
									SnackBar(content: Text('配置 "${config.name}" 已删除。')),
								);
							},
						),
					],
				);
			},
		);
	}

	void _showEditOpenAIConfigDialog(BuildContext context, WidgetRef ref, {DriftOpenAIAPIConfig? existingConfig}) {
		showDialog(
			context: context,
			barrierDismissible: false, // User must tap button!
			builder: (BuildContext dialogContext) {
				// We pass the ref to the stateful dialog
				return _OpenAIConfigDialog(existingConfig: existingConfig);
			},
		);
	}
}

// A stateful widget for the dialog content
class _OpenAIConfigDialog extends ConsumerStatefulWidget {
	final DriftOpenAIAPIConfig? existingConfig;

	const _OpenAIConfigDialog({this.existingConfig});

	@override
	ConsumerState<_OpenAIConfigDialog> createState() => _OpenAIConfigDialogState();
}

class _OpenAIConfigDialogState extends ConsumerState<_OpenAIConfigDialog> {
	final _formKey = GlobalKey<FormState>();
	late final TextEditingController _nameController;
	late final TextEditingController _baseUrlController;
	late final TextEditingController _apiKeyController;
	late final TextEditingController _modelController; // For manual input

	String? _selectedModel;
	AsyncValue<List<OpenAIModel>> _modelsState = const AsyncValue.data([]);

	bool get isEditing => widget.existingConfig != null;

	@override
	void initState() {
		super.initState();
		final config = widget.existingConfig;
		_nameController = TextEditingController(text: config?.name ?? '');
		_baseUrlController = TextEditingController(text: config?.baseUrl ?? 'https://api.openai.com/v1');
		_apiKeyController = TextEditingController(text: config?.apiKey ?? '');
		_selectedModel = config?.model;
		// Always initialize the text controller, used for manual input
		_modelController = TextEditingController(text: config?.model ?? 'gpt-4o-mini');
	}

	@override
	void dispose() {
		_nameController.dispose();
		_baseUrlController.dispose();
		_apiKeyController.dispose();
		_modelController.dispose();
		super.dispose();
	}

	Future<void> _fetchModels() async {
		if (_baseUrlController.text.trim().isEmpty || _apiKeyController.text.trim().isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('请先输入 Base URL 和 API Key。'), backgroundColor: Colors.orange),
			);
			return;
		}
		if (_modelsState.isLoading) return; // Prevent concurrent fetches

		if (!mounted) return;
		setState(() {
			_modelsState = const AsyncValue.loading();
		});

		try {
			final models = await ref.read(openaiApiServiceProvider).fetchModels(
						baseUrl: _baseUrlController.text.trim(),
						apiKey: _apiKeyController.text.trim(),
					);
			if (!mounted) return;
			setState(() {
				_modelsState = AsyncValue.data(models);
				// If the previously selected model isn't in the new list, unselect it.
				if (_selectedModel != null && !models.any((m) => m.id == _selectedModel)) {
					_selectedModel = null;
				}
				// If no model is selected and the list is not empty, select the first one.
				if (_selectedModel == null && models.isNotEmpty) {
					_selectedModel = models.first.id;
				}
			});
		} catch (e) {
			if (!mounted) return;
			// On error, show a snackbar and reset to an empty list.
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('获取模型列表失败: $e'), backgroundColor: Theme.of(context).colorScheme.error),
			);
			setState(() {
				_modelsState = const AsyncValue.data([]);
			});
		}
	}

	void _onSave() {
		if (_formKey.currentState!.validate()) {
			final hasModels = _modelsState.valueOrNull?.isNotEmpty ?? false;
			final modelValue = hasModels ? _selectedModel : _modelController.text.trim();

			// Final validation for model value before saving
			if (modelValue == null || modelValue.isEmpty) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('模型名称不能为空或未选择。'), backgroundColor: Theme.of(context).colorScheme.error),
				);
				return;
			}

			final config = DriftOpenAIAPIConfig(
				id: widget.existingConfig?.id ?? const Uuid().v4(),
				name: _nameController.text.trim(),
				baseUrl: _baseUrlController.text.trim(),
				apiKey: _apiKeyController.text.trim(),
				model: modelValue,
			);

			if (isEditing) {
				ref.read(apiKeyNotifierProvider.notifier).updateOpenAIConfig(config);
			} else {
				ref.read(apiKeyNotifierProvider.notifier).addOpenAIConfig(config);
			}
			Navigator.of(context).pop();
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('配置 "${config.name}" 已${isEditing ? "更新" : "添加"}。')),
			);
		}
	}

	@override
	Widget build(BuildContext context) {
		final String dialogTitle = isEditing ? '编辑 OpenAI 配置' : '添加 OpenAI 配置';
		final String saveButtonText = isEditing ? '保存更改' : '添加配置';

		return AlertDialog(
			title: Text(dialogTitle),
			content: SingleChildScrollView(
				child: Form(
					key: _formKey,
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: <Widget>[
							TextFormField(
								controller: _nameController,
								decoration: const InputDecoration(labelText: '配置名称*', hintText: '例如：我的本地大模型'),
								validator: (value) => (value == null || value.trim().isEmpty) ? '配置名称不能为空。' : null,
							),
							const SizedBox(height: 10),
							TextFormField(
								controller: _baseUrlController,
								decoration: const InputDecoration(labelText: 'Base URL*', hintText: '例如：https://api.your-llm.com/v1'),
								validator: (value) {
									if (value == null || value.trim().isEmpty) return 'Base URL 不能为空。';
									if (!(Uri.tryParse(value.trim())?.isAbsolute ?? false)) return '请输入有效的 URL。';
									return null;
								},
							),
							const SizedBox(height: 10),
							TextFormField(
								controller: _apiKeyController,
								decoration: const InputDecoration(labelText: 'API Key*', hintText: '您的 API 密钥'),
								obscureText: true,
								validator: (value) => (value == null || value.trim().isEmpty) ? 'API Key 不能为空。' : null,
							),
							const SizedBox(height: 10),
							_buildModelSelector(), // The new model selector widget
						],
					),
				),
			),
			actions: <Widget>[
				TextButton(
					child: const Text('取消'),
					onPressed: () => Navigator.of(context).pop(),
				),
				ElevatedButton(
					onPressed: _onSave,
					child: Text(saveButtonText),
				),
			],
		);
	}

	Widget _buildModelSelector() {
		final models = _modelsState.valueOrNull ?? [];
		final isLoading = _modelsState.isLoading;

		if (isLoading) {
			return const Padding(
				padding: EdgeInsets.symmetric(vertical: 16.0),
				child: Row(
					children: [
						SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
						SizedBox(width: 16),
						Expanded(child: Text('正在获取模型列表...')),
					],
				),
			);
		}

		if (models.isEmpty) {
			return Row(
				crossAxisAlignment: CrossAxisAlignment.end,
				children: [
					Expanded(
						child: TextFormField(
							controller: _modelController,
							decoration: const InputDecoration(
								labelText: '模型名称*',
								hintText: '例如: gpt-4o-mini',
							),
							validator: (value) {
								// Only validate if the dropdown isn't showing
								if (models.isEmpty && (value == null || value.trim().isEmpty)) {
									return '模型名称不能为空。';
								}
								return null;
							},
						),
					),
					IconButton(
						icon: const Icon(Icons.refresh),
						tooltip: '获取可用模型',
						onPressed: _fetchModels,
					),
				],
			);
		}

		// If we have models, show the dropdown
		return DropdownButtonFormField<String>(
			value: _selectedModel,
			isExpanded: true,
			decoration: InputDecoration(
				labelText: '模型名称*',
				suffixIcon: IconButton(
					icon: const Icon(Icons.refresh),
					tooltip: '刷新模型列表',
					onPressed: _fetchModels,
				),
			),
			items: models.map((model) {
				return DropdownMenuItem<String>(
					value: model.id,
					child: Text(model.id, overflow: TextOverflow.ellipsis),
				);
			}).toList(),
			onChanged: (value) {
				setState(() {
					_selectedModel = value;
				});
			},
			validator: (value) {
				// Only validate if the dropdown is showing
				if (models.isNotEmpty && (value == null || value.isEmpty)) {
					return '请选择一个模型。';
				}
				return null;
			},
		);
	}
}
