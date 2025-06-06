import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart'; // Import Uuid

// 导入模型、Provider 和仓库
import '../models/models.dart'; // Chat, Message, LlmType, ContextManagementMode etc. (now Drift-backed or re-exported)
import '../data/database/drift/models/drift_xml_rule.dart'; // Import DriftXmlRule
import '../data/database/drift/models/drift_openai_api_config.dart'; // Import DriftOpenAIAPIConfig
import '../data/database/drift/common_enums.dart' as drift_enums; // For direct use of Drift enums if needed
import '../providers/chat_state_providers.dart'; // 需要 currentChatProvider
import '../providers/api_key_provider.dart'; // 新增：需要 apiKeyNotifierProvider 获取 OpenAI 配置
import '../repositories/chat_repository.dart'; // 需要 chatRepositoryProvider

// 本文件包含用于配置单个聊天会话设置的屏幕界面。

// --- 聊天设置屏幕 ---
// 使用 ConsumerStatefulWidget 以便访问 Ref 并管理本地状态（如 TextEditingControllers）。
class ChatSettingsScreen extends ConsumerStatefulWidget {
  final int chatId; // 通过路由传递的聊天 ID
  const ChatSettingsScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
   // 用于编辑字段的控制器
   late TextEditingController _titleController;
   late TextEditingController _systemPromptController;
   late TextEditingController _modelNameController;
   late TextEditingController _maxOutputTokensController;
   late TextEditingController _maxTurnsController;
   late TextEditingController _maxTokensController; // 上下文 Token 限制
   late TextEditingController _stopSequencesController; // 新增：停止序列控制器
   // 滑块值的状态变量 (可空)
   double? _temperatureValue;
   double? _topPValue;
   int? _topKValue; // New state variable for Top K
   // 上下文管理模式的状态变量
   drift_enums.ContextManagementMode _contextMode = drift_enums.ContextManagementMode.turns; // Use drift_enums
   // XML 规则列表的状态变量 (需要是可变列表)
   List<DriftXmlRule> _xmlRules = []; // Use DriftXmlRule
   // 标记是否已从 Provider 初始化状态
   bool _isInitialized = false;
   // 新增：控制显示高级设置的布尔值
   bool _showAdvancedSettings = false;
   // 新增：为每个参数添加独立的控制开关
   bool _useCustomTemperature = false;
   bool _useCustomTopP = false;
   bool _useCustomTopK = false;
   // 新增：API 类型和 OpenAI 配置选择的状态变量
   drift_enums.LlmType _selectedApiType = drift_enums.LlmType.gemini; // Use drift_enums
   String? _selectedOpenAIConfigId;

  @override
  void initState() {
    super.initState();
    // 控制器需要在 initState 中初始化，但此时 Ref 还不能安全读取。
    // 因此，我们先创建控制器，然后在 build 方法中首次加载数据时填充它们。
    _titleController = TextEditingController();
    _systemPromptController = TextEditingController();
    _modelNameController = TextEditingController();
    _maxOutputTokensController = TextEditingController();
    _maxTurnsController = TextEditingController();
    _maxTokensController = TextEditingController();
    _stopSequencesController = TextEditingController(); // 新增：初始化停止序列控制器
  }

  // 在 Widget 销毁时释放控制器资源
  @override
  void dispose() {
    _titleController.dispose();
    _systemPromptController.dispose();
    _modelNameController.dispose();
    _maxOutputTokensController.dispose();
    _maxTurnsController.dispose();
    _maxTokensController.dispose();
    _stopSequencesController.dispose(); // 新增：释放停止序列控制器
    super.dispose();
  }

