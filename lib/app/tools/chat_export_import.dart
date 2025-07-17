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
import '../../domain/models/models.dart';
import '../repositories/chat_repository.dart';
import '../repositories/message_repository.dart';
import '../providers/repository_providers.dart';

// --- Service Provider ---
final chatExportImportServiceProvider = Provider<ChatExportImportService>((ref) {
  // 依赖 ChatRepository 和 MessageRepository
  final chatRepo = ref.watch(chatRepositoryProvider);
  final messageRepo = ref.watch(messageRepositoryProvider);
  return ChatExportImportService(chatRepo, messageRepo);
});

// --- Chat Export/Import Service Implementation ---
class ChatExportImportService {
  final ChatRepository _chatRepository;
  final MessageRepository _messageRepository;
  // --- 新版 PNG 格式常量 ---
  static const String _pngCharaKeyword = 'chara';

  // --- 旧版 JPG EXIF 格式常量 (保留用于导入兼容) ---
  static const String _jsonExifJsonKey = 'Image ImageDescription';

  ChatExportImportService(this._chatRepository, this._messageRepository);

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
      // --- 更新：生成新的 PNG 格式 ---
      final imageBytesWithPngData = await _generateExportData(chatId);
      if (imageBytesWithPngData == null) {
        throw Exception("未能生成导出数据。");
      }

      final chat = await _chatRepository.getChat(chatId);
      final sanitizedTitle = chat?.title?.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_') ?? 'chat_$chatId';
      // 文件扩展名改为 .png
      final suggestedFileName = '$sanitizedTitle.png';

      if (kIsWeb) {
        await FilePicker.platform.saveFile(
          dialogTitle: '请选择保存位置 (Web)',
          fileName: suggestedFileName,
          bytes: Uint8List.fromList(imageBytesWithPngData),
        );
        debugPrint("ChatExportImportService: Web export initiated for $suggestedFileName.");
        return null;
      } else {
        String? finalSavePath = await FilePicker.platform.saveFile(
          dialogTitle: '请选择保存位置',
          fileName: suggestedFileName,
          bytes: Uint8List.fromList(imageBytesWithPngData),
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
        bytes: Uint8List.fromList(zipBytes),
      );
      debugPrint("ChatExportImportService: Web ZIP export initiated.");
      return null;
    } else {
      String? finalSavePath = await FilePicker.platform.saveFile(
        dialogTitle: '保存 ZIP 文件',
        fileName: suggestedFileName,
        bytes: Uint8List.fromList(zipBytes),
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
          // 文件扩展名改为 .png
          final fileName = '$sanitizedTitle.png';
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
      } catch (e) {
        debugPrint("ChatExportImportService: [_generateExportData] 从 Base64 解码封面图片时出错: $e");
      }
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
            await _importFromImageBytes(file.bytes!, parentFolderId, isBatch: isBatchImport, fileName: file.name);
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
          await _importFromImageBytes(file.content, parentFolderId, isBatch: true, fileName: file.name);
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
        final now = DateTime.now();
        final folderToCreate = Chat(
            title: part,
            isFolder: true,
            createdAt: now,
            updatedAt: now,
        );
        // importChat now handles the domain model directly.
        final newFolderId = await _chatRepository.importChat(folderToCreate, parentFolderId: currentParentId);
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
  Future<void> _importFromImageBytes(Uint8List imageBytes, int? parentFolderId, {bool isBatch = false, required String fileName}) async {
    final lowerCaseFileName = fileName.toLowerCase();
    
    // 优先尝试基于文件扩展名的解析
    if (lowerCaseFileName.endsWith('.png')) {
      try {
        await _importFromPngTavern(imageBytes, parentFolderId, isBatch: isBatch);
        return; // PNG 成功，直接返回
      } catch (e) {
        debugPrint("ChatExportImportService: 将 '$fileName' 作为 PNG 导入失败: $e. 将尝试作为 JPG 回退。");
        // 如果失败，可能是个伪装成 PNG 的 JPG，尝试 EXIF
      }
    }

    // 对于 .jpg, .jpeg, 或 .png 解析失败的情况，尝试 EXIF
    if (lowerCaseFileName.endsWith('.jpg') || lowerCaseFileName.endsWith('.jpeg') || lowerCaseFileName.endsWith('.png')) {
      try {
        await _importFromJpgExif(imageBytes, parentFolderId, isBatch: isBatch);
      } catch (e) {
        throw Exception("无法将文件 '$fileName' 作为任何已知格式（PNG Tavern 或 JPG EXIF）导入。");
      }
    } else {
      throw Exception("不支持的文件类型: $fileName");
    }
  }

  // --- 新增：从 PNG tEXt 数据块导入（酒馆角色卡格式） ---
  Future<void> _importFromPngTavern(Uint8List imageBytes, int? parentFolderId, {bool isBatch = false}) async {
    final image = img.decodePng(imageBytes);
    if (image == null) {
      throw Exception("无法解码 PNG 图片。");
    }

    if (image.textData == null || !image.textData!.containsKey(_pngCharaKeyword)) {
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
    
    await _processImportedJson(jsonString, imageBytes, parentFolderId, isBatch: isBatch);
  }

  // --- 重构：从 JPG EXIF 数据导入（旧版格式） ---
  Future<void> _importFromJpgExif(Uint8List imageBytes, int? parentFolderId, {bool isBatch = false}) async {
    final exifData = await readExifFromBytes(imageBytes);
    if (exifData.isEmpty) {
      throw Exception("无法读取图片的元数据。");
    }

    String? jsonString;
    const descriptionKey = _jsonExifJsonKey;

    if (exifData.containsKey(descriptionKey)) {
      final tag = exifData[descriptionKey];
      if (tag != null) {
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

    if (jsonString.isEmpty) {
      throw Exception("未能从图片 EXIF 中恢复有效的聊天数据。");
    }

    await _processImportedJson(jsonString, imageBytes, parentFolderId, isBatch: isBatch);
  }

  // --- 新增：处理已解析 JSON 的共享逻辑 ---
  Future<void> _processImportedJson(String jsonString, Uint8List imageBytes, int? parentFolderId, {bool isBatch = false}) async {
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
    bool hasRealCoverInJson = chatFromJson.coverImageBase64 != null && chatFromJson.coverImageBase64!.isNotEmpty;
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
