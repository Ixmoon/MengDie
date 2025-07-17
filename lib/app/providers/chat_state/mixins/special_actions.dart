import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart'; // For Color

import '../../../../domain/models/api_config.dart';
import '../../../../domain/models/message.dart';
import '../../../../domain/enums.dart'; // For MessageRole and HelpMeReplyTriggerMode
import '../../../../data/llmapi/llm_service.dart';
import '../../../tools/context_xml_service.dart';
import '../../../../ui/screens/chat_settings_screen.dart' show defaultHelpMeReplyPrompt;
import '../../settings_providers.dart';
import '../chat_screen_state.dart';
import '../chat_data_providers.dart';
import '../../../repositories/message_repository.dart';
import '../special_action_type.dart';
mixin SpecialActions on StateNotifier<ChatScreenState> {
    // Abstract dependencies that must be implemented by the class using this mixin.
    Ref get ref;
    int get chatId;
    String? getEffectiveApiConfigId({String? specificConfigId});
    ApiConfig getEffectiveApiConfig({String? specificConfigId});
    void showTopMessage(String text, {Color? backgroundColor, Duration duration = const Duration(seconds: 3)});
    Future<void> sendMessage({
        List<MessagePart>? userParts,
        Message? userMessage,
        bool isRegeneration = false,
        bool isContinuation = false,
        String? promptOverride,
        int? messageToUpdateId,
        String? apiConfigIdOverride,
    });
    void startUpdateTimer();
    void stopUpdateTimer();
    bool get mounted;


    // Constants
    static const int _kSuggestionsPerPage = 5;

    // --- Special Actions ---

    Future<void> generateImage(Message userMessage) async {
        if (state.isLoading) {
            debugPrint("generateImage ($chatId) cancelled: already loading.");
            return;
        }

        final messageRepo = ref.read(messageRepositoryProvider);
        
        // 1. Set loading state and show a temporary placeholder message in the UI.
        final tempMessageId = -DateTime.now().millisecondsSinceEpoch;
        final placeholderMessage = Message(
            id: tempMessageId,
            chatId: chatId,
            role: MessageRole.model,
            parts: [MessagePart.text("正在生成图片...")],
        );

        state = state.copyWith(
            isLoading: true,
            isPrimaryResponseLoading: true,
            isCancelled: false,
            clearError: true,
            clearTopMessage: true,
            generationStartTime: DateTime.now(),
            streamingMessage: placeholderMessage,
            isStreamingMessageVisible: true,
        );
        startUpdateTimer();

        try {
            final llmService = ref.read(llmServiceProvider);
            final contextXmlService = ref.read(contextXmlServiceProvider);
            final apiConfig = getEffectiveApiConfig();

            // 2. Build context-aware request
            final apiRequestContext = await contextXmlService.buildApiRequestContext(
              chatId: chatId,
              currentUserMessage: userMessage,
              keepAsSystemPrompt: true, // Keep system prompt for context
            );

            final response = await llmService.generateImage(
              llmContext: apiRequestContext.contextParts,
              apiConfig: apiConfig
            );

            if (!mounted || state.isCancelled) {
                return;
            }

            // 3. Process response
            if (response.isSuccess && (response.base64Images.isNotEmpty || (response.text?.isNotEmpty ?? false))) {
                List<MessagePart> parts = [];
                if (response.text != null && response.text!.isNotEmpty) {
                    parts.add(MessagePart.text(response.text!));
                }
                if (response.base64Images.isNotEmpty) {
                    parts.addAll(response.base64Images.map(
                        (base64) => MessagePart.generatedImage(
                            base64Data: base64,
                            prompt: userMessage.rawText,
                        ),
                    ));
                }

                if (parts.isNotEmpty) {
                    final modelMessage = Message(
                        chatId: chatId,
                        role: MessageRole.model,
                        parts: parts,
                    );
                    await messageRepo.saveMessage(modelMessage);
                }
                
                showTopMessage('生成成功', backgroundColor: Colors.green);

            } else {
                showTopMessage(response.error ?? "图片生成失败", backgroundColor: Colors.red);
            }
        } catch (e) {
            if (mounted) {
                showTopMessage('生成图片时出错: $e', backgroundColor: Colors.red);
            }
        } finally {
            if (mounted) {
                state = state.copyWith(
                    isLoading: false,
                    isPrimaryResponseLoading: false,
                    clearStreamingMessage: true,
                );
                stopUpdateTimer();
            }
        }
    }

    Future<void> resumeGeneration() async {
        if (state.isLoading) {
            showTopMessage('正在生成中，请稍后...', backgroundColor: Colors.orange);
            return;
        }

        final lastMessage = ref.read(lastModelMessageProvider(chatId));
        if (lastMessage == null) {
            showTopMessage('没有可恢复的消息', backgroundColor: Colors.orange);
            return;
        }

        final globalSettings = ref.read(globalSettingsProvider);
        if (!globalSettings.enableResume) {
            showTopMessage('中断恢复功能已禁用', backgroundColor: Colors.orange);
            return;
        }

        await sendMessage(
            isContinuation: true,
            promptOverride: globalSettings.resumePrompt,
            messageToUpdateId: lastMessage.id,
            apiConfigIdOverride: getEffectiveApiConfigId(
                specificConfigId: globalSettings.resumeApiConfigId,
            ),
        );
    }

    Future<void> generateHelpMeReply({Function(List<String>)? onSuggestionsReady, bool forceRefresh = false}) async {
        if (!mounted) return;
        state = state.copyWith(isCancelled: false, isGeneratingSuggestions: true);

        try {
            final bool hasExistingSuggestions = state.helpMeReplySuggestions != null && state.helpMeReplySuggestions!.isNotEmpty;

            if (!forceRefresh && hasExistingSuggestions) {
                debugPrint("ChatStateNotifier($chatId): Using cached 'Help Me Reply' suggestions.");
                if (onSuggestionsReady != null) {
                    final currentPage = state.helpMeReplySuggestions![state.helpMeReplyPageIndex];
                    onSuggestionsReady(currentPage);
                }
                return;
            }

            final lastMessage = ref.read(lastModelMessageProvider(chatId));
            if (lastMessage == null) {
                if (onSuggestionsReady != null) showTopMessage('没有可供回复的消息', backgroundColor: Colors.orange);
                return;
            }

            final chat = ref.read(currentChatProvider(chatId)).value;
            if (chat == null) {
                if (onSuggestionsReady != null) showTopMessage('无法获取聊天设置', backgroundColor: Colors.red);
                return;
            }
            if (!chat.enableHelpMeReply) {
                if (onSuggestionsReady != null) showTopMessage('“帮我回复”功能在此聊天中已禁用', backgroundColor: Colors.orange);
                return;
            }

            try {
                final apiConfig = getEffectiveApiConfig(specificConfigId: chat.helpMeReplyApiConfigId);
                final generatedText = await executeSpecialAction(
                    prompt: chat.helpMeReplyPrompt ?? defaultHelpMeReplyPrompt,
                    apiConfig: apiConfig,
                    actionType: SpecialActionType.helpMeReply,
                    targetMessage: lastMessage,
                );

                final newSuggestions = RegExp(r'^\s*\d+\.\s*(.*)', multiLine: true)
                    .allMatches(generatedText)
                    .map((m) => m.group(1)!.trim())
                    .toList();
                final finalSuggestions = newSuggestions.isNotEmpty ? newSuggestions : [generatedText.trim()];
                
                if (mounted) {
                    final List<List<String>> newPages = [];
                    for (var i = 0; i < finalSuggestions.length; i += _kSuggestionsPerPage) {
                        final end = (i + _kSuggestionsPerPage < finalSuggestions.length) ? i + _kSuggestionsPerPage : finalSuggestions.length;
                        newPages.add(finalSuggestions.sublist(i, end));
                    }

                    final clearPreviousSuggestions = !hasExistingSuggestions;
                    final currentPages = clearPreviousSuggestions ? <List<String>>[] : (state.helpMeReplySuggestions ?? []);
                    final updatedPages = List<List<String>>.from(currentPages)..addAll(newPages);
                    
                    state = state.copyWith(
                        helpMeReplySuggestions: updatedPages,
                        helpMeReplyPageIndex: updatedPages.length - 1,
                    );

                    onSuggestionsReady?.call(newPages.isNotEmpty ? newPages.first : []);
                }
            } catch (e) {
                if (mounted && !state.isCancelled) {
                    showTopMessage(e.toString(), backgroundColor: Colors.red);
                }
            }
        } finally {
            if (mounted) {
                state = state.copyWith(isGeneratingSuggestions: false);
            }
        }
    }

    void clearHelpMeReplySuggestions() {
        if (!mounted) return;
        if (state.helpMeReplySuggestions != null) {
            state = state.copyWith(clearHelpMeReplySuggestions: true);
        }
    }

    void changeHelpMeReplyPage(int delta) {
        if (!mounted || state.helpMeReplySuggestions == null) return;
        final newIndex = state.helpMeReplyPageIndex + delta;
        if (newIndex >= 0 && newIndex < state.helpMeReplySuggestions!.length) {
            state = state.copyWith(helpMeReplyPageIndex: newIndex);
        }
    }

    Future<String> executeSpecialAction({
        required String prompt,
        required ApiConfig apiConfig,
        required SpecialActionType actionType,
        required Message targetMessage,
    }) async {
        const maxRetries = 3;
        final chat = ref.read(currentChatProvider(chatId)).value;
        if (chat == null) {
            throw Exception('无法执行操作：聊天数据未加载');
        }

        final contextXmlService = ref.read(contextXmlServiceProvider);
        final llmService = ref.read(llmServiceProvider);

        final apiRequestContext = await contextXmlService.buildApiRequestContext(
            chatId: chatId,
            currentUserMessage: targetMessage,
            chatSystemPromptOverride: prompt,
            lastMessageOverride: prompt,
            keepAsSystemPrompt: false,
        );

        for (int attempt = 1; attempt <= maxRetries; attempt++) {
            if (state.isCancelled) {
                throw Exception("Operation cancelled by user.");
            }

            try {
                final response = await llmService.sendMessageOnce(
                    llmContext: apiRequestContext.contextParts,
                    apiConfig: apiConfig,
                );

                if (!mounted || state.isCancelled) {
                    throw Exception("Operation cancelled by user.");
                }

                if (response.isSuccess && response.parts.isNotEmpty) {
                    final generatedText = response.parts.map((p) => p.text ?? "").join("\n");
                    debugPrint("ChatStateNotifier($chatId): Special action '$actionType' successful on attempt $attempt.");
                    return generatedText;
                } else {
                    throw Exception("API Error: ${response.error ?? 'Empty response'}");
                }
            } catch (e) {
                debugPrint("ChatStateNotifier($chatId): Special action '$actionType' attempt $attempt/$maxRetries failed: $e");
                if (attempt == maxRetries || state.isCancelled) {
                    rethrow;
                }
                await Future.delayed(Duration(seconds: attempt * 2));
            }
        }
        throw Exception("Special action '$actionType' failed after $maxRetries attempts.");
    }
}