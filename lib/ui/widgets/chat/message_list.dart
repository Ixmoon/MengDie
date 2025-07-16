import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/models.dart';
import '../../providers/api_key_provider.dart';
import '../../providers/chat_state_providers.dart';
import '../../providers/settings_providers.dart';
import '../message_bubble.dart';

class MessageList extends ConsumerStatefulWidget {
  final int chatId;
  final ScrollController scrollController;
  final void Function(Message, List<Message>) onMessageTap;
  final Function(String) onSuggestionSelected;

  const MessageList({
    super.key,
    required this.chatId,
    required this.scrollController,
    required this.onMessageTap,
    required this.onSuggestionSelected,
  });

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Message>>>(chatMessagesProvider(widget.chatId), (previous, next) {
      if (previous == next) return;

      if (next is! AsyncData || !next.hasValue || next.requireValue.isEmpty) {
        return;
      }

      final chatState = ref.read(chatStateNotifierProvider(widget.chatId));
      if (chatState.isLoading) return;
      
      ref.read(chatStateNotifierProvider(widget.chatId).notifier).calculateAndStoreTokenCount();
    });

    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final chatState = ref.watch(chatStateNotifierProvider(widget.chatId));

    return messagesAsync.when(
      data: (dbMessages) {
        if ((chatState.totalTokens ?? 0) == 0 && !chatState.isLoading && dbMessages.isNotEmpty) {
          final apiConfigs = ref.read(apiKeyNotifierProvider).apiConfigs;
          if (apiConfigs.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.read(chatStateNotifierProvider(widget.chatId).notifier).calculateAndStoreTokenCount();
              }
            });
          }
        }
        
        final streamingMessage = chatState.streamingMessage;
        final List<Message> allMessages;

        if (chatState.isStreamingMessageVisible && streamingMessage != null) {
          final tempMessages = dbMessages.where((m) => m.id != streamingMessage.id).toList();
          tempMessages.add(streamingMessage);
          allMessages = tempMessages;
        } else {
          allMessages = dbMessages;
        }

        return ListView.builder(
          reverse: true,
          controller: widget.scrollController,
          padding: const EdgeInsets.all(8.0),
          itemCount: allMessages.length,
          itemBuilder: (context, index) {
            final message = allMessages[allMessages.length - 1 - index];
            final isLastMessage = index == 0;
            final isThisMessageStreaming = chatState.isStreaming && streamingMessage != null && message.id == streamingMessage.id;

            Widget buildMessageItem() {
              return MessageBubble(
                key: ValueKey(message.id),
                message: message,
                isStreaming: isThisMessageStreaming,
                isTransparent: chatState.isBubbleTransparent,
                isHalfWidth: chatState.isBubbleHalfWidth,
                onTap: () => widget.onMessageTap(message, allMessages),
                totalTokens: isLastMessage && !isThisMessageStreaming ? chatState.totalTokens : null,
              );
            }
            
            Widget buildActionButtons() {
              final chatState = ref.watch(chatStateNotifierProvider(widget.chatId));
              final canPerformAction = isLastMessage &&
                                     allMessages.isNotEmpty &&
                                     allMessages.last.role == MessageRole.model &&
                                     !chatState.isLoading;

              if (!canPerformAction) return const SizedBox.shrink();

              final chat = ref.watch(currentChatProvider(widget.chatId)).value;
              final globalSettings = ref.watch(globalSettingsProvider);
              final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);

              if (chat == null) return const SizedBox.shrink();

              List<Widget> buttons = [];

              // Continue Button
              buttons.add(
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('续写'),
                  onPressed: notifier.continueGeneration,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              );

              // Resume Button
              if (globalSettings.enableResume) {
                buttons.add(const SizedBox(width: 8));
                buttons.add(
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.replay_circle_filled_rounded, size: 16),
                    label: const Text('中断恢复'),
                    onPressed: notifier.resumeGeneration,
                     style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                  ),
                );
              }

              // Help Me Reply / Cancel Button
              if (chat.enableHelpMeReply) {
                buttons.add(const SizedBox(width: 8));
                if (chatState.isGeneratingSuggestions) {
                  buttons.add(
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('取消'),
                      onPressed: () => notifier.cancelGeneration(),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        backgroundColor: Colors.red.withAlpha((255 * 0.1).round()),
                        foregroundColor: Colors.red.shade700,
                      ),
                    ),
                  );
                } else {
                  buttons.add(
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.quickreply_rounded, size: 16),
                      label: const Text('帮我回复'),
                      onPressed: () {
                        notifier.generateHelpMeReply(
                          onSuggestionsReady: (suggestions) {
                            if (!mounted) return;
                            showDialog(
                              context: context,
                              builder: (dialogContext) => _HelpMeReplyDialog(
                                chatId: widget.chatId,
                                initialSuggestions: suggestions,
                                onSuggestionSelected: widget.onSuggestionSelected,
                              ),
                            );
                          },
                        );
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  );
                }
              }

              return Padding(
                padding: const EdgeInsets.only(top: 4.0, left: 16.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  alignment: WrapAlignment.start,
                  children: buttons,
                ),
              );
            }

            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildMessageItem(),
                  buildActionButtons(),
                ],
              );
            }
            return buildMessageItem();
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => Center(child: Text("无法加载消息: $err")),
    );
  }
}


