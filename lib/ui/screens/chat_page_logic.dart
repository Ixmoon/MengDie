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
import '../../app/tools/xml_processor.dart';
import '../widgets/widget_utils.dart';

class ChatPageLogic {
  final Ref ref;
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

  void handleMessageTap(
    Message message,
    MessagePart part,
    List<Message> allMessages,
  ) {
    if (ref.read(chatStateNotifierProvider(chatId)).isLoading) return;

    final isUser = message.role == MessageRole.user;
    final messageIndex = allMessages.indexWhere((m) => m.id == message.id);
    final isLastUserMessage =
        isUser &&
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
            leading: Icon(
              isTextOnly ? Icons.edit_outlined : Icons.upload_file_outlined,
            ),
            title: Text(isTextOnly ? '编辑消息' : '重新上传'),
            onTap: () {
              Navigator.pop(modalContext);
              if (isTextOnly) {
                showEditMessageDialog(message);
              } else {
                replaceAttachment(message, part);
              }
            },
          ),
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
            ),
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
          ),
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
            ),
          );
        }

        options.addAll(_buildInsertMessageOptions(modalContext, messageIndex));

        options.add(
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
            title: Text('删除消息', style: TextStyle(color: Colors.red.shade400)),
            onTap: () async {
              Navigator.pop(modalContext);
              final confirm =
                  await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('确认删除'),
                      content: const Text('确定删除这条消息吗？'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: Text(
                            '删除',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ) ??
                  false;

              if (confirm) {
                deleteMessagePart(message, part);
              }
            },
          ),
        );

        return SafeArea(child: Wrap(children: options));
      },
    );
  }

  void showEditMessageDialog(Message message) {
    final chat = ref.read(currentChatProvider(chatId)).value;
    if (chat == null) return;

    final textController = TextEditingController(text: message.rawText);
    final originalXmlController =
        TextEditingController(text: message.originalXmlContent ?? '');
    final secondaryXmlController =
        TextEditingController(text: message.secondaryXmlContent ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        final isModelMessage = message.role == MessageRole.model;

        final dialogContent = SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: textController,
                autofocus: true,
                maxLines: 5,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: '用户可见内容',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(12),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.fullscreen),
                    tooltip: '全屏编辑',
                    onPressed: () async {
                      final newText = await showFullScreenTextEditor(
                        context,
                        initialText: textController.text,
                        title: '编辑消息内容',
                        initialLanguage: 'markdown',
                        chatId: chatId,
                      );
                      if (newText != null) {
                        textController.text = newText;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '原生XML:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: originalXmlController,
                maxLines: 5,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: '用于逻辑处理的XML标签...',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(12),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.fullscreen),
                    tooltip: '全屏编辑',
                    onPressed: () async {
                      final newText = await showFullScreenTextEditor(
                        context,
                        initialText: originalXmlController.text,
                        title: '编辑原生XML内容',
                        initialLanguage: 'xml',
                        chatId: chatId,
                      );
                      if (newText != null) {
                        originalXmlController.text = newText;
                      }
                    },
                  ),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              if (isModelMessage) ...[
                const SizedBox(height: 16),
                const Text(
                  '再生XML:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: secondaryXmlController,
                  maxLines: 5,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: '由AI生成的额外XML内容...',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(12),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.fullscreen),
                      tooltip: '全屏编辑',
                      onPressed: () async {
                        final newText = await showFullScreenTextEditor(
                          context,
                          initialText: secondaryXmlController.text,
                          title: '编辑再生XML内容',
                          initialLanguage: 'xml',
                          chatId: chatId,
                        );
                        if (newText != null) {
                          secondaryXmlController.text = newText;
                        }
                      },
                    ),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ]
            ],
          ),
        );

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
                final notifier = ref.read(
                  chatStateNotifierProvider(chatId).notifier,
                );
                final newModelsTextFromInput = textController.text;
                final newOriginalXml = originalXmlController.text;
                final newSecondaryXml = secondaryXmlController.text;

                if (newModelsTextFromInput.trim().isEmpty &&
                    !message.parts.any((p) => p.type != MessagePartType.text)) {
                  notifier.showTopMessage(
                    '消息内容不能为空',
                    backgroundColor: Colors.orange,
                  );
                  return;
                }

                final newParts = List<MessagePart>.from(
                  message.parts.where((p) => p.type != MessagePartType.text),
                );
                newParts.add(MessagePart.text(newModelsTextFromInput));

                final finalOriginalXml =
                    newOriginalXml.isNotEmpty ? newOriginalXml : null;
                final finalSecondaryXml =
                    newSecondaryXml.isNotEmpty ? newSecondaryXml : null;

                Message updatedMessage = message.copyWith(
                  parts: newParts,
                  originalXmlContent: finalOriginalXml,
                  clearOriginalXml: finalOriginalXml == null,
                  secondaryXmlContent:
                      isModelMessage ? finalSecondaryXml : message.secondaryXmlContent,
                  clearSecondaryXml:
                      isModelMessage ? (finalSecondaryXml == null) : false,
                );

                Navigator.pop(dialogContext);
                await notifier.editMessage(
                  updatedMessage.id,
                  updatedMessage: updatedMessage,
                );
              },
              child: const Text('保存'),
            ),
            TextButton(
              onPressed: () async {
                final notifier = ref.read(
                  chatStateNotifierProvider(chatId).notifier,
                );
                final newModelsTextFromInput = textController.text;
                final newOriginalXml = originalXmlController.text;
                final newSecondaryXml = secondaryXmlController.text;

                if (newModelsTextFromInput.trim().isEmpty &&
                    !message.parts.any((p) => p.type != MessagePartType.text)) {
                  notifier.showTopMessage(
                    '消息内容不能为空',
                    backgroundColor: Colors.orange,
                  );
                  return;
                }

                final processResult = XmlProcessor.processPostStream(
                  newModelsTextFromInput,
                  chat.xmlRules,
                );
                final finalCleanModelsText = processResult.modelsText;
                final newlyExtractedXml = processResult.extractedXml;

                final List<String> originalXmlParts = [];
                if (newOriginalXml.isNotEmpty) {
                  originalXmlParts.add(newOriginalXml);
                }
                if (newlyExtractedXml != null && newlyExtractedXml.isNotEmpty) {
                  originalXmlParts.add(newlyExtractedXml);
                }
                final finalOriginalXml = originalXmlParts.isEmpty
                    ? null
                    : originalXmlParts.join('\n');
                
                final finalSecondaryXml =
                    newSecondaryXml.isNotEmpty ? newSecondaryXml : null;

                final newParts = List<MessagePart>.from(
                  message.parts.where((p) => p.type != MessagePartType.text),
                );
                newParts.add(MessagePart.text(finalCleanModelsText));

                Message updatedMessage = message.copyWith(
                  parts: newParts,
                  originalXmlContent: finalOriginalXml,
                  clearOriginalXml: finalOriginalXml == null,
                  secondaryXmlContent:
                      isModelMessage ? finalSecondaryXml : message.secondaryXmlContent,
                  clearSecondaryXml:
                      isModelMessage ? (finalSecondaryXml == null) : false,
                );

                Navigator.pop(dialogContext);
                await notifier.editMessage(
                  updatedMessage.id,
                  updatedMessage: updatedMessage,
                );
              },
              child: const Text('保存并应用'),
            ),
          ],
        );
      },
    );
  }

  Future<void> replaceAttachment(
    Message messageToReplace,
    MessagePart partToReplace,
  ) async {
    final notifier = ref.read(chatStateNotifierProvider(chatId).notifier);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final file = result.files.single;
        final mimeType =
            lookupMimeType(file.name) ?? 'application/octet-stream';

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

        final newParts = messageToReplace.parts.map((p) {
          // Using reference equality, assuming the tapped part is passed correctly.
          return p == partToReplace ? newPart : p;
        }).toList();

        await notifier.editMessage(messageToReplace.id, newParts: newParts);
      }
    } catch (e) {
      notifier.showTopMessage('替换附件时出错: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> saveAttachment(Message message) async {
    final notifier = ref.read(chatStateNotifierProvider(chatId).notifier);

    final attachments = message.parts
        .where((p) => p.base64Data != null && p.type != MessagePartType.text)
        .toList();

    if (attachments.isEmpty) {
      notifier.showTopMessage('没有可保存的附件', backgroundColor: Colors.orange);
      return;
    }

    MessagePart partToSave;
    if (attachments.length > 1) {
      final MessagePart? selectedPart = await showDialog<MessagePart>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('选择要保存的附件'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: attachments.length,
              itemBuilder: (context, index) {
                final part = attachments[index];
                return ListTile(
                  title: Text(part.fileName ?? '未命名文件 ${index + 1}'),
                  subtitle: Text(part.mimeType ?? '未知类型'),
                  onTap: () => Navigator.of(dialogContext).pop(part),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      );
      if (selectedPart == null) {
        notifier.showTopMessage('已取消保存', backgroundColor: Colors.orange);
        return;
      }
      partToSave = selectedPart;
    } else {
      partToSave = attachments.first;
    }

    if (partToSave.base64Data == null) {
      notifier.showTopMessage('无法保存：文件数据为空', backgroundColor: Colors.red);
      return;
    }

    String fileName;
    if (partToSave.type == MessagePartType.generatedImage) {
      final promptText = partToSave.text ?? 'generated_image';
      final sanitizedPrompt = promptText.replaceAll(
        RegExp(r'[\s\\/:*?"<>|]+'),
        '_',
      );
      final snippet = sanitizedPrompt.substring(
        0,
        sanitizedPrompt.length > 50 ? 50 : sanitizedPrompt.length,
      );
      fileName = '${snippet}_${DateTime.now().millisecondsSinceEpoch}.png';
    } else if (partToSave.fileName != null) {
      fileName = partToSave.fileName!;
    } else {
      final extension = extensionFromMime(
        partToSave.mimeType ?? 'application/octet-stream',
      );
      fileName =
          'attachment_${DateTime.now().millisecondsSinceEpoch}.$extension';
    }

    try {
      final bytes = base64Decode(partToSave.base64Data!);
      final String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: '请选择保存位置',
        fileName: fileName,
        bytes: bytes,
      );

      if (savePath != null) {
        notifier.showTopMessage(
          '文件已保存到: $savePath',
          backgroundColor: Colors.green,
        );
      } else {
        notifier.showTopMessage('已取消保存', backgroundColor: Colors.orange);
      }
    } catch (e) {
      notifier.showTopMessage('保存文件时出错: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> forkChatFromMessage(
    Message message,
    List<Message> allMessages,
  ) async {
    // This is now a fire-and-forget call.
    // The notifier is responsible for the entire operation, including updating the active chat state.
    // This decouples the UI logic completely from the business logic.
    await ref
        .read(chatStateNotifierProvider(chatId).notifier)
        .duplicateChat(upToMessageId: message.id);
  }

  Future<void> regenerateResponse(Message userMessage) async {
    // No context/ref access after await, so no mounted check needed here.
    await ref
        .read(chatStateNotifierProvider(chatId).notifier)
        .regenerateResponse(userMessage);
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
        ref
            .read(chatStateNotifierProvider(chatId).notifier)
            .showTopMessage('封面图片已更新', backgroundColor: Colors.green);
      }
    } catch (e) {
      ref
          .read(chatStateNotifierProvider(chatId).notifier)
          .showTopMessage('图片处理失败: $e', backgroundColor: Colors.red);
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
      final sanitizedTitle =
          chat?.title?.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_') ??
          'chat_$chatId';
      final suggestedFileName = 'cover_$sanitizedTitle.jpg';

      final String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: '请选择封面保存位置',
        fileName: suggestedFileName,
        bytes: imageBytes,
      );

      if (!context.mounted) return;

      if (savePath != null) {
        notifier.showTopMessage(
          '封面已保存到: $savePath',
          backgroundColor: Colors.green,
        );
      } else {
        notifier.showTopMessage('已取消保存', backgroundColor: Colors.orange);
      }
    } catch (e) {
      notifier.showTopMessage('导出封面失败: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> removeCoverImage() async {
    final chatToUpdate = ref.read(currentChatProvider(chatId)).value;
    if (chatToUpdate != null) {
      final updatedChat = chatToUpdate.copyWith(coverImageBase64: null);
      await ref.read(chatRepositoryProvider).saveChat(updatedChat);
      if (!context.mounted) return;
      ref
          .read(chatStateNotifierProvider(chatId).notifier)
          .showTopMessage('封面图片已移除', backgroundColor: Colors.green);
    }
  }

  List<Widget> _buildInsertMessageOptions(
    BuildContext modalContext,
    int messageIndex,
  ) {
    final notifier = ref.read(chatStateNotifierProvider(chatId).notifier);

    Future<void> insertAndEdit(int index, MessageRole role) async {
      // Close the bottom sheet first.
      Navigator.pop(modalContext);

      final newId = await notifier.insertMessage(index, role);
      if (newId == null || !context.mounted) return;

      // A short delay to allow the UI to update with the new message bubble.
      await Future.delayed(const Duration(milliseconds: 100));

      // Find the newly created message from the updated list.
      final messages = ref.read(chatMessagesProvider(chatId)).value ?? [];
      final newMessage = messages.firstWhere(
        (m) => m.id == newId,
        orElse: () {
          // Return a dummy message with a non-positive ID to indicate "not found".
          return Message(
            id: -1,
            chatId: chatId,
            role: MessageRole.user,
            parts: [],
          );
        },
      );

      if (newMessage.id > 0) {
        showEditMessageDialog(newMessage);
      }
    }

    return [
      const Divider(),
      ListTile(
        leading: const Icon(Icons.vertical_align_top_outlined),
        title: const Text('在此之前插入用户消息'),
        onTap: () => insertAndEdit(messageIndex, MessageRole.user),
      ),
      ListTile(
        leading: const Icon(Icons.vertical_align_top_outlined),
        title: const Text('在此之前插入模型消息'),
        onTap: () => insertAndEdit(messageIndex, MessageRole.model),
      ),
      ListTile(
        leading: const Icon(Icons.vertical_align_bottom_outlined),
        title: const Text('在此之后插入用户消息'),
        onTap: () => insertAndEdit(messageIndex + 1, MessageRole.user),
      ),
      ListTile(
        leading: const Icon(Icons.vertical_align_bottom_outlined),
        title: const Text('在此之后插入模型消息'),
        onTap: () => insertAndEdit(messageIndex + 1, MessageRole.model),
      ),
    ];
  }

  Future<void> addMessageAtEnd(MessageRole role) async {
    final notifier = ref.read(chatStateNotifierProvider(chatId).notifier);
    final messages = ref.read(chatMessagesProvider(chatId)).value ?? [];
    final newId = await notifier.insertMessage(messages.length, role);
    if (newId == null || !context.mounted) return;

    await Future.delayed(const Duration(milliseconds: 100));

    final updatedMessages = ref.read(chatMessagesProvider(chatId)).value ?? [];
    final newMessage = updatedMessages.firstWhere(
      (m) => m.id == newId,
      orElse: () {
        return Message(id: -1, chatId: chatId, role: role, parts: []);
      },
    );

    if (newMessage.id > 0) {
      showEditMessageDialog(newMessage);
    }
  }
}
