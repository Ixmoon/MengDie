import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:collection/collection.dart'; // No longer needed for lastWhereOrNull here


import '../../domain/models/models.dart';
import '../../app/providers/chat_state_providers.dart';
import '../../data/llmapi/llm_models.dart'; // For LlmContent, LlmTextPart
import '../../app/tools/context_xml_service.dart';
import '../widgets/app_card.dart';
import '../widgets/fullscreen_text_editor.dart';
// import '../widgets/editable_debug_section.dart'; // No longer needed
import '../../app/providers/chat_state/chat_data_providers.dart';
import '../../app/providers/repository_providers.dart';



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
  bool _isSummaryDirty = false;

  @override
  void initState() {
    super.initState();
    _contextSummaryController = TextEditingController();
    _contextSummaryController.addListener(_onSummaryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadDebugContext();
      }
    });
  }

  @override
  void dispose() {
    _contextSummaryController.removeListener(_onSummaryChanged);
    _contextSummaryController.dispose();
    super.dispose();
  }

  void _onSummaryChanged() {
    final chatId = ref.read(activeChatIdProvider);
    if (chatId == null) return;
    // Use read here, we don't want to rebuild every time text changes,
    // we use a separate state variable _isSummaryDirty for that.
    final chat = ref.read(currentChatProvider(chatId)).value;
    if (chat != null) {
      final isDirty = _contextSummaryController.text != (chat.contextSummary ?? '');
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
      // Call the unified buildApiRequestContext
      // Create a placeholder message for debugging purposes
      final placeholderMessage = Message(
        chatId: chat.id,
        role: MessageRole.user,
        parts: [MessagePart.text("[调试占位符]")],
      );
      final apiRequestContext = await contextXmlService.buildApiRequestContext(
        chatId: chat.id,
        currentUserMessage: placeholderMessage,
      );

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
    final historyLoaded = ref.watch(chatMessagesProvider(chatId)).hasValue; // Still useful to know if base data is there

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          shadows: <Shadow>[
            Shadow(color: Colors.black.withAlpha((255 * 0.5).round()), blurRadius: 1.0)
          ],
        ),
        title: Text(
          '调试信息',
          style: TextStyle(
            shadows: <Shadow>[
              Shadow(color: Colors.black.withAlpha((255 * 0.5).round()), blurRadius: 1.0)
            ],
          ),
        ),
        // Refresh IconButton removed
      ),
      body: Builder(builder: (context) {
        // Adjusted loading condition slightly
        if (_isLoading && _displayedApiContextParts == null && !chatAsyncValue.hasValue && _errorLoadingContext.isEmpty) {
          return const SizedBox.shrink();
        }
        if (!chatAsyncValue.hasValue && !historyLoaded && _errorLoadingContext.isEmpty) {
            return const Center(child: Text("正在加载聊天数据..."));
        }
        
        // If there's an error message, show it regardless of other states
        if (_errorLoadingContext.isNotEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_errorLoadingContext, style: const TextStyle(color: Colors.red))
          ));
        }

        final chat = chatAsyncValue.value;
        if (chat == null) {
          // This case should be covered by the error or loading states above if chat data is truly unavailable for context building.
          // If we reach here, it implies chat might be null but no error was set by _loadDebugContext, which is unlikely.
          return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('聊天数据不可用。')));
        }
        
        // Update controller text if the chat data has changed and there are no pending edits.
        if (!_isSummaryDirty && _contextSummaryController.text != (chat.contextSummary ?? '')) {
          _contextSummaryController.text = chat.contextSummary ?? '';
        }
        
        if (_isLoading) { // General loading state after chat data is available but context isn't yet
            return const SizedBox.shrink();
        }


        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('计算出的合成 XML (只读)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      _displayedCarriedOverXml ?? '(无合成 XML)', // Use renamed variable
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
                      Text('上下文总结', style: Theme.of(context).textTheme.titleMedium),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isSummaryDirty)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ElevatedButton(
                                onPressed: () async {
                                  // No need to check for chat nullability again, it's handled above.
                                  final updatedChat = chat.copyWith(contextSummary: _contextSummaryController.text);
                                  // Use the repository to save the chat, the stream provider will update automatically
                                  await ref.read(chatRepositoryProvider).saveChat(updatedChat);
                                  
                                  // Manually clear dirty flag and show feedback
                                  setState(() {
                                    _isSummaryDirty = false;
                                  });

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('上下文总结已保存。'), duration: Duration(seconds: 2)),
                                    );
                                  }
                                },
                                child: const Text('保存'),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.compress),
                            tooltip: '手动总结',
                            onPressed: () {
                              // Call the new manual summarization method
                              ref.read(chatStateNotifierProvider(chatId).notifier).manuallySummarizeHistory();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.open_in_full),
                            tooltip: '全屏编辑',
                            onPressed: () async {
                              final newSummary = await Navigator.of(context).push<String?>(
                                MaterialPageRoute(
                                  builder: (context) => FullScreenTextEditorScreen(
                                    initialText: _contextSummaryController.text,
                                    title: '编辑上下文总结',
                                  ),
                                ),
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
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: TextFormField(
                      controller: _contextSummaryController,
                      maxLines: null, // Allows multiline
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
                      Text('API 上下文预览', style: Theme.of(context).textTheme.titleMedium),
                      // Loading indicator for this specific section is implicitly handled by overall _isLoading
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _buildContextDisplayWidget(), // Uses renamed _displayedApiContextParts
                  ),
                ],
              ),
            )
          ],
        );
      }),
    );
  }

  Widget _buildContextDisplayWidget() {
    if (_errorLoadingContext.isNotEmpty && _displayedApiContextParts == null) {
      return SelectableText( 
        "加载API上下文预览时出错: $_errorLoadingContext",
        style: const TextStyle(color: Colors.red, fontFamily: 'monospace', fontSize: 12),
      );
    } else if (_displayedApiContextParts == null || _displayedApiContextParts!.isEmpty) {
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
                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
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
}
