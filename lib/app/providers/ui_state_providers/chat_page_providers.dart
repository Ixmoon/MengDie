import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../../data/sync/sync_service.dart';
import '../../../domain/models/models.dart';
import '../chat_state_providers.dart';
import '../repository_providers.dart';

// 1. Define the State class
@immutable
class ChatPageState {
  final bool isPushing;

  const ChatPageState({
    this.isPushing = false,
  });

  ChatPageState copyWith({
    bool? isPushing,
  }) {
    return ChatPageState(
      isPushing: isPushing ?? this.isPushing,
    );
  }
}

// 2. Create the Notifier
class ChatPageNotifier extends StateNotifier<ChatPageState> {
  final int chatId;
  final Ref _ref;

  ChatPageNotifier(this.chatId, this._ref) : super(const ChatPageState());

  // --- Business Logic Methods ---

  Future<bool> handleForcePush() async {
    if (state.isPushing) return false;
    state = state.copyWith(isPushing: true);
    final success = await SyncService.instance.forcePushChanges();
    state = state.copyWith(isPushing: false);
    return success;
  }

  Future<void> pickAndSetCoverImageBase64(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: source);
      if (image == null) return;

      final Uint8List imageBytes = await image.readAsBytes();
      final String newBase64String = base64Encode(imageBytes);

