import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:collection/collection.dart'; // No longer needed for lastWhereOrNull here

import '../../domain/models/models.dart';
import '../../app/providers/chat_state_providers.dart';
import '../../data/llmapi/llm_models.dart'; // For LlmContent, LlmTextPart
import '../../app/tools/context_xml_service.dart';
import '../widgets/app_card.dart';
import '../widgets/widget_utils.dart'; // 导入新的公用函数
import '../../app/providers/repository_providers.dart';
import '../../app/repositories/message_repository.dart';
import '../../app/providers/settings_providers.dart'; // Import settings providers
// 此文件包含用于调试聊天上下文和合成 XML 的屏幕界面。
// XML 和上下文构建的核心逻辑已移至 ContextXmlService。

class ChatDebugScreen extends ConsumerStatefulWidget {
  const ChatDebugScreen({super.key});

  @override
  ConsumerState<ChatDebugScreen> createState() => _ChatDebugScreenState();
}

class _ChatDebugScreenState extends ConsumerState<ChatDebugScreen> {
  List<LlmContent>? _displayedApiContextParts; // Renamed
  String? _displayedCarriedOverXml; // Renamed
  String _errorLoadingContext = "";
  bool _isLoading = false;

  // For editable context summary
  late final TextEditingController _contextSummaryController;
  late final TextEditingController _summaryRatioController;
  bool _isSummaryDirty = false;

