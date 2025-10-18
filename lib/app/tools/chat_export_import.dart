import 'dart:convert'; // 用于 JSON 编码/解码
import 'dart:io'; // 用于文件操作
import 'dart:convert'; // 用于 JSON 编码/解码
import 'dart:io'; // 用于文件操作
import 'dart:typed_data'; // For Uint8List
import 'package:archive/archive_io.dart'; // For ZIP encoding
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:permission_handler/permission_handler.dart'; // 请求权限
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img; // 使用 'img' 前缀避免冲突
import 'package:file_picker/file_picker.dart'; // 选择文件

import '../../ui/router.dart';
// 导入模型、DTO 和仓库
import '../../domain/enums.dart';
import '../../domain/models/models.dart';
import '../providers/repository_providers.dart';
import '../repositories/chat_repository.dart';
import '../repositories/message_repository.dart';
import '../services/prompt_service.dart';

// --- Service Provider ---
final chatExportImportServiceProvider = Provider<ChatExportImportService>((
  ref,
) {
  // 依赖 ChatRepository 和 MessageRepository
  final chatRepo = ref.watch(chatRepositoryProvider);
  final messageRepo = ref.watch(messageRepositoryProvider);
  return ChatExportImportService(ref, chatRepo, messageRepo);
});

// --- Chat Export/Import Service Implementation ---
class ChatExportImportService {
  final Ref _ref;
  final ChatRepository _chatRepository;
  final MessageRepository _messageRepository;
  // --- 新版 PNG 格式常量 ---
  static const String _pngCharaKeyword = 'chara';
  static const String _pngV3Keyword = 'ccv3';

  ChatExportImportService(
    this._ref,
    this._chatRepository,
    this._messageRepository,
  );