      final chat = _ref.read(currentChatProvider(chatId)).value;
      if (chat != null) {
        final chatToUpdate = chat.copyWith(coverImageBase64: newBase64String);
        await _ref.read(chatRepositoryProvider).saveChat(chatToUpdate);
        _ref.read(chatStateNotifierProvider(chatId).notifier).showTopMessage('封面图片已更新', backgroundColor: Colors.green);
      }
    } catch (e) {
      debugPrint("设置封面图片 (Base64) 时出错: $e");
      _ref.read(chatStateNotifierProvider(chatId).notifier).showTopMessage('图片处理失败: $e', backgroundColor: Colors.red);
    }
  }

  Future<String?> exportImage() async {
    final chat = _ref.read(currentChatProvider(chatId)).value;
    final String? base64String = chat?.coverImageBase64;

    if (base64String == null || base64String.isEmpty) {
      _ref.read(chatStateNotifierProvider(chatId).notifier).showTopMessage('没有可导出的图片', backgroundColor: Colors.orange);
      return null;
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
      return savePath;
    } catch (e) {
      debugPrint("导出封面时出错: $e");
      _ref.read(chatStateNotifierProvider(chatId).notifier).showTopMessage('导出封面失败: $e', backgroundColor: Colors.red);
      return null;
    }
  }

  Future<void> removeCoverImage() async {
    final chatToUpdate = _ref.read(currentChatProvider(chatId)).value;
    if (chatToUpdate != null) {
      final updatedChat = chatToUpdate.copyWith(coverImageBase64: null);
      await _ref.read(chatRepositoryProvider).saveChat(updatedChat);
      _ref.read(chatStateNotifierProvider(chatId).notifier).showTopMessage('封面图片已移除', backgroundColor: Colors.green);
    }
  }
  
  Future<Message?> addMessageAtEnd(MessageRole role) async {
    final notifier = _ref.read(chatStateNotifierProvider(chatId).notifier);
    final messages = _ref.read(chatMessagesProvider(chatId)).value ?? [];
    final newId = await notifier.insertMessage(messages.length, role);
    if (newId == null) return null;

    // Allow UI to update before fetching the new message
    await Future.delayed(const Duration(milliseconds: 50));

    final updatedMessages = _ref.read(chatMessagesProvider(chatId)).value ?? [];
    final newMessage = updatedMessages.firstWhere((m) => m.id == newId, orElse: () {
      debugPrint("Could not find newly inserted message with id $newId at the end");
      return Message(id: -1, chatId: chatId, role: role, parts: []);
    });

    return newMessage.id > 0 ? newMessage : null;
  }

  // --- Methods to be called from UI callbacks ---
  
  Future<void> regenerateResponse(Message userMessage) async {
    await _ref.read(chatStateNotifierProvider(chatId).notifier).regenerateResponse(userMessage);
  }

  Future<void> forkChatFromMessage(Message message) async {
    await _ref.read(chatStateNotifierProvider(chatId).notifier).duplicateChat(upToMessageId: message.id);
  }

  Future<void> deleteMessagePart(Message message, MessagePart part) async {
    final notifier = _ref.read(chatStateNotifierProvider(chatId).notifier);
    if (message.parts.length > 1) {
      final newParts = List<MessagePart>.from(message.parts)..remove(part);
      await notifier.editMessage(message.id, newParts: newParts);
    } else {
      await notifier.deleteMessage(message.id);
    }
  }

  Future<void> insertMessageAndEdit({required int index, required MessageRole role, required Function(Message) onMessageCreated}) async {
    final notifier = _ref.read(chatStateNotifierProvider(chatId).notifier);
    final newId = await notifier.insertMessage(index, role);
    if (newId == null) return;

    await Future.delayed(const Duration(milliseconds: 50));

    final updatedMessages = _ref.read(chatMessagesProvider(chatId)).value ?? [];
    final newMessage = updatedMessages.firstWhere((m) => m.id == newId, orElse: () {
      return Message(id: -1, chatId: chatId, role: role, parts: []);
    });

    if (newMessage.id > 0) {
      onMessageCreated(newMessage);
    }
  }

  Future<void> replaceAttachment(Message messageToReplace) async {
    final notifier = _ref.read(chatStateNotifierProvider(chatId).notifier);
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

  Future<String?> saveAttachment(Message message, {MessagePart? specificPart}) async {
    final notifier = _ref.read(chatStateNotifierProvider(chatId).notifier);
    
    final attachments = message.parts.where((p) => p.base64Data != null && p.type != MessagePartType.text).toList();

    if (attachments.isEmpty) {
      notifier.showTopMessage('没有可保存的附件', backgroundColor: Colors.orange);
      return null;
    }

    MessagePart partToSave;
    if (specificPart != null) {
      partToSave = specificPart;
    } else if (attachments.length > 1) {
      // This part requires context to show a dialog.
      // For now, we'll just save the first one if not specified.
      // A better implementation would involve the UI asking which one to save.
      partToSave = attachments.first;
       notifier.showTopMessage('消息包含多个附件，已默认保存第一个。', backgroundColor: Colors.blue);
    } else {
      partToSave = attachments.first;
    }

    if (partToSave.base64Data == null) {
      notifier.showTopMessage('无法保存：文件数据为空', backgroundColor: Colors.red);
      return null;
    }

    String fileName;
    if (partToSave.type == MessagePartType.generatedImage) {
      final promptText = partToSave.text ?? 'generated_image';
      final sanitizedPrompt = promptText.replaceAll(RegExp(r'[\s\\/:*?"<>|]+'), '_');
      final snippet = sanitizedPrompt.substring(0, sanitizedPrompt.length > 50 ? 50 : sanitizedPrompt.length);
      fileName = '${snippet}_${DateTime.now().millisecondsSinceEpoch}.png';
    } else if (partToSave.fileName != null) {
      fileName = partToSave.fileName!;
    } else {
      final extension = extensionFromMime(partToSave.mimeType ?? 'application/octet-stream');
      fileName = 'attachment_${DateTime.now().millisecondsSinceEpoch}.$extension';
    }

    try {
      final bytes = base64Decode(partToSave.base64Data!);
      final String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: '请选择保存位置',
        fileName: fileName,
        bytes: bytes,
      );
      return savePath;
    } catch (e) {
      debugPrint("Error saving attachment: $e");
      notifier.showTopMessage('保存文件时出错: $e', backgroundColor: Colors.red);
      return null;
    }
  }
}

// 3. Create the Provider
final chatPageNotifierProvider =
    StateNotifierProvider.autoDispose.family<ChatPageNotifier, ChatPageState, int>((ref, chatId) {
  return ChatPageNotifier(chatId, ref);
});