  // --- 初始化控制器和状态 ---
  // 此方法在 build 方法中调用，当从 Provider 获取到初始聊天数据时执行一次。
  void _initializeState(Chat chat) {
    debugPrint("[ChatSettingsScreen] _initializeState: Start");
    debugPrint("[ChatSettingsScreen] _initializeState: chat.apiType = ${chat.apiType}, chat.selectedOpenAIConfigId = ${chat.selectedOpenAIConfigId}");
    _titleController.text = chat.title ?? '';
    _systemPromptController.text = chat.systemPrompt ?? '';
    _modelNameController.text = chat.generationConfig.modelName;

    // Initialize individual custom parameter flags
    _useCustomTemperature = chat.generationConfig.useCustomTemperature;
    _useCustomTopP = chat.generationConfig.useCustomTopP;
    _useCustomTopK = chat.generationConfig.useCustomTopK;

    // Initialize values based on their respective flags
    _temperatureValue = _useCustomTemperature ? (chat.generationConfig.temperature ?? 1.0) : null;
    _topPValue = _useCustomTopP ? (chat.generationConfig.topP ?? 0.95) : null;
    _topKValue = _useCustomTopK ? (chat.generationConfig.topK ?? 40) : null;
    
    _maxOutputTokensController.text = chat.generationConfig.maxOutputTokens?.toString() ?? ''; // 允许空
    // 新增：初始化停止序列控制器文本
    _stopSequencesController.text = chat.generationConfig.stopSequences?.join(', ') ?? '';
    _contextMode = chat.contextConfig.mode;
    _maxTurnsController.text = chat.contextConfig.maxTurns.toString();
    _maxTokensController.text = chat.contextConfig.maxContextTokens?.toString() ?? ''; // 允许空
    // 创建 _xmlRules 的可变副本，以便在 UI 中修改
    // chat.xmlRules is now List<DriftXmlRule>
    _xmlRules = List<DriftXmlRule>.from(chat.xmlRules); 

    // 新增：初始化 API 类型和 OpenAI 配置 ID
    _selectedApiType = chat.apiType; // chat.apiType is now drift_enums.LlmType
    final initialConfigId = chat.selectedOpenAIConfigId;
    // 在初始化时验证 ID 是否有效
    final availableConfigs = ref.read(apiKeyNotifierProvider).openAIConfigs; // This is List<DriftOpenAIAPIConfig>
    debugPrint("[ChatSettingsScreen] _initializeState: availableConfigs.length = ${availableConfigs.length}");
    if (_selectedApiType == drift_enums.LlmType.openai) { // Use drift_enums
      if (initialConfigId != null && availableConfigs.any((c) => c.id == initialConfigId)) {
        _selectedOpenAIConfigId = initialConfigId;
        debugPrint("[ChatSettingsScreen] _initializeState: OpenAI type, initialConfigId '$initialConfigId' is valid.");
      } else {
        // ID 无效或为 null，尝试设置第一个可用的
        _selectedOpenAIConfigId = availableConfigs.isNotEmpty ? availableConfigs.first.id : null;
        debugPrint("[ChatSettingsScreen] _initializeState: OpenAI type, initialConfigId '$initialConfigId' invalid or null. Defaulting to '${_selectedOpenAIConfigId}'.");
      }
    } else {
      _selectedOpenAIConfigId = null; //确保 Gemini 类型时 ID 为 null
      debugPrint("[ChatSettingsScreen] _initializeState: Gemini type, _selectedOpenAIConfigId set to null.");
    }
    debugPrint("[ChatSettingsScreen] _initializeState: Final _selectedApiType = $_selectedApiType, _selectedOpenAIConfigId = $_selectedOpenAIConfigId");
    // 标记为已初始化
    _isInitialized = true;
     debugPrint("[ChatSettingsScreen] _initializeState: End, _isInitialized = true");
  }