  String _formatJsonToMarkdown(String input) {
    try {
      // 尝试解码，如果成功，说明是有效的JSON
      final decoded = jsonDecode(input);
      // 使用缩进格式化为字符串
      const encoder = JsonEncoder.withIndent('    ');
      final formattedJson = encoder.convert(decoded);
      return formattedJson;
    } catch (e) {
      // 如果解码失败，说明不是JSON，返回原字符串
      return input;
    }
  }
  // --- 新增：处理占位符 ---
  Future<String?> _handlePlaceholders(
      String jsonString, String charName) async {
    String processedJson = jsonString
        .replaceAll('{{char}}', charName)
        .replaceAll('<char>', charName);

    if (processedJson.contains('{{user}}') ||
        processedJson.contains('<user>')) {
      final context = rootNavigatorKey.currentContext;
      if (context == null) {
        // 无法显示对话框，按原样继续
        return processedJson;
      }

      final userName = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('输入您的名字'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: '您的名字'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('确认'),
              ),
            ],
          );
        },
      );

      if (userName == null || userName.isEmpty) {
        // 用户取消或未输入
        return null;
      }

      processedJson = processedJson
          .replaceAll('{{user}}', userName)
          .replaceAll('<user>', userName);
    }

    return processedJson;
  }

  Future<void> _ensurePermissions() async {
    if (kIsWeb) return; // Web 不需要这些权限

    PermissionStatus status;

    if (Platform.isAndroid) {
      // 对于 Android 13 (API 33) 及以上版本，优先请求照片权限
      // Permission.photos 涵盖了读取媒体图片。对于写入，也与此相关。
      status = await Permission.photos.status;
      if (!status.isGranted) {
        status = await Permission.photos.request();
      }

      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          await openAppSettings(); // 引导用户到应用设置
          throw Exception("照片权限已被永久拒绝，请在系统设置中开启。");
        } else {
          throw Exception("需要照片权限才能继续操作。");
        }
      }
    } else if (Platform.isIOS) {
      // iOS 照片库权限
      status = await Permission.photos.status; // 用于读取和写入（如果应用创建）
      if (!status.isGranted) {
        status = await Permission.photos.request();
      }

      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          await openAppSettings();
          throw Exception("照片权限已被永久拒绝，请在系统设置中开启。");
        } else {
          throw Exception("需要照片权限才能继续操作。");
        }
      }
    }
    // 其他平台不在此处处理权限
  }

  // --- 导出聊天 ---
  Future<String?> exportChat(
    int chatId, {
    bool skipPermissionCheck = false,
  }) async {
    if (!skipPermissionCheck) {
      await _ensurePermissions();
    }

    try {
      // --- 更新：生成新的 PNG 格式 ---
      final imageBytesWithPngData = await _generateExportData(chatId);
      if (imageBytesWithPngData == null) {
        throw Exception("未能生成导出数据。");
      }

      final chat = await _chatRepository.getChat(chatId);
      final sanitizedTitle =
          chat?.title?.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_') ??
          'chat_$chatId';
      // 文件扩展名改为 .png
      final suggestedFileName = '$sanitizedTitle.png';

      if (kIsWeb) {
        await FilePicker.platform.saveFile(
          dialogTitle: '请选择保存位置 (Web)',
          fileName: suggestedFileName,
          bytes: Uint8List.fromList(imageBytesWithPngData),
        );
        return null;
      } else {
        String? finalSavePath = await FilePicker.platform.saveFile(
          dialogTitle: '请选择保存位置',
          fileName: suggestedFileName,
          bytes: Uint8List.fromList(imageBytesWithPngData),
        );
        if (finalSavePath != null) {
          return finalSavePath;
        } else {
          return null;
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception("导出聊天时发生未知错误: $e");
    }
  }

  // --- 更新：批量导出到 ZIP（支持文件夹结构）---
  Future<String?> exportChatsToZip(List<int> chatIds) async {
    await _ensurePermissions();

    final archive = Archive();
    // Start the recursive process from the root of the archive
    await _addItemsToArchive(archive, chatIds, '');

    if (archive.isEmpty) {
      throw Exception("未能导出任何项目。");
    }

    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    // zipBytes is non-nullable, so no need to check for null

    final String suggestedFileName =
        'mengdie_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.zip';

    if (kIsWeb) {
      await FilePicker.platform.saveFile(
        dialogTitle: '保存 ZIP 文件',
        fileName: suggestedFileName,
        bytes: Uint8List.fromList(zipBytes),
      );
      return null;
    } else {
      String? finalSavePath = await FilePicker.platform.saveFile(
        dialogTitle: '保存 ZIP 文件',
        fileName: suggestedFileName,
        bytes: Uint8List.fromList(zipBytes),
      );
      if (finalSavePath != null) {
        return finalSavePath;
      } else {
        return null;
      }
    }
  }

  // --- 新增：递归地将项目（聊天和文件夹）添加到压缩包 ---
  Future<void> _addItemsToArchive(
    Archive archive,
    List<int> itemIds,
    String currentPath,
  ) async {
    for (final itemId in itemIds) {
      try {
        final item = await _chatRepository.getChat(itemId);
        if (item == null) continue;

        final sanitizedTitle =
            item.title?.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_') ??
            'item_$itemId';

        if (item.isFolder) {
          // It's a folder, create a directory and recurse
          final newPath = '$currentPath$sanitizedTitle/';
          // Note: The archive library doesn't have an explicit "add directory" concept.
          // Directories are implicitly created by the paths of the files.
          // We can add an empty file to ensure the directory exists if it's empty, but it's often not necessary.

          final children = await _chatRepository.getChatsInFolder(item.id);
          final childIds = children.map((c) => c.id).toList();
          if (childIds.isNotEmpty) {
            await _addItemsToArchive(archive, childIds, newPath);
          }
        } else {
          // It's a chat, generate and add the file
          // 文件扩展名改为 .png
          final fileName = '$sanitizedTitle.png';
          final filePath = '$currentPath$fileName';

          final exportData = await _generateExportData(itemId);
          if (exportData != null) {
            archive.addFile(
              ArchiveFile(filePath, exportData.length, exportData),
            );
          }
        }
      } catch (_) {
        // Continue with the next item
      }
    }
  }

  // --- 新增：内部生成导出数据的方法 ---
  Future<List<int>?> _generateExportData(int chatId) async {
    final chat = await _chatRepository.getChat(chatId);
    if (chat == null) {
      return null;
    }
    final messages = await _messageRepository.getMessagesForChat(chatId);

    // Create a new Chat instance that includes the messages for serialization.
    final chatWithMessages = chat.copyWith(messages: messages);

    // Now, the domain model itself can be converted to JSON.
    final jsonString = jsonEncode(chatWithMessages.toJson());
    // --- 更新：使用 Base64 编码以兼容“酒馆”格式 ---
    final base64String = base64Encode(utf8.encode(jsonString));

    img.Image? image;
    if (chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty) {
      try {
        final coverBytes = base64Decode(chat.coverImageBase64!);
        // 尝试解码为 PNG 或 JPG
        image = img.decodeImage(coverBytes);
      } catch (_) {}
    }

    // 如果没有有效封面，创建一个默认图片
    if (image == null) {
      image = img.Image(width: 200, height: 200);
      img.fill(image, color: img.ColorRgb8(240, 240, 240));
    }

    // --- 更新：将数据写入 PNG 的 tEXt 块 ---
    // 使用 image 库的 addTextData 方法（如果可用）或手动构建
    // 注意：image 库本身可能没有直接添加任意 tEXt 块的简单方法。
    // 我们将 Base64 字符串添加到 image 对象的 textData map 中。
    // encodePng 会处理这个 map 并创建 tEXt 数据块。
    image.textData = {_pngCharaKeyword: base64String};

    // 返回 PNG 编码的字节
    return img.encodePng(image);
  }

  // --- 更新：导入聊天（支持批量图片和 ZIP 压缩包），可指定父文件夹 ---
  Future<int> importChats({int? parentFolderId}) async {
    await _ensurePermissions();

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'zip'],
        withData: true, // Always get bytes for both web and native
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        return 0;
      }

      int successCount = 0;
      final bool isBatchImport =
          result.files.length > 1 ||
          (result.files.length == 1 &&
              result.files.first.name.toLowerCase().endsWith('.zip'));

      for (final file in result.files) {
        if (file.bytes == null) {
          continue;
        }

        final fileName = file.name.toLowerCase();
        try {
          if (fileName.endsWith('.zip')) {
            // ZIP 文件总是被视为批量导入
            final count = await _importFromZip(file.bytes!, parentFolderId);
            successCount += count;
          } else if (fileName.endsWith('.jpg') ||
              fileName.endsWith('.jpeg') ||
              fileName.endsWith('.png')) {
            // 根据 isBatchImport 标志决定如何导入图片
            await _importFromImageBytes(
              file.bytes!,
              parentFolderId,
              isBatch: isBatchImport,
              fileName: file.name,
            );
            successCount++;
          }
        } catch (_) {
          // Log and continue with the next file.
        }
      }
      return successCount;
    } catch (e) {
      rethrow; // Rethrow to be caught by the UI
    }
  }

  // ZIP 导入逻辑现在接收一个基础的 parentFolderId
  Future<int> _importFromZip(
    Uint8List zipBytes,
    int? baseParentFolderId,
  ) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    int successCount = 0;

    // Map to keep track of created folder IDs: 'path/in/zip' -> db_id
    // 根路径现在映射到基础父文件夹 ID
    final Map<String, int?> createdFolderIds = {'': baseParentFolderId};

    // Create a mutable copy of the files list and sort it to process directories first
    final sortedFiles = List.of(archive.files);
    sortedFiles.sort((a, b) => a.name.compareTo(b.name));

    for (final file in sortedFiles) {
      if (file.isFile) {
        try {
          // Determine parent folder path from the file's full path
          final pathParts = file.name.split('/');
          final parentPath = pathParts.length > 1
              ? pathParts.sublist(0, pathParts.length - 1).join('/')
              : '';

          // Get or create the folder ID for the parent path, relative to the baseParentFolderId
          final parentFolderId = await _getOrCreateFolderIdByPath(
            parentPath,
            createdFolderIds,
            baseParentFolderId,
          );

          // ZIP 包内的文件总是作为批量导入的一部分，保留其排序信息
          await _importFromImageBytes(
            file.content,
            parentFolderId,
            isBatch: true,
            fileName: file.name,
          );
          successCount++;
        } catch (_) {}
      }
    }
    return successCount;
  }

  // _getOrCreateFolderIdByPath 现在也接收基础父文件夹 ID
  Future<int?> _getOrCreateFolderIdByPath(
    String path,
    Map<String, int?> createdFolderIds,
    int? baseParentFolderId,
  ) async {
    if (path.isEmpty) return baseParentFolderId; // 如果路径为空，返回基础父ID
    if (createdFolderIds.containsKey(path)) {
      return createdFolderIds[path];
    }

    // Path doesn't exist, we need to create it, and possibly its parents first
    final pathParts = path.split('/');
    // 起始的父ID是基础父ID
    int? currentParentId = baseParentFolderId;
    String currentPath = '';

    for (int i = 0; i < pathParts.length; i++) {
      final part = pathParts[i];
      currentPath = (i == 0) ? part : '$currentPath/$part';

      if (!createdFolderIds.containsKey(currentPath)) {
        // This folder part doesn't exist, create it under the current parent
        final now = DateTime.now();
        final folderToCreate = Chat(
          title: part,
          isFolder: true,
          createdAt: now,
          updatedAt: now,
        );
        // importChat now handles the domain model directly.
        final newFolderId = await _chatRepository.importChat(
          folderToCreate,
          parentFolderId: currentParentId,
        );
        createdFolderIds[currentPath] = newFolderId;
        currentParentId = newFolderId;
      } else {
        // The folder already exists in our map, just update the current parent ID
        currentParentId = createdFolderIds[currentPath];
      }
    }
    return currentParentId;
  }

  // --- 分发器，根据文件类型决定使用哪个导入方法 ---
  Future<void> _importFromImageBytes(
    Uint8List imageBytes,
    int? parentFolderId, {
    bool isBatch = false,
    required String fileName,
  }) async {
    final lowerCaseFileName = fileName.toLowerCase();

    // 优先尝试基于文件扩展名的解析
    if (lowerCaseFileName.endsWith('.png')) {
      try {
        // 首先，尝试作为我们的原生格式导入。
        await _importFromPngNative(imageBytes, parentFolderId, isBatch: isBatch);
        return;
      } catch (_) {
        // 如果失败，尝试作为酒馆角色卡导入。
        try {
          await _importFromTavernCard(imageBytes, parentFolderId,
              isBatch: isBatch);
          return;
        } catch (tavernError) {
          throw Exception("无法将 '$fileName' 作为梦蝶或酒馆角色卡导入。");
        }
      }
    }

    // 对于 .jpg, .jpeg, 或 .png 解析失败的情况，尝试 EXIF
    if (lowerCaseFileName.endsWith('.jpg') ||
        lowerCaseFileName.endsWith('.jpeg')) {
      throw Exception(
        "导入失败：JPG EXIF 导入已被弃用。请使用 PNG 格式的角色卡进行导入。",
      );
    }
  }

  // --- 新增：从 PNG tEXt 数据块导入 ---
  Future<void> _importFromPngNative(
    Uint8List imageBytes,
    int? parentFolderId, {
    bool isBatch = false,
  }) async {
    final image = img.decodePng(imageBytes);
    if (image == null) {
      throw Exception("无法解码 PNG 图片。");
    }

    if (image.textData == null ||
        !image.textData!.containsKey(_pngCharaKeyword)) {
      throw Exception("PNG 文件中未找到 '$_pngCharaKeyword' 数据块。");
    }

    final base64String = image.textData![_pngCharaKeyword]!;
    if (base64String.isEmpty) {
      throw Exception("PNG '$_pngCharaKeyword' 数据块为空。");
    }

    String? jsonString;
    try {
      final decodedBytes = base64Decode(base64String);
      jsonString = utf8.decode(decodedBytes);
    } catch (e) {
      throw Exception("无法解码存储在 PNG 中的聊天数据 (Base64/UTF8 解码失败)。");
    }

    if (jsonString.isEmpty) {
      throw Exception("未能从 PNG 中恢复有效的聊天数据。");
    }

    await _processImportedJson(
      jsonString,
      imageBytes,
      parentFolderId,
      isBatch: isBatch,
    );
  }

  // --- 新增：从酒馆角色卡导入 ---
  Future<void> _importFromTavernCard(
    Uint8List imageBytes,
    int? parentFolderId, {
    bool isBatch = false,
  }) async {
    final image = img.decodeImage(imageBytes); // 使用 decodeImage 兼容 jpg/png
    if (image == null) {
      throw Exception("无法解码图片。");
    }

    // 酒馆卡片使用 'chara' (v2) 或 'ccv3' (v3)
    final String? base64String =
        image.textData?[_pngV3Keyword] ?? image.textData?[_pngCharaKeyword];

    if (base64String == null || base64String.isEmpty) {
      throw Exception("PNG 文件中未找到酒馆角色数据。");
    }

    String jsonString;
    try {
      final decodedBytes = base64Decode(base64String);
      jsonString = utf8.decode(decodedBytes);
    } catch (e) {
      throw Exception("无法解码存储在 PNG 中的酒馆数据 (Base64/UTF8 解码失败)。");
    }

    Map<String, dynamic> cardData;
    try {
      cardData = jsonDecode(jsonString);
    } on FormatException {
      throw Exception("导入失败：酒馆卡数据格式无效或已损坏。");
    }

    // 处理 V2 vs V3 规范数据结构
    final data = cardData.containsKey('data') && cardData['data'] is Map
        ? cardData['data'] as Map<String, dynamic>
        : cardData;

    final String name = data['name'] as String? ?? '导入的角色';

    // --- 新增：处理占位符 ---
    final processedJsonString = await _handlePlaceholders(jsonString, name);
    if (processedJsonString == null) {
      return; // 用户取消，中止导入
    }
    
    // 从处理过的 JSON 重新解码数据
    final processedCardData = jsonDecode(processedJsonString);
    final processedData = processedCardData.containsKey('data') && processedCardData['data'] is Map
        ? processedCardData['data'] as Map<String, dynamic>
        : processedCardData;

    final String description = _formatJsonToMarkdown(processedData['description'] as String? ?? '');
    final String personality = _formatJsonToMarkdown(processedData['personality'] as String? ?? '');
    final String scenario = _formatJsonToMarkdown(processedData['scenario'] as String? ?? '');
    final String systemPrompt = _formatJsonToMarkdown(processedData['system_prompt'] as String? ?? '');

    final combinedSystemPrompt = [
      description,
      personality,
      scenario,
      systemPrompt,
    ].where((s) => s.isNotEmpty).join('\n\n');

    final String coverImageBase64 = base64Encode(imageBytes);

    List<String> greetings =
        (processedData['alternate_greetings'] as List<dynamic>?)
                ?.map((g) => g.toString())
                .where((g) => g.isNotEmpty)
                .toList() ??
            [];

    // 1. 当alternate_greetings不存在时才需要回退使用first_mes
    if (greetings.isEmpty) {
      final firstMes = processedData['first_mes'] as String?;
      if (firstMes != null && firstMes.isNotEmpty) {
        greetings.add(firstMes);
      }
    }

    // 如果两种问候语都没有，我们仍然需要创建一个聊天，但不带初始消息。
    // 为此，我们向列表中添加一个空字符串，以确保循环至少执行一次。
    if (greetings.isEmpty) {
      greetings.add('');
    }

    int chatCount = 0;
    for (final greeting in greetings) {
      final now = DateTime.now();
      final chatToCreate = Chat(
        title: greetings.length > 1 ? '$name ${++chatCount}' : name,
        systemPrompt: combinedSystemPrompt,
        coverImageBase64: coverImageBase64,
        createdAt: now,
        updatedAt: now,
        orderIndex: isBatch ? 999999 : null,
      );

      final newChatId = await _chatRepository.importChat(
        chatToCreate,
        parentFolderId: parentFolderId,
      );

      if (greeting.isNotEmpty) {
        final firstMessage = Message(
          chatId: newChatId,
          role: MessageRole.model,
          parts: [MessagePart.text(greeting)],
          timestamp: DateTime.now(),
        );
        await _messageRepository.saveMessage(firstMessage);
      }

      // 导入角色设定集
      // 检查原始卡片数据中是否存在有效的 character_book
      final characterBook = processedData['character_book'];
      if (characterBook is Map &&
          characterBook.containsKey('entries') &&
          characterBook['entries'] is List) {
        try {
          final promptService = _ref.read(promptServiceProvider.notifier);
          // 直接将从卡片中解析出的完整、原始的 jsonString 传递给 prompt service
          // 这模拟了从文件导入时的行为，确保解析逻辑一致
          await promptService.importCompatiblePrompts(
            processedJsonString, // 使用处理占位符后的 JSON 字符串
            isGlobal: false,
            chatId: newChatId,
          );
        } catch (e) {
          debugPrint('为聊天 $newChatId 导入 character_book 失败: $e');
        }
      }
    }
  }

  // --- 新增：处理已解析 JSON 的共享逻辑 ---
  Future<void> _processImportedJson(
    String jsonString,
    Uint8List imageBytes,
    int? parentFolderId, {
    bool isBatch = false,
  }) async {
    Chat chatFromJson;
    try {
      // Directly deserialize into the domain model.
      chatFromJson = Chat.fromJson(jsonDecode(jsonString));
    } on FormatException {
      throw Exception("导入失败：文件中的数据格式无效或已损坏。");
    }

    // The logic to decide whether to use the imported image as a cover
    // is now handled by checking the `coverImageBase64` field in the JSON itself.
    // If it's null or empty, it means the original chat didn't have a "real" cover.
    // We only override with the container image if the original had a real cover.
    bool hasRealCoverInJson =
        chatFromJson.coverImageBase64 != null &&
        chatFromJson.coverImageBase64!.isNotEmpty;
    String? finalCoverImageBase64 = hasRealCoverInJson
        ? base64Encode(imageBytes)
        : chatFromJson.coverImageBase64;

    // If it's a single file import, force orderIndex to null to place it at the top.
    // Otherwise, respect the orderIndex from the file.
    final finalChat = chatFromJson.copyWith(
      coverImageBase64: finalCoverImageBase64,
      orderIndex: isBatch ? chatFromJson.orderIndex : null,
    );

    // importChat now takes the domain model directly.
    await _chatRepository.importChat(finalChat, parentFolderId: parentFolderId);
  }
}
