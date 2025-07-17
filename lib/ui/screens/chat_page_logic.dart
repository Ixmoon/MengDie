import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../data/sync/sync_service.dart';
import '../../domain/models/models.dart';
import '../../app/providers/chat_state_providers.dart';
import '../../app/providers/repository_providers.dart';

class ChatPageLogic {
  final WidgetRef ref;
  final int chatId;
  final BuildContext context;
  final VoidCallback onStateChange;

  ChatPageLogic({
    required this.ref,
    required this.chatId,
    required this.context,
    required this.onStateChange,
  });

  bool _isPushing = false;
  bool get isPushing => _isPushing;

  void handleMessageTap(Message message, MessagePart part, List<Message> allMessages) {
    if (ref.read(chatStateNotifierProvider(chatId)).isLoading) return;

    final isUser = message.role == MessageRole.user;
    final messageIndex = allMessages.indexWhere((m) => m.id == message.id);
    final isLastUserMessage = isUser &&
        messageIndex >= 0 &&
        (messageIndex == allMessages.length - 1 ||
            (messageIndex == allMessages.length - 2 &&
                allMessages.last.role == MessageRole.model));

    showModalBottomSheet(
      context: context,
      builder: (modalContext) {
        List<Widget> options = [];
        final isTextOnly = part.type == MessagePartType.text;
        
        options.add(
          ListTile(
            leading: Icon(isTextOnly ? Icons.edit_outlined : Icons.upload_file_outlined),
            title: Text(isTextOnly ? '编辑消息' : '重新上传'),
            onTap: () {
              Navigator.pop(modalContext);
              if (isTextOnly) {
                showEditMessageDialog(message);
              } else {
                replaceAttachment(message);
              }
            },
          )
        );

        if (!isTextOnly) {
          options.add(
            ListTile(
              leading: const Icon(Icons.save_alt_outlined),
              title: const Text('另存为...'),
              onTap: () {
                Navigator.pop(modalContext);
                saveAttachment(message);
              },
            )
          );
        }

        options.add(
          ListTile(
            leading: const Icon(Icons.fork_right_outlined),
            title: const Text('从此消息分叉对话'),
            onTap: () {
              Navigator.pop(modalContext);
              forkChatFromMessage(message, allMessages);
            },
          )
        );

        if (isLastUserMessage) {
          options.add(
            ListTile(
              leading: const Icon(Icons.refresh_outlined),
              title: const Text('重新生成回复'),
              onTap: () {
                Navigator.pop(modalContext);
                regenerateResponse(message);
              },
            )
          );
        }

        options.add(
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
            title: Text('删除消息', style: TextStyle(color: Colors.red.shade400)),
            onTap: () async {
              Navigator.pop(modalContext);
              final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('确认删除'),
                      content: const Text('确定删除这条消息吗？'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                            child: const Text('取消')),
                        TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(true),
                            child: Text('删除', style: TextStyle(color: Colors.red.shade700))),
                      ],
                    ),
                  ) ?? false;

              if (confirm) {
                deleteMessagePart(message, part);
              }
            },
          )
        );

        return SafeArea(
          child: Wrap(children: options),
        );
      },
    );
  }

  void showEditMessageDialog(Message message) {
    final chat = ref.read(currentChatProvider(chatId)).value;
    if (chat == null) return;

    final textController = TextEditingController(text: message.rawText);
    final xmlController = TextEditingController();

    if (message.role == MessageRole.model) {
      final bool useSecondaryXml = chat.enableSecondaryXml;
      xmlController.text = useSecondaryXml
          ? (message.secondaryXmlContent ?? '')
          : (message.originalXmlContent ?? '');
    }
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isFullScreen = false;
        TextEditingController? activeController;
        String fullScreenTitle = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (isFullScreen && activeController != null) {
              return Dialog(
                insetPadding: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                child: Scaffold(
                  appBar: AppBar(
                    title: Text(fullScreenTitle),
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: '关闭',
                      onPressed: () => setDialogState(() => isFullScreen = false),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.check),
                        tooltip: '完成',
                        onPressed: () => setDialogState(() => isFullScreen = false),
                      ),
                    ],
                  ),
                  body: TextField(
                    controller: activeController,
                    autofocus: true,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                    ),
                  ),
                ),
              );
            }

            void openFullScreenEditor(TextEditingController controller, String title) {
              setDialogState(() {
                isFullScreen = true;
                activeController = controller;
                fullScreenTitle = title;
              });
            }

            Widget dialogContent;
            if (message.role == MessageRole.model) {
              dialogContent = SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('显示文本:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: textController,
                      autofocus: true,
                      maxLines: 5,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: '用户可见的纯文本内容...',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.all(12),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.fullscreen),
                          tooltip: '全屏编辑',
                          onPressed: () => openFullScreenEditor(textController, '编辑显示文本'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('XML内容:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: xmlController,
                      maxLines: 5,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: '用于逻辑处理的XML标签...',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.all(12),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.fullscreen),
                          tooltip: '全屏编辑',
                          onPressed: () => openFullScreenEditor(xmlController, '编辑XML内容'),
                        ),
                      ),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ],
                ),
              );
            } else {
              dialogContent = TextField(
                controller: textController,
                autofocus: true,
                maxLines: 5,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: '输入修改后的内容...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.fullscreen),
                    tooltip: '全屏编辑',
                    onPressed: () => openFullScreenEditor(textController, '编辑你的消息'),
                  ),
                ),
              );
            }

            return AlertDialog(
              title: Text(message.role == MessageRole.user ? '编辑你的消息' : '编辑模型回复'),
              content: dialogContent,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () async {
                    final notifier = ref.read(chatStateNotifierProvider(chatId).notifier);
                    final newDisplayText = textController.text.trim();
                    final newXmlContent = xmlController.text.trim();

                    if (newDisplayText.isEmpty && message.parts.any((p) => p.type != MessagePartType.text)) {
                    } else if (newDisplayText.isEmpty) {
                      notifier.showTopMessage('消息内容不能为空', backgroundColor: Colors.orange);
                      return;
                    }

                    Message updatedMessage;
                    if (message.role == MessageRole.model) {
                      final bool useSecondaryXml = chat.enableSecondaryXml;
                      updatedMessage = message.copyWith(
                        parts: [MessagePart.text(newDisplayText)],
                        secondaryXmlContent: useSecondaryXml ? newXmlContent : message.secondaryXmlContent,
                        originalXmlContent: !useSecondaryXml ? newXmlContent : message.originalXmlContent,
                      );
                    } else {
                      final newParts = List<MessagePart>.from(message.parts);
                      final textPartIndex = newParts.indexWhere((p) => p.type == MessagePartType.text);
                      if (textPartIndex != -1) {
                        newParts[textPartIndex] = MessagePart.text(newDisplayText);
                      } else {
                        newParts.add(MessagePart.text(newDisplayText));
                      }
                      updatedMessage = message.copyWith(parts: newParts);
                    }
                    
                    Navigator.pop(dialogContext);
                    await notifier.editMessage(updatedMessage.id, updatedMessage: updatedMessage);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> replaceAttachment(Message messageToReplace) async {
    final notifier = ref.read(chatStateNotifierProvider(chatId).notifier);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final file = result.files.single;
        final mimeType = lookupMimeType(file.name) ?? 'application/octet-stream';
        
        MessagePart newPart;
        if (mimeType.startsWith('image/')) {
          newPart = MessagePart.image(
            mimeType: mimeType,
            base64Data: base64Encode(file.bytes!),
            fileName: file.name,
          );
        } else {
          newPart = MessagePart.file(
            mimeType: mimeType,
            base64Data: base64Encode(file.bytes!),
            fileName: file.name,
          );
        }
        
        await notifier.editMessage(messageToReplace.id, newParts: [newPart]);
      }
    } catch (e) {
      debugPrint("Error replacing attachment: $e");
      notifier.showTopMessage('替换附件时出错: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> saveAttachment(Message message) async {
    final notifier = ref.read(chatStateNotifierProvider(chatId).notifier);
    if (message.parts.isEmpty) return;

    final part = message.parts.first;

    if (part.base64Data == null) {
      notifier.showTopMessage('无法保存：文件数据为空', backgroundColor: Colors.red);
      return;
    }

    String fileName;
    if (part.type == MessagePartType.generatedImage) {
      final promptText = part.text ?? 'generated_image';
      final sanitizedPrompt = promptText.replaceAll(RegExp(r'[\s\\/:*?"<>|]+'), '_');
      final snippet = sanitizedPrompt.substring(0, sanitizedPrompt.length > 50 ? 50 : sanitizedPrompt.length);
      fileName = '${snippet}_${DateTime.now().millisecondsSinceEpoch}.png';
    } else if (part.fileName == null) {
      notifier.showTopMessage('无法保存：文件名丢失', backgroundColor: Colors.red);
      return;
    } else {
      fileName = part.fileName!;
    }

    try {
      final bytes = base64Decode(part.base64Data!);
      final String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: '请选择保存位置',
        fileName: fileName,
        bytes: bytes,
      );

      if (savePath != null) {
        notifier.showTopMessage('文件已保存到: $savePath', backgroundColor: Colors.green);
      } else {
        notifier.showTopMessage('已取消保存', backgroundColor: Colors.orange);
      }
    } catch (e) {
      debugPrint("Error saving attachment: $e");
      notifier.showTopMessage('保存文件时出错: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> forkChatFromMessage(Message message, List<Message> allMessages) async {
    // This is now a fire-and-forget call.
    // The notifier is responsible for the entire operation, including updating the active chat state.
    // This decouples the UI logic completely from the business logic.
    debugPrint("[ChatPageLogic] Triggering fork from message ${message.id} in chat $chatId.");
    await ref.read(chatStateNotifierProvider(chatId).notifier).forkChat(message);
    debugPrint("[ChatPageLogic] Fork operation triggered.");
  }

  Future<void> regenerateResponse(Message userMessage) async {
    // No context/ref access after await, so no mounted check needed here.
    await ref.read(chatStateNotifierProvider(chatId).notifier).regenerateResponse(userMessage);
  }

  Future<void> deleteMessagePart(Message message, MessagePart part) async {
    final notifier = ref.read(chatStateNotifierProvider(chatId).notifier);
    // If the message has more than one part, just remove the specific part.
    if (message.parts.length > 1) {
      final newParts = List<MessagePart>.from(message.parts)..remove(part);
      await notifier.editMessage(message.id, newParts: newParts);
    } else {
      // If it's the last part, delete the whole message.
      await notifier.deleteMessage(message.id);
    }
  }

  Future<void> handleForcePush() async {
    if (_isPushing) return;

    _isPushing = true;
    onStateChange();
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('正在上传本地变更...'),
        duration: Duration(seconds: 2),
      ),
    );

    final success = await SyncService.instance.forcePushChanges();

    if (!context.mounted) return;
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(success ? '上传成功' : '上传失败或无需上传'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
    _isPushing = false;
    onStateChange();
  }

  Future<void> pickAndSetCoverImageBase64(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: source);
      if (image == null) return;

      final Uint8List imageBytes = await image.readAsBytes();
      if (!context.mounted) return;
      final String newBase64String = base64Encode(imageBytes);

      final chat = ref.read(currentChatProvider(chatId)).value;
      if (chat != null) {
        final chatToUpdate = chat.copyWith(coverImageBase64: newBase64String);
        await ref.read(chatRepositoryProvider).saveChat(chatToUpdate);
        if (!context.mounted) return;
        ref.read(chatStateNotifierProvider(chatId).notifier).showTopMessage('封面图片已更新', backgroundColor: Colors.green);
      }
    } catch (e) {
      debugPrint("设置封面图片 (Base64) 时出错: $e");
      ref.read(chatStateNotifierProvider(chatId).notifier).showTopMessage('图片处理失败: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> exportImage() async {
    final notifier = ref.read(chatStateNotifierProvider(chatId).notifier);
    final chat = ref.read(currentChatProvider(chatId)).value;
    final String? base64String = chat?.coverImageBase64;

    if (base64String == null || base64String.isEmpty) {
      notifier.showTopMessage('没有可导出的图片', backgroundColor: Colors.orange);
      return;
    }

    try {
      final Uint8List imageBytes = base64Decode(base64String);
      final sanitizedTitle = chat?.title?.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_') ?? 'chat_$chatId';
      final suggestedFileName = 'cover_$sanitizedTitle.jpg';
      
      final String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: '请选择封面保存位置',
        fileName: suggestedFileName,
        bytes: imageBytes,
      );

      if (!context.mounted) return;

      if (savePath != null) {
        notifier.showTopMessage('封面已保存到: $savePath', backgroundColor: Colors.green);
      } else {
        notifier.showTopMessage('已取消保存', backgroundColor: Colors.orange);
      }
    } catch (e) {
      debugPrint("导出封面时出错: $e");
      notifier.showTopMessage('导出封面失败: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> removeCoverImage() async {
    final chatToUpdate = ref.read(currentChatProvider(chatId)).value;
    if (chatToUpdate != null) {
      final updatedChat = chatToUpdate.copyWith(coverImageBase64: null);
      await ref.read(chatRepositoryProvider).saveChat(updatedChat);
      if (!context.mounted) return;
      ref.read(chatStateNotifierProvider(chatId).notifier).showTopMessage('封面图片已移除', backgroundColor: Colors.green);
    }
  }
}