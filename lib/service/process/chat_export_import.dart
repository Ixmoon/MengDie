import 'dart:convert'; // 用于 JSON 编码/解码
import 'dart:io'; // 用于文件操作
import 'dart:typed_data'; // For Uint8List
import 'package:archive/archive_io.dart'; // For ZIP encoding
import 'package:intl/intl.dart'; // For date formatting
import 'package:permission_handler/permission_handler.dart'; // 请求权限
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint; // Added kIsWeb
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img; // 使用 'img' 前缀避免冲突
import 'package:file_picker/file_picker.dart'; // 选择文件
import 'package:exif/exif.dart'; // 读写 EXIF

// 导入模型、DTO 和仓库
import '../../data/models/export_import_dtos.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../ui/providers/repository_providers.dart';

// --- Service Provider ---
final chatExportImportServiceProvider = Provider<ChatExportImportService>((ref) {
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
  // static const _jsonExifTag = 'UserComment'; // 不再使用 UserComment
  static const int _jsonExifTagId = 0x010e; // 使用 ImageDescription Tag ID
  static const String _jsonExifJsonKey = 'Image ImageDescription'; // exif 库中 ImageDescription 的键

  ChatExportImportService(this._ref, this._chatRepository, this._messageRepository);

  Future<void> _ensurePermissions() async {
    if (kIsWeb) return; // Web 不需要这些权限

    PermissionStatus status;

    if (Platform.isAndroid) {
      // 对于 Android 13 (API 33) 及以上版本，优先请求照片权限
      // Permission.photos 涵盖了读取媒体图片。对于写入，也与此相关。
      status = await Permission.photos.status;
      // debugPrint("ChatExportImportService: Android Photos permission status: $status");

      if (!status.isGranted) {
        status = await Permission.photos.request();
        // debugPrint("ChatExportImportService: Android Photos permission requested, new status: $status");
      }

      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          // debugPrint("ChatExportImportService: 照片权限被永久拒绝，正在打开应用设置。");
          await openAppSettings(); // 引导用户到应用设置
          throw Exception("照片权限已被永久拒绝，请在系统设置中开启。");
        } else {
          // debugPrint("ChatExportImportService: 照片权限被拒绝。");
          throw Exception("需要照片权限才能继续操作。");
        }
      }
      // debugPrint("ChatExportImportService: Android 照片权限已授予。");

    } else if (Platform.isIOS) {
      // iOS 照片库权限
      status = await Permission.photos.status; // 用于读取和写入（如果应用创建）
      // debugPrint("ChatExportImportService: iOS Photos permission status: $status");
      if (!status.isGranted) {
        status = await Permission.photos.request();
        // debugPrint("ChatExportImportService: iOS Photos permission requested, new status: $status");
      }

      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          // debugPrint("ChatExportImportService: iOS 照片权限被永久拒绝，正在打开应用设置。");
          await openAppSettings();
          throw Exception("照片权限已被永久拒绝，请在系统设置中开启。");
        } else {
          // debugPrint("ChatExportImportService: iOS 照片权限被拒绝。");
          throw Exception("需要照片权限才能继续操作。");
        }
      }
      // debugPrint("ChatExportImportService: iOS 照片权限已授予。");
    }
    // 其他平台不在此处处理权限
  }

  // --- 导出聊天 ---
  Future<String?> exportChat(int chatId, {bool skipPermissionCheck = false}) async {
    debugPrint("ChatExportImportService: 开始导出聊天 ID: $chatId");

    if (!skipPermissionCheck) {
      await _ensurePermissions();
    }

    try {
      final imageBytesWithExif = await _generateExportData(chatId);
      if (imageBytesWithExif == null) {
        throw Exception("未能生成导出数据。");
      }

      if (kIsWeb) {
        final chat = await _chatRepository.getChat(chatId);
        final sanitizedTitle = chat?.title?.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_') ?? 'chat_$chatId';
        final suggestedFileName = '$sanitizedTitle.jpg';
        await FilePicker.platform.saveFile(
          dialogTitle: '请选择保存位置 (Web)',
          fileName: suggestedFileName,
          bytes: Uint8List.fromList(imageBytesWithExif),
        );
        debugPrint("ChatExportImportService: Web export initiated for $suggestedFileName.");
        return null;
      } else {
        final chat = await _chatRepository.getChat(chatId);
        final sanitizedTitle = chat?.title?.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_') ?? 'chat_$chatId';
        final suggestedFileName = '$sanitizedTitle.jpg';
        String? finalSavePath = await FilePicker.platform.saveFile(
          dialogTitle: '请选择保存位置',
          fileName: suggestedFileName,
          bytes: Uint8List.fromList(imageBytesWithExif),
        );
        if (finalSavePath != null) {
          debugPrint("ChatExportImportService: 文件已成功导出到: $finalSavePath");
          return finalSavePath;
        } else {
          debugPrint("ChatExportImportService: 用户取消了文件保存操作。");
          return null;
        }
      }
    } catch (e, s) {
      debugPrint("ChatExportImportService: 导出失败 - $e\n$s");
      if (e is Exception) {
        rethrow;
      }
      throw Exception("导出聊天时发生未知错误: $e");
    }
  }

  // --- 更新：批量导出到 ZIP（支持文件夹结构）---
  Future<String?> exportChatsToZip(List<int> chatIds) async {
    debugPrint("ChatExportImportService: 开始将 ${chatIds.length} 个项目导出到 ZIP...");
    await _ensurePermissions();

    final archive = Archive();
    // Start the recursive process from the root of the archive
    await _addItemsToArchive(archive, chatIds, '');

    if (archive.isEmpty) {
      debugPrint("ChatExportImportService: 没有成功导出的项目可供压缩。");
      throw Exception("未能导出任何项目。");
    }

    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    // zipBytes is non-nullable, so no need to check for null

    final String suggestedFileName = 'mengdie_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.zip';
    
    if (kIsWeb) {
      await FilePicker.platform.saveFile(
        dialogTitle: '保存 ZIP 文件',
        fileName: suggestedFileName,
        bytes: Uint8List.fromList(zipBytes!),
      );
      debugPrint("ChatExportImportService: Web ZIP export initiated.");
      return null;
    } else {
      String? finalSavePath = await FilePicker.platform.saveFile(
        dialogTitle: '保存 ZIP 文件',
        fileName: suggestedFileName,
        bytes: Uint8List.fromList(zipBytes!),
      );
      if (finalSavePath != null) {
        debugPrint("ChatExportImportService: ZIP 文件已成功导出到: $finalSavePath");
        return finalSavePath;
      } else {
        debugPrint("ChatExportImportService: 用户取消了 ZIP 文件保存操作。");
        return null;
      }
    }
  }

  // --- 新增：递归地将项目（聊天和文件夹）添加到压缩包 ---
  Future<void> _addItemsToArchive(Archive archive, List<int> itemIds, String currentPath) async {
    for (final itemId in itemIds) {
      try {
        final item = await _chatRepository.getChat(itemId);
        if (item == null) continue;

        final sanitizedTitle = item.title?.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_') ?? 'item_$itemId';

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
          final fileName = '$sanitizedTitle.jpg';
          final filePath = '$currentPath$fileName';
          
          final exportData = await _generateExportData(itemId);
          if (exportData != null) {
            archive.addFile(ArchiveFile(filePath, exportData.length, exportData));
          }
        }
      } catch (e, s) {
        debugPrint("ChatExportImportService: [_addItemsToArchive] 导出项目 ID $itemId 时失败: $e\n$s");
        // Continue with the next item
      }
    }
  }

  // --- 新增：内部生成导出数据的方法 ---
  Future<List<int>?> _generateExportData(int chatId) async {
    final chat = await _chatRepository.getChat(chatId);
    if (chat == null) {
      debugPrint("ChatExportImportService: [_generateExportData] 未找到聊天 ID: $chatId");
      return null;
    }
    final messages = await _messageRepository.getMessagesForChat(chatId);

    final messageDtos = messages.map((m) => MessageExportDto(
      rawText: m.rawText,
      role: m.role,
      parts: m.parts.map((p) => p.toJson()).toList(),
      originalXmlContent: m.originalXmlContent,
      secondaryXmlContent: m.secondaryXmlContent,
    )).toList();

    final chatDto = ChatExportDto(
      title: chat.title,
      systemPrompt: chat.systemPrompt,
      isFolder: chat.isFolder,
      apiConfigId: chat.apiConfigId,
      coverImageBase64: chat.coverImageBase64,
      enablePreprocessing: chat.enablePreprocessing,
      preprocessingPrompt: chat.preprocessingPrompt,
      preprocessingApiConfigId: chat.preprocessingApiConfigId,
      enableSecondaryXml: chat.enableSecondaryXml,
      secondaryXmlPrompt: chat.secondaryXmlPrompt,
      secondaryXmlApiConfigId: chat.secondaryXmlApiConfigId,
      contextSummary: chat.contextSummary,
      continuePrompt: chat.continuePrompt,
      contextConfig: ContextConfigDto(
        mode: chat.contextConfig.mode,
        maxTurns: chat.contextConfig.maxTurns,
        maxContextTokens: chat.contextConfig.maxContextTokens,
      ),
      xmlRules: chat.xmlRules.map((r) => XmlRuleDto(tagName: r.tagName, action: r.action)).toList(),
      messages: messageDtos,
      hasRealCoverImage: chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty,
      backgroundImagePath: chat.backgroundImagePath, // 导出模板路径
      // 填充时间戳
      createdAt: chat.createdAt,
      updatedAt: chat.updatedAt,
      orderIndex: chat.orderIndex, // 导出排序信息
    );

    final jsonString = jsonEncode(chatDto.toJson());
    final jsonBytes = utf8.encode(jsonString);
    final base64String = base64Encode(jsonBytes);

    img.Image? image;
    if (chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty) {
      try {
        final coverBytes = base64Decode(chat.coverImageBase64!);
        image = img.decodeImage(coverBytes);
      } catch (e) {
        debugPrint("ChatExportImportService: [_generateExportData] 从 Base64 解码封面图片时出错: $e");
      }
    }

    if (image == null) {
      image = img.Image(width: 200, height: 200);
      img.fill(image, color: img.ColorRgb8(240, 240, 240));
    }

    image.exif.imageIfd[_jsonExifTagId] = base64String;
    return img.encodeJpg(image);
  }

  // --- 更新：导入聊天（支持批量图片和 ZIP 压缩包），可指定父文件夹 ---
  Future<int> importChats({int? parentFolderId}) async {
    debugPrint("ChatExportImportService: 开始导入到文件夹 ID: $parentFolderId");
    await _ensurePermissions();

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'zip'],
        withData: true, // Always get bytes for both web and native
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        debugPrint("ChatExportImportService: 用户取消了文件选择。");
        return 0;
      }

      int successCount = 0;
      final bool isBatchImport = result.files.length > 1 || (result.files.length == 1 && result.files.first.name.toLowerCase().endsWith('.zip'));

      for (final file in result.files) {
        if (file.bytes == null) {
          debugPrint("ChatExportImportService: 文件 ${file.name} 的数据为空，跳过。");
          continue;
        }
        
        final fileName = file.name.toLowerCase();
        try {
          if (fileName.endsWith('.zip')) {
            // ZIP 文件总是被视为批量导入
            final count = await _importFromZip(file.bytes!, parentFolderId);
            successCount += count;
          } else if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.png')) {
            // 根据 isBatchImport 标志决定如何导入图片
            await _importFromImage(file.bytes!, parentFolderId, isBatch: isBatchImport);
            successCount++;
          }
        } catch (e, s) {
          debugPrint("ChatExportImportService: 导入文件 ${file.name} 失败: $e\n$s");
          // Log and continue with the next file.
        }
      }
      return successCount;
    } catch (e, s) {
      debugPrint("ChatExportImportService: 导入操作失败 - $e\n$s");
      rethrow; // Rethrow to be caught by the UI
    }
  }

  // ZIP 导入逻辑现在接收一个基础的 parentFolderId
  Future<int> _importFromZip(Uint8List zipBytes, int? baseParentFolderId) async {
    debugPrint("ChatExportImportService: 正在从 ZIP 文件导入到基础文件夹 ID: $baseParentFolderId");
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
          final parentPath = pathParts.length > 1 ? pathParts.sublist(0, pathParts.length - 1).join('/') : '';
          
          // Get or create the folder ID for the parent path, relative to the baseParentFolderId
          final parentFolderId = await _getOrCreateFolderIdByPath(parentPath, createdFolderIds, baseParentFolderId);

          // ZIP 包内的文件总是作为批量导入的一部分，保留其排序信息
          await _importFromImage(file.content, parentFolderId, isBatch: true);
          successCount++;
        } catch (e, s) {
          debugPrint("ChatExportImportService: 从 ZIP 中的文件 ${file.name} 导入失败: $e\n$s");
        }
      }
    }
    return successCount;
  }

  // _getOrCreateFolderIdByPath 现在也接收基础父文件夹 ID
  Future<int?> _getOrCreateFolderIdByPath(String path, Map<String, int?> createdFolderIds, int? baseParentFolderId) async {
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
        debugPrint("ChatExportImportService: 正在创建文件夹: $currentPath in parent $currentParentId");
        final folderDto = ChatExportDto.createFolder(title: part);
        // importChat 现在会自动处理用户绑定
        final newFolderId = await _chatRepository.importChat(folderDto, parentFolderId: currentParentId);
        createdFolderIds[currentPath] = newFolderId;
        currentParentId = newFolderId;
      } else {
        // The folder already exists in our map, just update the current parent ID
        currentParentId = createdFolderIds[currentPath];
      }
    }
    return currentParentId;
  }

  Future<void> _importFromImage(Uint8List imageBytes, int? parentFolderId, {bool isBatch = false}) async {
    final exifData = await readExifFromBytes(imageBytes);
    if (exifData.isEmpty) {
      throw Exception("无法读取图片的元数据。");
    }

    String? jsonString;
    const descriptionKey = _jsonExifJsonKey;

    if (exifData.containsKey(descriptionKey)) {
      final tag = exifData[descriptionKey];
      if (tag != null) {
        // ... [EXIF parsing logic remains the same]
        dynamic rawValue = tag.values;
        String? base64String;
        if (rawValue is IfdBytes) {
          try {
            List<int> bytes = rawValue.toList().cast<int>();
            base64String = ascii.decode(bytes, allowInvalid: true);
          } catch (e) { base64String = tag.printable; }
        } else if (rawValue is List<int>) {
          try {
            base64String = ascii.decode(rawValue, allowInvalid: true);
          } catch (e) { base64String = tag.printable; }
        } else if (rawValue is String) {
          base64String = rawValue;
        } else {
          base64String = tag.printable;
        }
        base64String = base64String.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
        if (base64String.startsWith('b"') && base64String.endsWith('"')) {
          base64String = base64String.substring(2, base64String.length - 1);
        } else if (base64String.startsWith("b'") && base64String.endsWith("'")) {
          base64String = base64String.substring(2, base64String.length - 1);
        }
        if (base64String.isEmpty) throw Exception("未能从 EXIF 中提取有效的 Base64 数据。");
        
        try {
          final decodedBytes = base64Decode(base64String);
          jsonString = utf8.decode(decodedBytes);
        } catch (e) {
          throw Exception("无法解码存储在图片中的聊天数据。数据可能已损坏。");
        }
      } else {
        throw Exception("未找到 ImageDescription 标签对象。");
      }
    } else {
      throw Exception("图片 EXIF 数据中缺少 '$descriptionKey' 标签。");
    }

    if (jsonString == null || jsonString.isEmpty) {
      throw Exception("未能从图片中恢复有效的聊天数据。");
    }

    ChatExportDto chatDtoFromJson;
    try {
      chatDtoFromJson = ChatExportDto.fromJson(jsonDecode(jsonString));
    } on FormatException {
      throw Exception("导入失败：文件中的数据格式无效或已损坏。");
    }

    // Override the cover image with the importing image itself, only if it's a real one
    String? importedCoverImageBase64String;
    if (chatDtoFromJson.hasRealCoverImage) {
      importedCoverImageBase64String = base64Encode(imageBytes);
    }

    // 如果不是批量导入（即单个文件导入），则强制将 orderIndex 设为 null 以实现置顶。
    // 否则，保留从文件中解析出的 orderIndex。
    final finalChatDto = chatDtoFromJson.copyWith(
      coverImageBase64: importedCoverImageBase64String,
      orderIndex: isBatch ? chatDtoFromJson.orderIndex : null,
    );
    
    // importChat 现在会自动处理用户绑定
    await _chatRepository.importChat(finalChatDto, parentFolderId: parentFolderId);
  }
}
