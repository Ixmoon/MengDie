import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';

import '../../../data/models/models.dart';
import '../../providers/api_key_provider.dart';
import '../../providers/chat_state_providers.dart';
import '../cached_image.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  final int chatId;
  final TextEditingController messageController;
  const ChatInputBar({super.key, required this.chatId, required this.messageController});

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final FocusNode _inputFocusNode = FocusNode();
  final FocusNode _keyboardListenerFocusNode = FocusNode();
  final List<PlatformFile> _attachments = [];
  bool _isImageGenerationMode = false;

  @override
  void dispose() {
    _inputFocusNode.dispose();
    _keyboardListenerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
    final text = widget.messageController.text.trim();

    if (text.isEmpty && _attachments.isEmpty) {
      return;
    }

    if (_isImageGenerationMode) {
      if (text.isNotEmpty) {
        notifier.generateImage(text);
        widget.messageController.clear();
        if (mounted) FocusScope.of(context).unfocus();
      } else {
        notifier.showTopMessage('请输入图片描述。', backgroundColor: Colors.orange);
      }
      return;
    }

    List<MessagePart> parts = [];
    if (text.isNotEmpty) {
      parts.add(MessagePart.text(text));
    }

    for (var file in _attachments) {
      if (file.bytes != null) {
        final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';
        if (mimeType.startsWith('image/')) {
          parts.add(MessagePart.image(
            mimeType: mimeType,
            base64Data: base64Encode(file.bytes!),
            fileName: file.name,
          ));
        } else if (mimeType.startsWith('audio/')) {
          parts.add(MessagePart.audio(
            mimeType: mimeType,
            base64Data: base64Encode(file.bytes!),
            fileName: file.name,
          ));
        } else {
          parts.add(MessagePart.file(
            mimeType: mimeType,
            base64Data: base64Encode(file.bytes!),
            fileName: file.name,
          ));
        }
      }
    }
    
    if (parts.isNotEmpty) {
      final currentChat = await ref.read(currentChatProvider(widget.chatId).future);
      if (currentChat == null) {
        notifier.showTopMessage('错误：无法获取当前聊天信息', backgroundColor: Colors.red);
        return;
      }
      final apiConfigs = ref.read(apiKeyNotifierProvider).apiConfigs;
      if (apiConfigs.isEmpty) {
        notifier.showTopMessage('请先在全局设置中添加至少一个 API 配置', backgroundColor: Colors.orange);
        return;
      }

      notifier.sendMessage(userParts: parts);
      widget.messageController.clear();
      setState(() {
        _attachments.clear();
      });
      if (mounted) FocusScope.of(context).unfocus();
    }
  }

  Future<void> _pickFiles() async {
    final notifier = ref.read(chatStateNotifierProvider(widget.chatId).notifier);
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
      debugPrint("Error picking files: $e");
      if (mounted) {
        notifier.showTopMessage('选择文件时出错: $e', backgroundColor: Colors.red);
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
                cacheWidth: (80 * MediaQuery.of(context).devicePixelRatio).round(),
                cacheHeight: (80 * MediaQuery.of(context).devicePixelRatio).round(),
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

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatStateNotifierProvider(widget.chatId));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAttachmentsPreview(),
        SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withAlpha((255 * 0.95).round()),
                borderRadius: BorderRadius.circular(30.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  )
                ]),
            child: KeyboardListener(
              focusNode: _keyboardListenerFocusNode,
              onKeyEvent: (KeyEvent event) {
                if (!_inputFocusNode.hasFocus) return;
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.enter) {
                    if (HardwareKeyboard.instance.isShiftPressed) {
                      final currentSelection = widget.messageController.selection;
                      final newText = widget.messageController.text.replaceRange(
                        currentSelection.start,
                        currentSelection.end,
                        '\n',
                      );
                      widget.messageController.value = TextEditingValue(
                        text: newText,
                        selection: TextSelection.collapsed(offset: currentSelection.start + 1),
                      );
                    } else {
                      if ((widget.messageController.text.trim().isNotEmpty || _attachments.isNotEmpty) && !chatState.isLoading) {
                        _sendMessage();
                      }
                    }
                  }
                }
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                 IconButton(
                   icon: const Icon(Icons.image_outlined),
                   tooltip: '切换图片生成模式',
                   color: _isImageGenerationMode ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                   style: _isImageGenerationMode
                     ? IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary.withAlpha((255 * 0.1).round()))
                     : null,
                   onPressed: () {
                     setState(() {
                       _isImageGenerationMode = !_isImageGenerationMode;
                       if (_isImageGenerationMode && _attachments.isNotEmpty) {
                         _attachments.clear();
                         ref.read(chatStateNotifierProvider(widget.chatId).notifier)
                           .showTopMessage('附件已清除，图片生成模式不支持附件', backgroundColor: Colors.orange);
                       }
                     });
                   },
                 ),
                  Flexible(
                    child: TextField(
                      controller: widget.messageController,
                      focusNode: _inputFocusNode,
                      decoration: InputDecoration(
                        hintText: _isImageGenerationMode
                           ? '输入图片描述...'
                           : ((chatState.isLoading || chatState.isProcessingInBackground)
                               ? '处理中... (${chatState.elapsedSeconds ?? 0}s)'
                               : '输入消息'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        isDense: false,
                      ),
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: 1,
                      maxLines: 5,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  if (chatState.isLoading || chatState.isProcessingInBackground)
                    Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: IconButton(
                        icon: const Icon(Icons.cancel),
                        tooltip: '停止生成',
                        onPressed: () async {
                          if (!mounted) return;
                          final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('确认停止'),
                                  content: const Text('确定要停止当前的 AI 响应或后台任务吗？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(dialogContext).pop(false),
                                      child: const Text('取消'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(dialogContext).pop(true),
                                      child: Text('确认停止', style: TextStyle(color: Colors.red.shade700)),
                                    ),
                                  ],
                                ),
                              ) ?? false;
                          if (mounted && confirm) {
                            ref.read(chatStateNotifierProvider(widget.chatId).notifier).cancelGeneration();
                          }
                        },
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  if (!chatState.isLoading && !chatState.isProcessingInBackground)
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: widget.messageController,
                      builder: (context, value, child) {
                        final isSendMode = value.text.trim().isNotEmpty;
                        final canSendMessage = (value.text.trim().isNotEmpty || _attachments.isNotEmpty);

                        if (isSendMode || _isImageGenerationMode) {
                          return GestureDetector(
                            onLongPress: (chatState.isLoading || _isImageGenerationMode) ? null : _pickFiles,
                            child: IconButton(
                              icon: const Icon(Icons.send),
                              tooltip: _isImageGenerationMode ? '生成图片' : '发送 (长按添加文件)',
                              onPressed: canSendMessage ? _sendMessage : null,
                              style: IconButton.styleFrom(
                                padding: const EdgeInsets.all(12),
                              ).copyWith(
                                backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                                  (Set<WidgetState> states) {
                                    if (states.contains(WidgetState.disabled)) {
                                      return Colors.grey.shade300;
                                    }
                                    return Theme.of(context).colorScheme.primary;
                                  },
                                ),
                                foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                                  (Set<WidgetState> states) {
                                    if (states.contains(WidgetState.disabled)) {
                                      return Colors.grey.shade700;
                                    }
                                    return Theme.of(context).colorScheme.onPrimary;
                                  },
                                ),
                              ),
                            ),
                          );
                        } else {
                          return IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            tooltip: '添加文件',
                            onPressed: (chatState.isLoading || _isImageGenerationMode) ? null : _pickFiles,
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
          ),
        ),
      ],
    );
  }
}