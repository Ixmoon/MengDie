import 'dart:convert';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';

import '../../../domain/models/models.dart';
import '../../../app/providers/api_key_provider.dart';
import '../../../app/providers/chat_settings_provider.dart';
import '../../../app/providers/chat_state_providers.dart';
import '../cached_image.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  final int chatId;
  final TextEditingController messageController;
  const ChatInputBar({
    super.key,
    required this.chatId,
    required this.messageController,
  });

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final FocusNode _inputFocusNode = FocusNode();
  final FocusNode _keyboardListenerFocusNode = FocusNode();
  final List<PlatformFile> _attachments = [];
  bool _isChinesePunctuation = true;
  bool _isSwitchingApi = false;

  @override
  void dispose() {
    _inputFocusNode.dispose();
    _keyboardListenerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final notifier = ref.read(
      chatStateNotifierProvider(widget.chatId).notifier,
    );
    final text = widget.messageController.text.trim();

    if (text.isEmpty && _attachments.isEmpty) {
      return;
    }

    List<MessagePart> parts = [];
    if (text.isNotEmpty) {
      parts.add(MessagePart.text(text));
    }

    for (var file in _attachments) {
      if (file.bytes != null) {
        final mimeType =
            lookupMimeType(file.name) ?? 'application/octet-stream';
        if (mimeType.startsWith('image/')) {
          parts.add(
            MessagePart.image(
              mimeType: mimeType,
              base64Data: base64Encode(file.bytes!),
              fileName: file.name,
            ),
          );
        } else if (mimeType.startsWith('audio/')) {
          parts.add(
            MessagePart.audio(
              mimeType: mimeType,
              base64Data: base64Encode(file.bytes!),
              fileName: file.name,
            ),
          );
        } else {
          parts.add(
            MessagePart.file(
              mimeType: mimeType,
              base64Data: base64Encode(file.bytes!),
              fileName: file.name,
            ),
          );
        }
      }
    }

    if (parts.isNotEmpty) {
      final currentChat = await ref.read(
        currentChatProvider(widget.chatId).future,
      );
      if (!mounted) return;
      if (currentChat == null) {
        notifier.showTopMessage('错误：无法获取当前聊天信息', backgroundColor: Colors.red);
        return;
      }
      final apiConfigs = ref.read(apiKeyNotifierProvider).apiConfigs;
      if (apiConfigs.isEmpty) {
        notifier.showTopMessage(
          '请先在全局设置中添加至少一个 API 配置',
          backgroundColor: Colors.orange,
        );
        return;
      }

      notifier.sendMessage(userParts: parts, requestThoughts: true);
      widget.messageController.clear();
      setState(() {
        _attachments.clear();
      });
      if (mounted) FocusScope.of(context).unfocus();
    }
  }

  Future<void> _pickFiles() async {
    final notifier = ref.read(
      chatStateNotifierProvider(widget.chatId).notifier,
    );
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: true,
      );

      if (result != null) {
        setState(() {
          _attachments.addAll(result.files.where((file) => file.bytes != null));
        });
      }
    } catch (e) {
      if (mounted) {
        notifier.showTopMessage('选择文件时出错: $e', backgroundColor: Colors.red);
      }
    }
  }

  void _insertText(String left, String right) {
    final text = widget.messageController.text;
    final selection = widget.messageController.selection;
    final middle = selection.textInside(text);
    final newText =
        selection.textBefore(text) +
        left +
        middle +
        right +
        selection.textAfter(text);

    widget.messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + left.length + middle.length,
      ),
    );
  }

  Future<void> _showApiConfigSwitcherDialog() async {
    final allConfigs = ref.read(apiKeyNotifierProvider).apiConfigs;
    final chatSettings = ref.read(chatSettingsProvider(widget.chatId));
    final currentConfigId = chatSettings.chatForDisplay?.apiConfigId;

    if (allConfigs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('没有可用的 API 配置。'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final String? selectedId = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('选择 API 配置'),
          children: allConfigs.map((config) {
            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, config.id);
              },
              child: ListTile(
                title: Text(config.name),
                trailing: config.id == currentConfigId
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );

    if (selectedId != null && selectedId != currentConfigId) {
      setState(() {
        _isSwitchingApi = true;
      });
      try {
        final notifier = ref.read(chatSettingsProvider(widget.chatId).notifier);
        notifier.updateSettings(
          (chat) => chat.copyWith(apiConfigId: selectedId),
        );
        await notifier.saveSettings();
        if (mounted) {
          final newConfig = allConfigs.firstWhere((c) => c.id == selectedId);
          ref
              .read(chatStateNotifierProvider(widget.chatId).notifier)
              .showTopMessage(
                'API 已切换为: ${newConfig.name}',
                backgroundColor: Colors.green,
              );
        }
      } catch (e) {
        if (mounted) {
          ref
              .read(chatStateNotifierProvider(widget.chatId).notifier)
              .showTopMessage('API 切换失败: $e', backgroundColor: Colors.red);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSwitchingApi = false;
          });
        }
      }
    }
  }

  Widget _buildAttachmentsPreview() {
    if (_attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _attachments.length,
        itemBuilder: (context, index) {
          final file = _attachments[index];
          final mimeType = lookupMimeType(file.name) ?? '';
          final isImage = mimeType.startsWith('image/');
          final isAudio = mimeType.startsWith('audio/');

          Widget previewChild;
          if (isImage) {
            previewChild = ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedImageFromBase64(
                base64String: base64Encode(file.bytes!),
                fit: BoxFit.cover,
                width: 80,
                height: 80,
                cacheWidth: (80 * MediaQuery.of(context).devicePixelRatio)
                    .round(),
                cacheHeight: (80 * MediaQuery.of(context).devicePixelRatio)
                    .round(),
              ),
            );
          } else if (isAudio) {
            previewChild = Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.audiotrack_outlined, size: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    file.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          } else {
            previewChild = Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.insert_drive_file_outlined, size: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    file.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: previewChild,
                ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: Material(
                    color: Colors.transparent,
                    child: IconButton(
                      icon: const Icon(Icons.cancel),
                      iconSize: 20,
                      splashRadius: 16,
                      onPressed: () {
                        setState(() {
                          _attachments.removeAt(index);
                        });
                      },
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withAlpha(204),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onPressed,
    Widget? replacement,
  }) {
    if (replacement != null) {
      return replacement;
    }
    final theme = Theme.of(context);
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      color: isSelected
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant,
      style: isSelected
          ? IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withAlpha(40),
            )
          : null,
      onPressed: onPressed,
    );
  }

  Widget _buildTextButton({
    required String text,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Tooltip(
        message: tooltip,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final chatState = ref.watch(chatStateNotifierProvider(widget.chatId));
    final notifier = ref.read(
      chatStateNotifierProvider(widget.chatId).notifier,
    );
    final chatSettings = ref.watch(chatSettingsProvider(widget.chatId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildIconButton(
                icon: Icons.settings_ethernet,
                tooltip: '切换 API 配置',
                isSelected: false,
                onPressed: _isSwitchingApi
                    ? () {}
                    : _showApiConfigSwitcherDialog,
                replacement: _isSwitchingApi
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        ),
                      )
                    : null,
              ),
              _buildIconButton(
                icon: chatState.isImageGenerationMode
                    ? Icons.image
                    : Icons.image_outlined,
                tooltip: '图片生成模式',
                isSelected: chatState.isImageGenerationMode,
                onPressed: notifier.toggleImageGenerationMode,
              ),
              _buildIconButton(
                icon: chatState.isStreamMode ? Icons.stream : Icons.chat_bubble,
                tooltip: chatState.isStreamMode ? '流式输出' : '一次性输出',
                isSelected: chatState.isStreamMode,
                onPressed: notifier.toggleOutputMode,
              ),
              _buildIconButton(
                icon: chatState.isGoogleSearchEnabled
                    ? Icons.public
                    : Icons.public_off,
                tooltip: 'Google 搜索',
                isSelected: chatState.isGoogleSearchEnabled,
                onPressed: notifier.toggleGoogleSearch,
              ),
              _buildIconButton(
                icon: chatState.isUrlContextEnabled
                    ? Icons.link
                    : Icons.link_off,
                tooltip: 'URL 上下文',
                isSelected: chatState.isUrlContextEnabled,
                onPressed: notifier.toggleUrlContext,
              ),
              _buildIconButton(
                icon: chatState.isCodeExecutionEnabled
                    ? Icons.code
                    : Icons.code_off,
                tooltip: '代码执行',
                isSelected: chatState.isCodeExecutionEnabled,
                onPressed: notifier.toggleCodeExecution,
              ),
              _buildIconButton(
                icon: chatState.highlightQuotes
                    ? Icons.format_quote
                    : Icons.format_quote_outlined,
                tooltip: '引号高亮',
                isSelected: chatState.highlightQuotes,
                onPressed: notifier.toggleHighlightQuotes,
              ),
              _buildIconButton(
                icon: Icons.biotech_outlined,
                tooltip: 'Prompt Injection',
                isSelected: false,
                onPressed: () {
                  context.go('/chat/prompt-editor');
                },
              ),
            ],
          ),
          Row(
            children: [
              _buildTextButton(
                text: '""',
                tooltip: '添加双引号',
                onPressed: () {
                  _insertText(
                    _isChinesePunctuation ? '“' : '"',
                    _isChinesePunctuation ? '”' : '"',
                  );
                },
              ),
              _buildTextButton(
                text: '()',
                tooltip: '添加括号',
                onPressed: () {
                  _insertText(
                    _isChinesePunctuation ? '（' : '(',
                    _isChinesePunctuation ? '）' : ')',
                  );
                },
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: Tooltip(
                  message: '切换中/英文标点',
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isChinesePunctuation = !_isChinesePunctuation;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: Text(
                      _isChinesePunctuation ? '中' : '英',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatStateNotifierProvider(widget.chatId));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAttachmentsPreview(),
        SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 6.0,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(30.0),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                KeyboardListener(
                  focusNode: _keyboardListenerFocusNode,
                  onKeyEvent: (KeyEvent event) {
                    if (!_inputFocusNode.hasFocus) return;
                    if (event is KeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.enter) {
                        if (HardwareKeyboard.instance.isShiftPressed) {
                          final currentSelection =
                              widget.messageController.selection;
                          final newText = widget.messageController.text
                              .replaceRange(
                                currentSelection.start,
                                currentSelection.end,
                                '\n',
                              );
                          widget.messageController.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(
                              offset: currentSelection.start + 1,
                            ),
                          );
                        } else {
                          if ((widget.messageController.text
                                      .trim()
                                      .isNotEmpty ||
                                  _attachments.isNotEmpty) &&
                              !chatState.isLoading) {
                            _sendMessage();
                          }
                        }
                      }
                    }
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: TextField(
                          controller: widget.messageController,
                          focusNode: _inputFocusNode,
                          decoration: InputDecoration(
                            hintText: chatState.isImageGenerationMode
                                ? '输入图片描述...'
                                : ((chatState.isLoading ||
                                          chatState.isProcessingInBackground)
                                      ? '处理中... (${ref.watch(generationElapsedSecondsProvider)}s)'
                                      : '输入消息'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.0),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.transparent,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 12.0,
                            ),
                            isDense: false,
                          ),
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          minLines: 1,
                          maxLines: 5,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                      const SizedBox(width: 4.0),
                      if (chatState.isLoading ||
                          chatState.isProcessingInBackground)
                        Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: IconButton(
                            icon: const Icon(Icons.cancel),
                            tooltip: '停止生成',
                            onPressed: () async {
                              if (!mounted) return;
                              final confirm =
                                  await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text('确认停止'),
                                      content: const Text(
                                        '确定要停止当前的 AI 响应或后台任务吗？',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(
                                            dialogContext,
                                          ).pop(false),
                                          child: const Text('取消'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(
                                            dialogContext,
                                          ).pop(true),
                                          child: Text(
                                            '确认停止',
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                              if (!mounted) return;
                              if (confirm) {
                                ref
                                    .read(
                                      chatStateNotifierProvider(
                                        widget.chatId,
                                      ).notifier,
                                    )
                                    .cancelGeneration();
                              }
                            },
                            style: IconButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                      if (!chatState.isLoading &&
                          !chatState.isProcessingInBackground)
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: widget.messageController,
                          builder: (context, value, child) {
                            final isSendMode = value.text.trim().isNotEmpty;
                            final canSendMessage =
                                (value.text.trim().isNotEmpty ||
                                _attachments.isNotEmpty);

                            if (isSendMode) {
                              return GestureDetector(
                                onLongPress: chatState.isLoading
                                    ? null
                                    : _pickFiles,
                                child: IconButton(
                                  icon: const Icon(Icons.send),
                                  tooltip: chatState.isImageGenerationMode
                                      ? '生成图片 (长按添加文件)'
                                      : '发送 (长按添加文件)',
                                  onPressed: canSendMessage
                                      ? _sendMessage
                                      : null,
                                  style:
                                      IconButton.styleFrom(
                                        padding: const EdgeInsets.all(12),
                                      ).copyWith(
                                        backgroundColor:
                                            WidgetStateProperty.resolveWith<
                                              Color?
                                            >((Set<WidgetState> states) {
                                              if (states.contains(
                                                WidgetState.disabled,
                                              )) {
                                                return Colors.grey.shade300;
                                              }
                                              return Theme.of(
                                                context,
                                              ).colorScheme.primary;
                                            }),
                                        foregroundColor:
                                            WidgetStateProperty.resolveWith<
                                              Color?
                                            >((Set<WidgetState> states) {
                                              if (states.contains(
                                                WidgetState.disabled,
                                              )) {
                                                return Colors.grey.shade700;
                                              }
                                              return Theme.of(
                                                context,
                                              ).colorScheme.onPrimary;
                                            }),
                                      ),
                                ),
                              );
                            } else {
                              return IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                tooltip: '添加文件',
                                onPressed: chatState.isLoading
                                    ? null
                                    : _pickFiles,
                                style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(12),
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