   // --- 保存设置 ---
   Future<void> _saveSettings() async {
      // 从 Provider 获取最新的 Chat 对象
      // 使用 read 而不是 watch，因为我们只在保存时需要它，不需要监听变化
      final chat = ref.read(currentChatProvider(widget.chatId)).value;
      if (chat == null) {
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无法保存：聊天数据丢失'), backgroundColor: Colors.red));
         return;
      }

       // 创建一个要保存的 Chat 对象副本或直接修改 (取决于 Chat 类是否可变)
       // 这里假设 Chat 类是可变的 (没有 @immutable 注解)
       final chatToSave = chat;

      // --- 从控制器/状态更新 Chat 对象 ---
      chatToSave.title = _titleController.text.trim().isEmpty ? null : _titleController.text.trim();
      chatToSave.systemPrompt = _systemPromptController.text.trim().isEmpty ? null : _systemPromptController.text.trim();

      // 更新 GenerationConfig
      // Ensure consistency with GenerationConfig class default ('gemini-pro')
      final trimmedModelName = _modelNameController.text.trim();
      chatToSave.generationConfig.modelName = trimmedModelName.isEmpty
          ? 'gemini-pro' // 标准化默认模型名称
          : trimmedModelName;
      
      // Save individual useCustom flags
      chatToSave.generationConfig.useCustomTemperature = _useCustomTemperature;
      chatToSave.generationConfig.useCustomTopP = _useCustomTopP;
      chatToSave.generationConfig.useCustomTopK = _useCustomTopK;

      // Save values based on their respective flags
      chatToSave.generationConfig.temperature = _useCustomTemperature ? _temperatureValue : null;
      chatToSave.generationConfig.topP = _useCustomTopP ? _topPValue : null;
      chatToSave.generationConfig.topK = _useCustomTopK ? _topKValue : null;
      
      chatToSave.generationConfig.maxOutputTokens = int.tryParse(_maxOutputTokensController.text); // 解析失败则为 null
      // 新增：更新停止序列
      final stopSequencesText = _stopSequencesController.text.trim();
      if (stopSequencesText.isNotEmpty) {
        chatToSave.generationConfig.stopSequences = stopSequencesText.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      } else {
        chatToSave.generationConfig.stopSequences = null;
      }

      // 更新 ContextConfig
      chatToSave.contextConfig.mode = _contextMode;
      chatToSave.contextConfig.maxTurns = int.tryParse(_maxTurnsController.text) ?? 10; // 解析失败则默认为 10
      chatToSave.contextConfig.maxContextTokens = int.tryParse(_maxTokensController.text); // 解析失败则为 null

       // 更新 XML Rules
       chatToSave.xmlRules = _xmlRules; // 使用当前状态中的列表

      // 新增：更新 API 类型和 OpenAI 配置 ID
      chatToSave.apiType = _selectedApiType; // _selectedApiType is drift_enums.LlmType
      chatToSave.selectedOpenAIConfigId = (_selectedApiType == drift_enums.LlmType.openai) ? _selectedOpenAIConfigId : null; // 只有 OpenAI 类型才保存 ID

      // --- 调用仓库保存 ---
      try {
        // 使用 read 获取 ChatRepository 并保存
        await ref.read(chatRepositoryProvider).saveChat(chatToSave);
        // 保存成功后，如果 Widget 仍挂载，显示提示并返回上一页
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('设置已保存')));
           Navigator.pop(context);
        }
      } catch (e) {
        // 保存失败时，如果 Widget 仍挂载，显示错误提示
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存设置失败: $e'), backgroundColor: Colors.red));
        }
      }
   }

   // --- 显示添加/编辑 XML 规则的对话框 ---
   void _showXmlRuleDialog({DriftXmlRule? existingRule, int? ruleIndex}) { // Use DriftXmlRule
     final tagNameController = TextEditingController(text: existingRule?.tagName ?? '');
     // 对话框内的状态，用于下拉菜单选择
     drift_enums.XmlAction selectedAction = existingRule?.action ?? drift_enums.XmlAction.ignore; // Use drift_enums

     showDialog(
       context: context,
       builder: (context) {
         // 使用 StatefulBuilder 允许更新对话框内部的状态 (下拉菜单的选择)
         return StatefulBuilder(
           builder: (context, setDialogState) {
             return AlertDialog(
               title: Text(existingRule == null ? '添加 XML 规则' : '编辑 XML 规则'),
               content: Column(
                 mainAxisSize: MainAxisSize.min, // 内容高度自适应
                 children: [
                   // 标签名称输入框
                   TextField(
                     controller: tagNameController,
                     decoration: const InputDecoration(
                       labelText: 'XML 标签名称 (例如: summary)',
                       border: OutlineInputBorder(),
                     ),
                   ),
                   const SizedBox(height: 15),
                   // 处理动作下拉菜单
                   DropdownButtonFormField<drift_enums.XmlAction>( // Use drift_enums.XmlAction
                     value: selectedAction, // 当前选中的动作
                     decoration: const InputDecoration(
                        labelText: '处理动作',
                         border: OutlineInputBorder(),
                      ),
                      items: drift_enums.XmlAction.values.map((action) { // Use drift_enums.XmlAction
                        return DropdownMenuItem(
                          value: action,
                          child: Text(action.name), 
                        );
                      }).toList(),
                      // 当选择项改变时，更新对话框状态
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                             selectedAction = value;
                          });
                       }
                     },
                   ),
                 ],
               ),
               actions: [
                 TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                 TextButton(
                   onPressed: () {
                     final tagName = tagNameController.text.trim();
                     // 检查标签名称是否为空
                     if (tagName.isNotEmpty) {
                       final newRule = DriftXmlRule(tagName: tagName, action: selectedAction); // Use DriftXmlRule
                       // 更新主屏幕的状态 (setState)
                       setState(() {
                         if (ruleIndex != null) { // 如果是编辑模式
                           _xmlRules[ruleIndex] = newRule; // 替换现有规则
                         } else { // 如果是添加模式
                            // 检查是否已存在相同标签名的规则 (忽略大小写)
                            if (!_xmlRules.any((r) => r.tagName?.toLowerCase() == tagName.toLowerCase())) {
                               _xmlRules.add(newRule); // 添加新规则
                            } else {
                               // 如果已存在，显示提示信息，不关闭对话框
                               ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('该标签名称的规则已存在'), backgroundColor: Colors.orange)
                               );
                               return;
                            }
                         }
                       });
                       Navigator.pop(context); // 关闭对话框
                     } else {
                        // 如果标签名称为空，显示提示信息
                        ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('标签名称不能为空'), backgroundColor: Colors.red)
                        );
                     }
                   },
                   child: Text(existingRule == null ? '添加' : '保存'), // 根据模式显示不同按钮文本
                 ),
               ],
             );
           },
         );
       },
     );
   }

  @override
  Widget build(BuildContext context) {
    // 监听当前聊天数据流
    final chatAsync = ref.watch(currentChatProvider(widget.chatId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_showAdvancedSettings ? '高级模型设置' : '聊天设置'),
        actions: [
          Builder( // 使用 Builder 获取正确的 context
            builder: (context) {
              final ThemeData theme = Theme.of(context);
              // 获取 AppBar 的背景颜色，如果 AppBarTheme 中未指定，则默认为主题的 primaryColor
              final Color appBarBackgroundColor = theme.appBarTheme.backgroundColor ?? theme.primaryColor;
              // 判断 AppBar 背景颜色是深色还是浅色
              final Brightness appBarBrightness = ThemeData.estimateBrightnessForColor(appBarBackgroundColor);
              // 根据 AppBar 背景色的亮度选择合适的图标和文字颜色
              final Color appBarContentColor = appBarBrightness == Brightness.dark ? Colors.white : Colors.black;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 保存按钮
                  IconButton(
                    icon: Icon(Icons.save_outlined, color: appBarContentColor), // Icon can be const if color is const
                    tooltip: '保存设置',
                    onPressed: _saveSettings,
                  ),
                  // 高级选项切换按钮
                  TextButton.icon(
                    icon: Icon(_showAdvancedSettings ? Icons.settings_outlined : Icons.tune_outlined, color: appBarContentColor), // Icon can be const if color is const
                    label: Text(
                      _showAdvancedSettings ? '基本设置' : '高级选项',
                      style: TextStyle(color: appBarContentColor),
                    ),
                    onPressed: () {
                      setState(() {
                        _showAdvancedSettings = !_showAdvancedSettings;
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: appBarContentColor, // 用于涟漪效果等
                    ),
                  ),
                ],
              );
            }
          ),
        ],
      ),
      // 处理聊天数据加载状态
      body: chatAsync.when(
        data: (chat) {
          if (chat == null) return const Center(child: Text('聊天数据无法加载')); // const

          // --- 首次加载时初始化状态 ---
          // 检查 _isInitialized 标志，确保只初始化一次
          if (!_isInitialized && mounted) {
             // 使用 WidgetsBinding.instance.addPostFrameCallback 确保在 build 完成后执行 setState
             WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) { // 再次检查 mounted 状态
                   setState(() {
                      _initializeState(chat);
                   });
                }
             });
          }
          // 如果尚未初始化，显示加载指示器
          if (!_isInitialized) {
             return const Center(child: CircularProgressIndicator()); // const
          }

          // --- 构建设置表单 ---
          // 使用 GestureDetector 点击背景收起键盘
          return GestureDetector(
             onTap: () => FocusScope.of(context).unfocus(),
             // 使用 Form 可选地添加验证逻辑
             child: Form(
               child: _showAdvancedSettings
                   ? _buildAdvancedSettingsForm(context) // 显示高级设置
                   : _buildMainSettingsForm(context), // 显示主要设置
             ),
           );
        },
        // --- 聊天数据加载状态处理 ---
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('无法加载聊天设置: $err')),
      ),
    );
  }

  // --- 构建主要设置表单 ---
  Widget _buildMainSettingsForm(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0), // const
      children: [
        // --- 基本信息部分 ---
        Text('基本信息', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 15), // const
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: '聊天标题', border: OutlineInputBorder()), // const
        ),
        const SizedBox(height: 15), // const
        TextFormField(
          controller: _systemPromptController,
          decoration: const InputDecoration(labelText: '系统提示词', hintText: '定义 AI 的角色或行为...', border: OutlineInputBorder()), // const
          maxLines: 4, // 允许多行输入
          minLines: 2,
        ),
        const Divider(height: 30), // const: 分隔线

        // --- API 提供者选择 ---
        Text('API 提供者', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 15), // const
        DropdownButtonFormField<drift_enums.LlmType>( // Use drift_enums.LlmType
          value: _selectedApiType,
          decoration: const InputDecoration(labelText: '选择 API 类型', border: OutlineInputBorder()), // const
          items: drift_enums.LlmType.values.map((type) => DropdownMenuItem( // Use drift_enums.LlmType
            value: type,
            child: Text(type == drift_enums.LlmType.gemini ? 'Google Gemini' : 'OpenAI 兼容 API'),
          )).toList(),
          onChanged: (value) {
            if (value != null) {
              debugPrint("[ChatSettingsScreen] API Type Dropdown onChanged: New LlmType selected = $value");
              setState(() {
                _selectedApiType = value;
                // 检查并设置 OpenAI 配置 ID
                if (value == drift_enums.LlmType.openai) { // Use drift_enums.LlmType
                  final availableConfigs = ref.read(apiKeyNotifierProvider).openAIConfigs; // This is List<DriftOpenAIAPIConfig>
                  debugPrint("[ChatSettingsScreen] API Type Dropdown: Switched to OpenAI. availableConfigs.length = ${availableConfigs.length}, current _selectedOpenAIConfigId = $_selectedOpenAIConfigId");
                  final currentIdIsValid = _selectedOpenAIConfigId != null && availableConfigs.any((c) => c.id == _selectedOpenAIConfigId);
                  if (!currentIdIsValid && availableConfigs.isNotEmpty) {
                    _selectedOpenAIConfigId = availableConfigs.first.id;
                    debugPrint("[ChatSettingsScreen] API Type Dropdown: OpenAI, currentId invalid. Defaulting _selectedOpenAIConfigId to '${availableConfigs.first.id}'.");
                  } else if (availableConfigs.isEmpty) {
                    _selectedOpenAIConfigId = null;
                     debugPrint("[ChatSettingsScreen] API Type Dropdown: OpenAI, no available configs. _selectedOpenAIConfigId set to null.");
                  } else if (currentIdIsValid) {
                    debugPrint("[ChatSettingsScreen] API Type Dropdown: OpenAI, currentId '$_selectedOpenAIConfigId' is valid. No change to _selectedOpenAIConfigId.");
                  }
                } else {
                  _selectedOpenAIConfigId = null;
                  debugPrint("[ChatSettingsScreen] API Type Dropdown: Switched to Gemini. _selectedOpenAIConfigId set to null.");
                }
              });
            }
          },
        ),
        const SizedBox(height: 15), // const
        // 如果选择了 OpenAI，显示配置选择下拉框
        if (_selectedApiType == LlmType.openai)
          Consumer( // 使用 Consumer 来获取最新的 OpenAI 配置列表
            builder: (context, ref, child) {
              final openAIConfigs = ref.watch(apiKeyNotifierProvider).openAIConfigs; // This is List<DriftOpenAIAPIConfig>
              // 检查当前选中的 ID 是否仍然有效
              final isValidSelection = _selectedOpenAIConfigId != null && openAIConfigs.any((c) => c.id == _selectedOpenAIConfigId);
              
              String? currentDropdownValue = isValidSelection ? _selectedOpenAIConfigId : (openAIConfigs.isNotEmpty ? openAIConfigs.first.id : null);
              
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _selectedApiType == drift_enums.LlmType.openai) { // Use drift_enums
                  debugPrint("[ChatSettingsScreen] OpenAI Dropdown Consumer addPostFrameCallback: _selectedOpenAIConfigId Before = $_selectedOpenAIConfigId, currentDropdownValue = $currentDropdownValue");
                  if (_selectedOpenAIConfigId != currentDropdownValue) {
                    setState(() {
                      _selectedOpenAIConfigId = currentDropdownValue;
                       debugPrint("[ChatSettingsScreen] OpenAI Dropdown Consumer addPostFrameCallback: setState _selectedOpenAIConfigId to $currentDropdownValue");
                    });
                  }
                }
              });

              if (openAIConfigs.isEmpty) {
                return const Text('没有可用的 OpenAI 配置。请先在全局设置中添加。', style: TextStyle(color: Colors.orange)); // const Text, const TextStyle
              }

              return DropdownButtonFormField<String>(
                value: currentDropdownValue, 
                decoration: const InputDecoration(labelText: '选择 OpenAI 配置', border: OutlineInputBorder()), // const
                items: openAIConfigs.map((config) => DropdownMenuItem( // config is DriftOpenAIAPIConfig
                  value: config.id,
                  child: Text(config.name),
                )).toList(),
                onChanged: (value) {
                  if (value != null) {
                    debugPrint("[ChatSettingsScreen] OpenAI Config Dropdown onChanged: Selected config ID = $value");
                    setState(() {
                      _selectedOpenAIConfigId = value;
                    });
                  }
                },
                 validator: (value) {
                    if (_selectedApiType == drift_enums.LlmType.openai && value == null) { // Use drift_enums
                       return '请选择一个 OpenAI 配置。';
                    }
                    return null;
                 },
              );
            }
          ),
        const Divider(height: 30), // const: 分隔线

        // --- 上下文配置部分 ---
        Text('上下文管理', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 15), // const
        // 上下文模式下拉菜单
        DropdownButtonFormField<drift_enums.ContextManagementMode>( // Use drift_enums
           value: _contextMode, 
           decoration: const InputDecoration(labelText: '上下文模式', border: OutlineInputBorder()), // const
           items: drift_enums.ContextManagementMode.values.map((mode) => DropdownMenuItem( // Use drift_enums
              value: mode,
              child: Text(mode == drift_enums.ContextManagementMode.turns ? '按轮数' : '按 Tokens (实验性)'), // Use drift_enums
           )).toList(),
           onChanged: (value) {
              if (value != null) setState(() => _contextMode = value);
           },
        ),
        const SizedBox(height: 15), // const
        // 根据选中的模式显示对应的输入框
        if (_contextMode == ContextManagementMode.turns)
          TextFormField(
            controller: _maxTurnsController,
            decoration: const InputDecoration(labelText: '最大对话轮数', border: OutlineInputBorder()), // const
            keyboardType: TextInputType.number,
          ),
        if (_contextMode == ContextManagementMode.tokens)
          TextFormField(
            controller: _maxTokensController,
            decoration: const InputDecoration(labelText: '最大 Tokens (近似值, 可选)', hintText: '留空则不限制', border: OutlineInputBorder()), // const
            keyboardType: TextInputType.number,
          ),
        const Divider(height: 30), // const

        // --- XML 处理规则部分 ---
        Row( // 标题和添加按钮在同一行
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
              Text('XML 处理规则 (${_xmlRules.length})', style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                 icon: const Icon(Icons.add_circle_outline), // const
                 tooltip: '添加规则',
                 onPressed: _showXmlRuleDialog, // 点击显示添加规则对话框
              )
           ],
        ),
        const SizedBox(height: 5), // const
        // 如果没有规则，显示提示
        if (_xmlRules.isEmpty)
           const Text('未定义任何 XML 规则。', style: TextStyle(color: Colors.grey)), // const Text, const TextStyle
         // 使用 ListView.builder 显示现有规则列表
         ListView.builder(
            shrinkWrap: true, // 高度自适应
            physics: const NeverScrollableScrollPhysics(), // const: 禁用内部滚动
            itemCount: _xmlRules.length,
            itemBuilder: (context, index) {
               final rule = _xmlRules[index];
               return ListTile(
                  title: Text('<${rule.tagName ?? "无效规则"}>'), // 显示标签名
                  subtitle: Text('动作: ${rule.action.name}'), // 显示动作名称
                  trailing: Row( // 右侧显示编辑和删除按钮
                     mainAxisSize: MainAxisSize.min,
                     children: [
                        IconButton(
                           icon: const Icon(Icons.edit_outlined, size: 20), // const
                           tooltip: '编辑规则',
                           // 点击编辑按钮，调用对话框并传入现有规则和索引
                           onPressed: () => _showXmlRuleDialog(existingRule: rule, ruleIndex: index),
                        ),
                        IconButton(
                           icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent), // const
                           tooltip: '删除规则',
                           // 点击删除按钮，直接从状态列表中移除规则并重绘
                           onPressed: () {
                              setState(() {
                                 _xmlRules.removeAt(index);
                              });
                           },
                        ),
                     ],
                  ),
                  dense: true, // 紧凑模式
               );
            },
         ),

        const SizedBox(height: 30), // const: 底部间距
        // --- 保存按钮 (已移至 AppBar) ---
        // ElevatedButton.icon(
        //   icon: const Icon(Icons.save_outlined),
        //   label: const Text('保存设置'),
        //   onPressed: _saveSettings, // 点击调用保存函数
        // ),
        const SizedBox(height: 20), // const: 列表底部额外间距
      ],
    );
  }

  // --- 构建高级模型设置表单 ---
  Widget _buildAdvancedSettingsForm(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0), // const
      children: [
        Text('模型与生成设置', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 15), // const

        // Conditionally show Model Name field only if Gemini is selected
        if (_selectedApiType == drift_enums.LlmType.gemini) ...[ // Use drift_enums
          TextFormField(
            controller: _modelNameController,
            decoration: const InputDecoration(labelText: 'Gemini 模型名称', hintText: '例如: gemini-1.5-pro-latest', border: OutlineInputBorder()), // const
          ),
          const SizedBox(height: 15), // const
        ] else if (_selectedApiType == drift_enums.LlmType.openai) ...[ // Use drift_enums
          // For OpenAI, show the selected model name (read-only) or a message if no config is selected
          Consumer(
            builder: (context, ref, child) {
            debugPrint("[ChatSettingsScreen] Advanced Settings OpenAI Consumer build: _selectedApiType = $_selectedApiType, _selectedOpenAIConfigId state = $_selectedOpenAIConfigId");
            final openAIConfigsList = ref.watch(apiKeyNotifierProvider).openAIConfigs; // This is List<DriftOpenAIAPIConfig>

            final advIsValidSelection = _selectedOpenAIConfigId != null && openAIConfigsList.any((c) => c.id == _selectedOpenAIConfigId);
            final advEffectiveConfigId = advIsValidSelection ? _selectedOpenAIConfigId : (openAIConfigsList.isNotEmpty ? openAIConfigsList.first.id : null);
            debugPrint("[ChatSettingsScreen] Advanced Settings OpenAI Consumer: Effective ID derived = $advEffectiveConfigId");

            DriftOpenAIAPIConfig displayConfig; // Use DriftOpenAIAPIConfig

            if (advEffectiveConfigId != null) {
                final foundConfig = openAIConfigsList.firstWhere(
                    (c) => c.id == advEffectiveConfigId,
                    orElse: () {
                        debugPrint("[ChatSettingsScreen] Advanced Settings OpenAI Consumer: Effective ID '$advEffectiveConfigId' NOT FOUND in configs (list length: ${openAIConfigsList.length}). Creating temporary N/A config for display.");
                        return DriftOpenAIAPIConfig(id: const Uuid().v4(), name: '未选择配置', modelName: 'N/A', baseUrl: ''); // baseUrl is required
                    }
                );
                // Create a copy for display if needed, or use directly if DriftOpenAIAPIConfig is immutable
                displayConfig = foundConfig; // Assuming DriftOpenAIAPIConfig is immutable or copy not strictly needed for display here

                if (foundConfig.id == advEffectiveConfigId && foundConfig.modelName != 'N/A') { 
                   debugPrint("[ChatSettingsScreen] Advanced Settings OpenAI Consumer: Found config using effective ID '$advEffectiveConfigId'. Displaying. Name: ${displayConfig.name}, Model: ${displayConfig.modelName}");
                }

            } else {
                debugPrint("[ChatSettingsScreen] Advanced Settings OpenAI Consumer: advEffectiveConfigId is null. Creating temporary N/A config for display.");
                displayConfig = DriftOpenAIAPIConfig(id: const Uuid().v4(), name: '未选择配置', modelName: 'N/A', baseUrl: '');// baseUrl is required
            }
            
            return ListTile(
              title: const Text('OpenAI 模型名称'), // const
              subtitle: Text(displayConfig.modelName.isNotEmpty ? displayConfig.modelName : '(来自所选配置)'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          }),
          const SizedBox(height: 15), // const
        ],
        
        TextFormField(
          controller: _maxOutputTokensController,
          decoration: const InputDecoration(labelText: '最大输出 Tokens (可选)', border: OutlineInputBorder()), // const
          keyboardType: TextInputType.number, // 数字键盘
        ),
        const SizedBox(height: 15), // const
        // 新增：停止序列输入框
        TextFormField(
          controller: _stopSequencesController,
          decoration: const InputDecoration( // const
            labelText: '停止序列 (可选)',
            hintText: '用逗号分隔, 例如: END,STOP',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          minLines: 1,
        ),
        // Removed duplicated TextFormFields for maxOutputTokens and stopSequences
        // The SizedBox(height:10) and misplaced comments were also part of the duplicated block.
        const Divider(height: 20), // const: This divider is correctly placed before the switches

        // Temperature Switch and Slider
        SwitchListTile(
          title: const Text('自定义 Temperature'), // const
          subtitle: Text(_useCustomTemperature ? (_temperatureValue?.toStringAsFixed(1) ?? '1.0') : 'API 默认'),
          value: _useCustomTemperature,
          onChanged: (bool value) {
            setState(() {
              _useCustomTemperature = value;
              if (_useCustomTemperature) {
                _temperatureValue ??= ref.read(currentChatProvider(widget.chatId)).value?.generationConfig.temperature ?? 1.0;
              } else {
                _temperatureValue = null; // Clear value when switch is off
              }
            });
          },
        ),
        Slider(
           value: _temperatureValue ?? 1.0, 
           min: 0.0, max: 2.0, divisions: 40, 
           label: (_temperatureValue ?? 1.0).toStringAsFixed(1),
           onChanged: _useCustomTemperature ? (val) => setState(() => _temperatureValue = val) : null,
        ),
        const SizedBox(height: 10), // const

         // Top P Switch and Slider
        SwitchListTile(
          title: const Text('自定义 Top P'), // const
          subtitle: Text(_useCustomTopP ? (_topPValue?.toStringAsFixed(2) ?? '0.95') : 'API 默认'),
          value: _useCustomTopP,
          onChanged: (bool value) {
            setState(() {
              _useCustomTopP = value;
              if (_useCustomTopP) {
                _topPValue ??= ref.read(currentChatProvider(widget.chatId)).value?.generationConfig.topP ?? 0.95;
              } else {
                _topPValue = null;
              }
            });
          },
        ),
        Slider(
            value: _topPValue ?? 0.95, 
            min: 0.0, max: 1.0, divisions: 100, 
            label: (_topPValue ?? 0.95).toStringAsFixed(2),
            onChanged: _useCustomTopP ? (val) => setState(() => _topPValue = val) : null,
        ),
        const SizedBox(height: 10), // const

        // Top K Switch and Slider
        SwitchListTile(
          title: const Text('自定义 Top K'), // const
          subtitle: Text(_useCustomTopK ? (_topKValue?.round().toString() ?? '40') : 'API 默认'),
          value: _useCustomTopK,
          onChanged: (bool value) {
            setState(() {
              _useCustomTopK = value;
              if (_useCustomTopK) {
                _topKValue ??= ref.read(currentChatProvider(widget.chatId)).value?.generationConfig.topK ?? 40;
              } else {
                _topKValue = null;
              }
            });
          },
        ),
        Slider(
          value: _topKValue?.toDouble() ?? 40.0, 
          min: 1.0,
          max: 100.0, 
          divisions: 99, 
          label: (_topKValue?.round() ?? 40).toString(),
          onChanged: _useCustomTopK 
              ? (val) => setState(() => _topKValue = val.round())
              : null,
        ),
        const Divider(height: 30), // const

        const SizedBox(height: 30), // const: 底部间距
        // --- 保存按钮 (已移至 AppBar) ---
        // ElevatedButton.icon(
        //   icon: const Icon(Icons.save_outlined),
        //   label: const Text('保存设置'),
        //   onPressed: _saveSettings, // 点击调用保存函数
        // ),
        const SizedBox(height: 20), // const: 列表底部额外间距
      ],
    );
  }
}
