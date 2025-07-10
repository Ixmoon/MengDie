import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:collection/collection.dart'; // No longer needed for lastWhereOrNull here


import '../../data/models/models.dart';
import '../../providers/chat_state_providers.dart';
import '../../service/llmapi/llm_service.dart'; // For LlmContent, LlmTextPart
import '../../service/process/context_xml_service.dart';
import '../widgets/app_card.dart';
// import '../widgets/editable_debug_section.dart'; // No longer needed



// 此文件包含用于调试聊天上下文和携带 XML 的屏幕界面。
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadDebugContext();
      }
    });
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
        chat: chat,
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
    ref.listen<int?>(activeChatIdProvider, (_, __) {
      // 当活动的聊天发生变化时，重新加载上下文。
      // 根据 Riverpod 的要求，监听器被放置在 build() 方法中。
      if (mounted) {
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
                  Text('计算出的携带 XML (只读)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      _displayedCarriedOverXml ?? '(无携带 XML)', // Use renamed variable
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
                  Text('上下文总结 (只读)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      chat.contextSummary ?? '(无上下文总结)',
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
    // _isLoading is handled by the main body builder now.
    // This widget specifically focuses on displaying the context or error related to it.
    if (_errorLoadingContext.isNotEmpty && _displayedApiContextParts == null) {
       // This might be redundant if the main body already shows the error.
       // However, keeping it provides specific feedback if context parts are null due to an error during their fetch/build.
      return SelectableText( 
        "加载API上下文预览时出错: $_errorLoadingContext", // More specific error for this section
        style: const TextStyle(color: Colors.red, fontFamily: 'monospace', fontSize: 12),
      );
    } else if (_displayedApiContextParts == null || _displayedApiContextParts!.isEmpty) {
      return const SelectableText(
        "(无 API 上下文内容)",
        style: TextStyle(fontFamily: 'monospace', fontSize: 12),
      );
    } else {
      // 优化：在映射之前一次性获取消息列表
      final chatId = ref.read(activeChatIdProvider);
      if (chatId == null) return const SizedBox.shrink();
      final messages = ref.read(chatMessagesProvider(chatId)).value;
      final bool messagesAvailable = messages != null && messages.isNotEmpty;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _displayedApiContextParts!.asMap().entries.map((entry) {
          final int contentIndex = entry.key;
          final LlmContent content = entry.value;

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
                if (content.parts.isNotEmpty)
                  ...content.parts.map((part) {
                    if (part is LlmTextPart) {
                      // 优化：使用预先计算的索引和消息列表
                      final message = (messagesAvailable && contentIndex < messages.length)
                          ? messages[contentIndex]
                          : null;
                      final originalXml = message?.originalXmlContent;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            part.text.trim().isEmpty ? "(空文本部分)" : part.text,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                          if (originalXml != null && originalXml.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '--- 原始XML (被后处理覆盖) ---',
                                style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.orange.shade800, fontStyle: FontStyle.italic),
                              ),
                            ),
                          if (originalXml != null && originalXml.isNotEmpty)
                            SelectableText(
                              originalXml,
                              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.orange.shade900),
                            ),
                        ],
                      );
                    } else {
                      return SelectableText(
                        "[未知的 LlmPart 类型: ${part.runtimeType}]",
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontStyle: FontStyle.italic),
                      );
                    }
                  })
                else
                  const SelectableText(
                    "(空内容部分)",
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          );
        }).toList(),
      );
    }
  }
}