class _HelpMeReplyDialog extends ConsumerStatefulWidget {
  final int chatId;
  final List<String> initialSuggestions;
  final Function(String) onSuggestionSelected;

  const _HelpMeReplyDialog({
    required this.chatId,
    required this.initialSuggestions,
    required this.onSuggestionSelected,
  });

  @override
  ConsumerState<_HelpMeReplyDialog> createState() => _HelpMeReplyDialogState();
}

class _HelpMeReplyDialogState extends ConsumerState<_HelpMeReplyDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatStateNotifierProvider(widget.chatId));
    final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
    final allSuggestionPages = chatState.helpMeReplySuggestions ?? [];
    final pageIndex = chatState.helpMeReplyPageIndex;
    final currentSuggestions = (allSuggestionPages.isNotEmpty && pageIndex < allSuggestionPages.length)
        ? allSuggestionPages[pageIndex]
        : <String>[];
    final totalPages = allSuggestionPages.length;
    final isGenerating = chatState.isGeneratingSuggestions;

    if (isGenerating && !_animationController.isAnimating) {
      _animationController.repeat();
    } else if (!isGenerating && _animationController.isAnimating) {
      _animationController.stop();
    }

    Widget contentWidget;
    if (isGenerating && allSuggestionPages.isEmpty) {
      contentWidget = const Center(child: CircularProgressIndicator());
    } else if (allSuggestionPages.isEmpty) {
      contentWidget = const Center(child: Text('没有可用的建议。'));
    } else {
      contentWidget = Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: ListView(
          shrinkWrap: true,
          children: currentSuggestions.map((s) => ListTile(
            title: Text(s),
            onTap: () {
              widget.onSuggestionSelected(s);
              Navigator.of(context).pop();
            },
          )).toList(),
        ),
      );
    }

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0),
      content: contentWidget,
      actionsPadding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 12.0),
      actions: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (totalPages > 0)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: (isGenerating || pageIndex <= 0) ? null : () => notifier.changeHelpMeReplyPage(-1),
                  ),
                  Text('${pageIndex + 1}/$totalPages'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: (isGenerating || pageIndex >= totalPages - 1) ? null : () => notifier.changeHelpMeReplyPage(1),
                  ),
                ],
              )
            else
              const SizedBox(),
            
            Row(
              children: [
                RotationTransition(
                  turns: _animationController,
                  child: IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: '获取新选项',
                    onPressed: isGenerating ? null : () {
                      notifier.generateHelpMeReply(
                        forceRefresh: true,
                        onSuggestionsReady: (suggestions) {
                        },
                      );
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}