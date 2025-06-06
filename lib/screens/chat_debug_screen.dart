import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:collection/collection.dart'; // No longer needed for lastWhereOrNull here


import '../providers/chat_state_providers.dart';
import '../services/llm_service.dart'; // For LlmContent, LlmTextPart
import '../services/context_xml_service.dart';
// import '../widgets/editable_debug_section.dart'; // No longer needed



// 此文件包含用于调试聊天上下文和携带 XML 的屏幕界面。
// XML 和上下文构建的核心逻辑已移至 ContextXmlService。

class ChatDebugScreen extends ConsumerStatefulWidget {
  final int chatId;
  const ChatDebugScreen({super.key, required this.chatId});

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
        _loadDebugContext(); // Renamed and consolidated
      }
    });
  }

  Future<void> _loadDebugContext() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorLoadingContext = "";
    });

    final chat = ref.read(currentChatProvider(widget.chatId)).value;
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
      final apiRequestContext = await contextXmlService.buildApiRequestContext(
        chat: chat,
        currentUserInput: "[调试占位符]", // Placeholder for debug view
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
    final chatAsyncValue = ref.watch(currentChatProvider(widget.chatId));
    final historyLoaded = ref.watch(chatMessagesProvider(widget.chatId)).hasValue; // Still useful to know if base data is there

    return Scaffold(
      appBar: AppBar(
        title: const Text('调试信息'),
        // Refresh IconButton removed
      ),
      body: Builder(builder: (context) {
        // Adjusted loading condition slightly
        if (_isLoading && _displayedApiContextParts == null && !chatAsyncValue.hasValue && _errorLoadingContext.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!chatAsyncValue.hasValue && !historyLoaded && _errorLoadingContext.isEmpty) {
            return const Center(child: Text("正在加载聊天数据..."));
        }
        
        // If there's an error message, show it regardless of other states
        if (_errorLoadingContext.isNotEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_errorLoadingContext, style: const TextStyle(color: Colors.red)) // const
          ));
        }

        final chat = chatAsyncValue.value;
        if (chat == null) {
          // This case should be covered by the error or loading states above if chat data is truly unavailable for context building.
          // If we reach here, it implies chat might be null but no error was set by _loadDebugContext, which is unlikely.
          return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('聊天数据不可用。'))); // const
        }
        
        if (_isLoading) { // General loading state after chat data is available but context isn't yet
            return const Center(child: CircularProgressIndicator());
        }


        return ListView(
          padding: const EdgeInsets.all(16.0), // const
          children: [
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0), // const
              child: Padding(
                padding: const EdgeInsets.all(12.0), // const
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('计算出的携带 XML (只读)', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8), // const
                    Container(
                      padding: const EdgeInsets.all(8), // const
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        _displayedCarriedOverXml ?? '(无携带 XML)', // Use renamed variable
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12), // const
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0), // const
              child: Padding(
                padding: const EdgeInsets.all(12.0), // const
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
                    const SizedBox(height: 8), // const
                    Container(
                      padding: const EdgeInsets.all(8), // const
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: _buildContextDisplayWidget(), // Uses renamed _displayedApiContextParts
                    ),
                  ],
                ),
              ),
            ),
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
        style: const TextStyle(color: Colors.red, fontFamily: 'monospace', fontSize: 12), // const
      );
    } else if (_displayedApiContextParts == null || _displayedApiContextParts!.isEmpty) {
      return const SelectableText(
        "(无 API 上下文内容)",
        style: TextStyle(fontFamily: 'monospace', fontSize: 12), // const
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _displayedApiContextParts!.map((content) { // Use renamed variable
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0), // const
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "--- ${content.role} ---",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 4), // const
                if (content.parts.isNotEmpty)
                  ...content.parts.map((part) {
                    if (part is LlmTextPart) {
                      return SelectableText(
                        part.text.trim().isEmpty ? "(空文本部分)" : part.text,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12), // const
                      );
                    } else {
                      return SelectableText(
                        "[未知的 LlmPart 类型: ${part.runtimeType}]",
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontStyle: FontStyle.italic), // const
                      );
                    }
                  }).toList()
                else
                  const SelectableText(
                    "(空内容部分)",
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontStyle: FontStyle.italic), // const
                  ),
              ],
            ),
          );
        }).toList(),
      );
    }
  }
}