  @override
  void initState() {
    super.initState();
    _contextSummaryController = TextEditingController();
    _summaryRatioController = TextEditingController();
    _contextSummaryController.addListener(_onSummaryChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Initialize the controller with the provider's value
        final initialRatio = ref.read(summaryRatioProvider);
        _summaryRatioController.text = (initialRatio * 100).toStringAsFixed(0);
        _loadDebugContext();
      }
    });
  }

  @override
  void dispose() {
    _contextSummaryController.removeListener(_onSummaryChanged);
    _contextSummaryController.dispose();
    _summaryRatioController.dispose();
    super.dispose();
  }

  void _onSummaryChanged() {
    final chatId = ref.read(activeChatIdProvider);
    if (chatId == null) return;
    // Use read here, we don't want to rebuild every time text changes,
    // we use a separate state variable _isSummaryDirty for that.
    final chat = ref.read(currentChatProvider(chatId)).value;
    if (chat != null) {
      final isDirty =
          _contextSummaryController.text != (chat.contextSummary ?? '');
      if (isDirty != _isSummaryDirty) {
        setState(() {
          _isSummaryDirty = isDirty;
        });
      }
    }
  }

  Future<void> _loadDebugContext() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorLoadingContext = "";
    });

    final chatId = ref.read(activeChatIdProvider);
    if (chatId == null) {
      if (mounted) {
        setState(() {
          _errorLoadingContext = "错误：没有活动的聊天。";
          _isLoading = false;
        });
      }
      return;
    }

    // 同时更新状态和加载预览
    final notifier = ref.read(chatStateNotifierProvider(chatId).notifier);
    await notifier.updateContextDebugInfo();

    final chat = ref.read(currentChatProvider(chatId)).value;
    if (chat == null) {
      if (mounted) {
        setState(() {
          _displayedApiContextParts = null;
          _displayedCarriedOverXml = null;
          _errorLoadingContext = "错误：无法加载调试上下文，缺少聊天数据。";
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final contextXmlService = ref.read(contextXmlServiceProvider);
      final messageRepo = ref.read(messageRepositoryProvider);
      final allMessages = await messageRepo.getMessagesForChat(chatId);

      // 创建一个可修改的历史记录副本
      final historyForContext = List<Message>.from(allMessages);

      // 检查是否需要添加虚拟用户消息
      if (historyForContext.isEmpty ||
          historyForContext.last.role != MessageRole.user) {
        historyForContext.add(Message(
          chatId: chatId,
          role: MessageRole.user,
          parts: [MessagePart.text("(调试占位：用户输入...)")],
        ));
      }

      // 使用 `historyOverride` 将修改后的历史记录传递给服务，以进行真实的上下文计算
      final apiRequestContext = await contextXmlService.buildApiRequestContext(
        chatId: chat.id,
        // currentUserMessage 仍然需要，我们传递被覆盖历史的最后一条消息
        currentUserMessage: historyForContext.last,
        historyOverride: historyForContext,
      );

      // 现在 apiRequestContext.contextParts 应该已经正确包含了占位消息（如果它在上下文中）
      // 无需再手动添加。
      if (mounted) {
        setState(() {
          _displayedApiContextParts = apiRequestContext.contextParts;
          _displayedCarriedOverXml = apiRequestContext.carriedOverXml;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _displayedApiContextParts = null;
          _displayedCarriedOverXml = null;
          _errorLoadingContext = "构建调试 API 上下文时出错: $e";
          _isLoading = false;
        });
      }
    }
  }

  // _handleRefresh method removed
  // _updateDisplayedApiContext method removed (merged into _loadDebugContext)

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(activeChatIdProvider, (previous, next) {
      // 当活动的聊天发生变化时，重新加载上下文。
      // 根据 Riverpod 的要求，监听器被放置在 build() 方法中。
      if (mounted) {
        if (previous != next) {
          // Reset dirty state when chat changes to avoid carrying over edit state
          // and to allow the controller to be updated with the new chat's summary.
          _isSummaryDirty = false;
        }
        _loadDebugContext();
      }
    });
    final chatId = ref.watch(activeChatIdProvider);
    if (chatId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('调试信息')),
        body: const Center(child: Text("没有活动的聊天。")),
      );
    }
    final chatAsyncValue = ref.watch(currentChatProvider(chatId));
    final historyLoaded = ref
        .watch(chatMessagesProvider(chatId))
        .hasValue; // Still useful to know if base data is there

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          shadows: <Shadow>[
            Shadow(
              color: Colors.black.withAlpha((255 * 0.5).round()),
              blurRadius: 1.0,
            ),
          ],
        ),
        title: Text(
          '调试信息',
          style: TextStyle(
            shadows: <Shadow>[
              Shadow(
                color: Colors.black.withAlpha((255 * 0.5).round()),
                blurRadius: 1.0,
              ),
            ],
          ),
        ),
        // Refresh IconButton removed
      ),
      body: Builder(
        builder: (context) {
          // Adjusted loading condition slightly
          if (_isLoading &&
              _displayedApiContextParts == null &&
              !chatAsyncValue.hasValue &&
              _errorLoadingContext.isEmpty) {
            return const SizedBox.shrink();
          }
          if (!chatAsyncValue.hasValue &&
              !historyLoaded &&
              _errorLoadingContext.isEmpty) {
            return const Center(child: Text("正在加载聊天数据..."));
          }

          // If there's an error message, show it regardless of other states
          if (_errorLoadingContext.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _errorLoadingContext,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final chat = chatAsyncValue.value;
          if (chat == null) {
            // This case should be covered by the error or loading states above if chat data is truly unavailable for context building.
            // If we reach here, it implies chat might be null but no error was set by _loadDebugContext, which is unlikely.
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('聊天数据不可用。'),
              ),
            );
          }

          // Update controller text if the chat data has changed and there are no pending edits.
          if (!_isSummaryDirty &&
              _contextSummaryController.text != (chat.contextSummary ?? '')) {
            _contextSummaryController.text = chat.contextSummary ?? '';
          }

          if (_isLoading) {
            // General loading state after chat data is available but context isn't yet
            return const SizedBox.shrink();
          }

          final screenState = ref.watch(chatStateNotifierProvider(chatId));
          final mode = screenState.contextManagementMode;

          final String title;
          final String currentLabel;
          final double progress;

          if (mode == ContextManagementMode.tokens) {
            title = '上下文状态 (Token)';
            final keptTokens = screenState.keptTokenCount ?? 0;
            final limitTokens = screenState.contextTokenLimit ?? 1;
            currentLabel = '窗口: $keptTokens / $limitTokens (Tokens)';
            progress = keptTokens / limitTokens;
          } else {
            // Default to turns
            title = '上下文状态 (轮次)';
            final keptTurns = screenState.keptMessageCount ?? 0;
            final limitTurns = screenState.contextTurnLimit ?? 1;
            currentLabel = '窗口: $keptTurns / $limitTurns (消息)';
            progress = (limitTurns > 0) ? keptTurns / limitTurns : 0.0;
          }

          final totalCount = screenState.totalMessageCount;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      minHeight: 6,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currentLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '总计: ${totalCount ?? 'N/A'} (消息)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '总结锚点 (ID):',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '${chat.lastSummarizedMessageId ?? '无'}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '手动总结设置',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _buildManualSummarySlider(),
                  ],
                ),
              ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '计算出的合成 XML (只读)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest.withAlpha(77),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        _displayedCarriedOverXml ??
                            '(无合成 XML)', // Use renamed variable
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '上下文总结',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isSummaryDirty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final scaffoldMessenger =
                                        ScaffoldMessenger.of(context);
                                    // No need to check for chat nullability again, it's handled above.
                                    final updatedChat = chat.copyWith(
                                      contextSummary:
                                          _contextSummaryController.text,
                                    );
                                    // Use the repository to save the chat, the stream provider will update automatically
                                    await ref
                                        .read(chatRepositoryProvider)
                                        .saveChat(updatedChat);

                                    if (!mounted) return;
                                    // Manually clear dirty flag and show feedback
                                    setState(() {
                                      _isSummaryDirty = false;
                                    });

                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('上下文总结已保存。'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: const Text('保存'),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.compress),
                              tooltip: '手动总结',
                              onPressed: () {
                                // Call the new manual summarization method
                                ref
                                    .read(
                                      chatStateNotifierProvider(
                                        chatId,
                                      ).notifier,
                                    )
                                    .manuallySummarizeHistory();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.open_in_full),
                              tooltip: '全屏编辑',
                              onPressed: () async {
                                final newSummary =
                                    await showFullScreenTextEditor(
                                    context,
                                    initialText:
                                        _contextSummaryController.text,
                                    title: '编辑上下文总结',
                                    chatId: chatId,
                                  );
                                if (newSummary != null) {
                                  _contextSummaryController.text = newSummary;
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest.withAlpha(77),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: TextFormField(
                        controller: _contextSummaryController,
                        maxLines: null, // Allows multiline
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: '(无上下文总结)',
                          // The parent Container provides padding and background color.
                          // Set filled to false and contentPadding to zero to avoid conflicts.
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'API 上下文预览',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        // Loading indicator for this specific section is implicitly handled by overall _isLoading
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest.withAlpha(77),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child:
                          _buildContextDisplayWidget(), // Uses renamed _displayedApiContextParts
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContextDisplayWidget() {
    if (_errorLoadingContext.isNotEmpty && _displayedApiContextParts == null) {
      return SelectableText(
        "加载API上下文预览时出错: $_errorLoadingContext",
        style: const TextStyle(
          color: Colors.red,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      );
    } else if (_displayedApiContextParts == null ||
        _displayedApiContextParts!.isEmpty) {
      return const SelectableText(
        "(无 API 上下文内容)",
        style: TextStyle(fontFamily: 'monospace', fontSize: 12),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _displayedApiContextParts!.map((content) {
          // 将每个 LlmContent 块中的所有文本部分连接起来
          final fullText = content.parts
              .whereType<LlmTextPart>()
              .map((p) => p.text)
              .join('\n');

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "--- ${content.role} ---",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  fullText.trim().isEmpty ? "(空内容部分)" : fullText,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }
  }

  Widget _buildManualSummarySlider() {
    final ratio = ref.watch(summaryRatioProvider);
    final ratioNotifier = ref.read(summaryRatioProvider.notifier);

    // Update text controller only if the widget value is different
    // to avoid cycles and allow user input.
    final controllerValue = (ratio * 100).toStringAsFixed(0);
    if (_summaryRatioController.text != controllerValue) {
      _summaryRatioController.text = controllerValue;
    }

    return Column(
      children: [
        Text(
          '保留最近 ${(ratio * 100).toStringAsFixed(0)}% 的上下文',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: ratio,
                min: 0.1,
                max: 1.0,
                divisions: 90,
                label: '${(ratio * 100).toStringAsFixed(0)}%',
                onChanged: (value) {
                  ratioNotifier.setRatio(value);
                },
              ),
            ),
            SizedBox(
              width: 60,
              child: TextFormField(
                controller: _summaryRatioController,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  suffixText: '%',
                  isDense: true,
                  contentPadding: EdgeInsets.all(8),
                ),
                keyboardType: TextInputType.number,
                onFieldSubmitted: (value) {
                  final percentage = double.tryParse(value);
                  if (percentage != null) {
                    ratioNotifier.setRatio(percentage / 100.0);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
