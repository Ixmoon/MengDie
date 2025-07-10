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
import '../repositories/chat_repository.dart';
import '../repositories/message_repository.dart';

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
  // static const _jsonExifTag = 'UserComment'; // 不再使用 UserComment
  static const int _jsonExifTagId = 0x010e; // 使用 ImageDescription Tag ID
  static const String _jsonExifJsonKey = 'Image ImageDescription'; // exif 库中 ImageDescription 的键

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

  // --- 新增：批量导出到 ZIP ---
  Future<String?> exportChatsToZip(List<int> chatIds) async {
    debugPrint("ChatExportImportService: 开始将 ${chatIds.length} 个聊天导出到 ZIP...");
    await _ensurePermissions();

    final archive = Archive();
    for (final chatId in chatIds) {
      try {
        final chat = await _chatRepository.getChat(chatId);
        final sanitizedTitle = chat?.title?.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_') ?? 'chat_$chatId';
        final fileName = '$sanitizedTitle.jpg';
        
        final exportData = await _generateExportData(chatId);
        if (exportData != null) {
          archive.addFile(ArchiveFile(fileName, exportData.length, exportData));
        }
      } catch (e) {
        debugPrint("ChatExportImportService: 导出聊天 ID $chatId 到 ZIP 时失败: $e");
        // 继续处理下一个
      }
    }

    if (archive.isEmpty) {
      debugPrint("ChatExportImportService: 没有成功导出的聊天可供压缩。");
      throw Exception("未能导出任何聊天。");
    }

    // 使用 ZipEncoder 编码
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    if (zipBytes == null) {
      debugPrint("ChatExportImportService: ZIP 编码失败。");
      throw Exception("创建 ZIP 文件失败。");
    }

    final String suggestedFileName = 'mengdie_chats_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.zip';
    
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

  // --- 导入聊天(支持批量) ---
  Future<int> importChats() async {
    debugPrint("ChatExportImportService: 开始批量导入聊天...");
    await _ensurePermissions();

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: kIsWeb,
        allowMultiple: true, // 允许多选
      );

      if (result == null || result.files.isEmpty) {
        debugPrint("ChatExportImportService: 用户取消了文件选择或未选择文件。");
        return 0;
      }

      int successCount = 0;
      for (final file in result.files) {
        try {
          Uint8List fileBytes;
          if (kIsWeb) {
            if (file.bytes == null) {
              debugPrint("ChatExportImportService: [Batch] Web import - file bytes are null for ${file.name}.");
              continue;
            }
            fileBytes = file.bytes!;
          } else {
            if (file.path == null) {
              debugPrint("ChatExportImportService: [Batch] Native import - file path is null for ${file.name}.");
              continue;
            }
            final f = File(file.path!);
            fileBytes = await f.readAsBytes();
          }

          final exifData = await readExifFromBytes(fileBytes);
          if (exifData.isEmpty) {
            throw Exception("无法读取图片的元数据，或图片不包含元数据。");
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
                } catch (e) {
                  base64String = tag.printable;
                }
              } else if (rawValue is List<int>) {
                try {
                  base64String = ascii.decode(rawValue, allowInvalid: true);
                } catch (e) {
                  base64String = tag.printable;
                }
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
              if (base64String.isEmpty) {
                throw Exception("未能从 EXIF 中提取有效的 Base64 数据。");
              }
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
            throw Exception("未能从图片中恢复有效的聊天数据。");
          }

          ChatExportDto chatDtoFromJson;
          try {
            chatDtoFromJson = ChatExportDto.fromJson(jsonDecode(jsonString));
          } on FormatException {
            throw Exception("导入失败：文件中的数据格式无效或已损坏。");
          }

          String? importedCoverImageBase64String = base64Encode(fileBytes);

          final chatDto = ChatExportDto(
            title: chatDtoFromJson.title,
            systemPrompt: chatDtoFromJson.systemPrompt,
            isFolder: chatDtoFromJson.isFolder,
            apiConfigId: chatDtoFromJson.apiConfigId,
            contextConfig: chatDtoFromJson.contextConfig,
            xmlRules: chatDtoFromJson.xmlRules,
            messages: chatDtoFromJson.messages,
            coverImageBase64: importedCoverImageBase64String,
            enablePreprocessing: chatDtoFromJson.enablePreprocessing,
            preprocessingPrompt: chatDtoFromJson.preprocessingPrompt,
            preprocessingApiConfigId: chatDtoFromJson.preprocessingApiConfigId,
            enableSecondaryXml: chatDtoFromJson.enableSecondaryXml,
            secondaryXmlPrompt: chatDtoFromJson.secondaryXmlPrompt,
            secondaryXmlApiConfigId: chatDtoFromJson.secondaryXmlApiConfigId,
            contextSummary: chatDtoFromJson.contextSummary,
            continuePrompt: chatDtoFromJson.continuePrompt,
          );

          await _chatRepository.importChat(chatDto);
          successCount++;
        } catch (e) {
          debugPrint("ChatExportImportService: [Batch] 导入文件 ${file.name} 失败: $e");
          // Just log and continue with the next file.
        }
      }
      return successCount;
    } catch (e, s) {
      debugPrint("ChatExportImportService: 批量导入操作失败 - $e\n$s");
      rethrow; // Rethrow to be caught by the UI
    }
  }

  // --- 辅助函数 (示例，需要具体实现或库支持) ---
  // Future<Uint8List> _addExifData(Uint8List imageData, Map<String, IfdTag> exifData) async {
  //   // 实现将 exifData 合并到 imageData 的逻辑
  //   // 这可能需要解析 JPG 结构，找到 APP1 段，然后插入或修改 EXIF 信息
  //   // 或者使用专门的库来完成
  //   debugPrint("警告: _addExifData 尚未实现！");
  //   return imageData; // 返回原始数据
  // }
}
