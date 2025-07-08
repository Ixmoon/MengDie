import 'dart:convert'; // 用于 JSON 编码/解码
import 'dart:io'; // 用于文件操作
import 'dart:typed_data'; // For Uint8List
import 'package:permission_handler/permission_handler.dart'; // 请求权限
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint; // Added kIsWeb
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img; // 使用 'img' 前缀避免冲突
// import 'package:isar/isar.dart'; // Removed Isar import
import 'package:file_picker/file_picker.dart'; // 选择文件
// import 'package:permission_handler/permission_handler.dart'; // 请求权限 - 已移除，重复导入
import 'package:exif/exif.dart'; // 读写 EXIF
// import 'package:share_plus/share_plus.dart'; // 分享文件 - 已移除，未使用
import 'package:uuid/uuid.dart'; // 生成唯一文件名

// 导入模型、DTO 和仓库
// import '../models/models.dart'; // 已移除，未使用，通过 export_import_dtos 间接使用
import '../models/export_import_dtos.dart';
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
  Future<String?> exportChat(int chatId) async { // Changed Id to int
    debugPrint("ChatExportImportService: 开始导出聊天 ID: $chatId");

    // 1. 请求权限
    await _ensurePermissions();

    // 2. 检查仓库是否就绪 (Drift repositories are assumed ready if obtained)
    // if (!_chatRepository.isarInstance.isOpen || !_messageRepository.isReady) { // Removed Isar specific checks
    //   debugPrint("ChatExportImportService: 仓库未就绪，无法导出。");
    //   throw Exception("数据库未准备好，无法导出。");
    // }

    try {
      // 3. 获取聊天和消息数据
      final chat = await _chatRepository.getChat(chatId);
      if (chat == null) {
        debugPrint("ChatExportImportService: 未找到聊天 ID: $chatId");
        throw Exception("未找到要导出的聊天。");
      }
      final messages = await _messageRepository.getMessagesForChat(chatId);
      debugPrint("ChatExportImportService: 获取到 ${messages.length} 条消息。");

      // 4. 将数据转换为 DTOs
      final messageDtos = messages.map((m) {
        return MessageExportDto(
          rawText: m.rawText, // Still keep for backward compatibility
          role: m.role,
          parts: m.parts.map((p) => p.toJson()).toList(), // Serialize each part
          originalXmlContent: m.originalXmlContent,
        );
      }).toList();

      // --- 修改：直接从 Chat 对象获取 Base64 字符串 ---
      // Chat 对象现在应该直接持有 Base64 编码的封面图字符串
      // 无需再通过 coverImagePath 读取文件并转换
      // --- 结束修改 ---

      final chatDto = ChatExportDto(
        title: chat.title,
        systemPrompt: chat.systemPrompt,
        isFolder: chat.isFolder,
        apiType: chat.apiType, // 新增
        selectedOpenAIConfigId: chat.selectedOpenAIConfigId, // 新增
        coverImageBase64: chat.coverImageBase64, // 直接使用 Chat模型中的 Base64 字符串
        enablePreprocessing: chat.enablePreprocessing,
        preprocessingPrompt: chat.preprocessingPrompt,
        enablePostprocessing: chat.enablePostprocessing,
        postprocessingPrompt: chat.postprocessingPrompt,
        contextSummary: chat.contextSummary,
        generationConfig: GenerationConfigDto(
          modelName: chat.generationConfig.modelName,
          temperature: chat.generationConfig.temperature,
          topP: chat.generationConfig.topP,
          topK: chat.generationConfig.topK,
          maxOutputTokens: chat.generationConfig.maxOutputTokens,
          stopSequences: chat.generationConfig.stopSequences,
          useCustomTemperature: chat.generationConfig.useCustomTemperature, // 新增
          useCustomTopP: chat.generationConfig.useCustomTopP, // 新增
          useCustomTopK: chat.generationConfig.useCustomTopK, // 新增
          safetySettings: chat.generationConfig.safetySettings.map((s) =>
            SafetySettingRuleDto(category: s.category, threshold: s.threshold)
          ).toList(),
        ),
        contextConfig: ContextConfigDto(
          mode: chat.contextConfig.mode,
          maxTurns: chat.contextConfig.maxTurns,
          maxContextTokens: chat.contextConfig.maxContextTokens,
        ),
        xmlRules: chat.xmlRules.map((r) =>
          XmlRuleDto(tagName: r.tagName, action: r.action)
        ).toList(),
        messages: messageDtos,
      );

      // 5. 序列化 DTO 为 JSON 字符串
      final jsonString = jsonEncode(chatDto.toJson());
      debugPrint("ChatExportImportService: JSON 数据已生成 (长度: ${jsonString.length})");

      // --- 新增：Base64 编码 ---
      final jsonBytes = utf8.encode(jsonString);
      final base64String = base64Encode(jsonBytes);
      debugPrint("ChatExportImportService: JSON Base64 编码后长度: ${base64String.length}");
      // 注意：Base64 会增加约 33% 的大小，仍需注意 EXIF 限制

      // --- 修改：尝试从 Base64 解码封面图，否则创建占位图 ---
      img.Image? image; // 声明为可空
      if (chat.coverImageBase64 != null && chat.coverImageBase64!.isNotEmpty) {
        try {
          final coverBytes = base64Decode(chat.coverImageBase64!);
          image = img.decodeImage(coverBytes); // 尝试解码
          if (image != null) {
            debugPrint("ChatExportImportService: 成功从 Base64 解码封面图片。");
          } else {
            debugPrint("ChatExportImportService: 从 Base64 解码封面图片失败。");
          }
        } catch (e) {
          debugPrint("ChatExportImportService: 从 Base64 解码封面图片时出错: $e");
          image = null; // 确保 image 为 null 以触发备选方案
        }
      } else {
         debugPrint("ChatExportImportService: 未设置封面图片的 Base64 数据。");
      }

      // 如果加载或解码封面图失败，则创建占位图
      if (image == null) {
        debugPrint("ChatExportImportService: 创建 200x200 方形占位图作为备选。");
        image = img.Image(width: 200, height: 200); // 创建占位图
        img.fill(image, color: img.ColorRgb8(240, 240, 240)); // 填充灰色
      }
      // --- 结束修改 ---

      // 7. 将 Base64 编码后的字符串添加到 EXIF 数据中 (添加到加载的图片或占位图)
      image.exif.imageIfd[_jsonExifTagId] = base64String; // 存储 Base64 字符串
      debugPrint("ChatExportImportService: Base64 数据已添加到 EXIF ImageDescription (Tag $_jsonExifTagId)。");

      // 8. 重新编码图片为 JPG (encodeJpg 会包含 EXIF 数据)
      List<int> imageBytesWithExif = img.encodeJpg(image); 
      debugPrint("ChatExportImportService: 图片已重新编码为 JPG (包含 EXIF)。");

      if (kIsWeb) {
        // For web, trigger a download using FilePicker
        final String suggestedFileName = 'chat_export_${chatId}_${const Uuid().v4()}.jpg';
        // FilePicker.platform.saveFile will trigger a browser download.
        // It returns null on web, so we can't return a file path.
        // The 'filePath' variable here is just for the dialog title.
        String? webSavePath = await FilePicker.platform.saveFile(
          dialogTitle: '请选择保存位置 (Web)', // Not really used on web for picking location
          fileName: suggestedFileName,
          bytes: Uint8List.fromList(imageBytesWithExif),
        );
        // webSavePath will be null on web. The download is initiated by the browser.
        debugPrint("ChatExportImportService: Web export initiated for $suggestedFileName. saveFile returned: $webSavePath");
        return null; // Indicate success for web, but no path available.
      } else {
        // Native platforms: Use FilePicker.platform.saveFile to let user choose destination
        final String suggestedFileName = 'chat_export_${chatId}_${const Uuid().v4()}.jpg';

        // Removed extended debugging for imageBytesWithExif
        // Assuming imageBytesWithExif is valid if this point is reached.
        
        String? finalSavePath = await FilePicker.platform.saveFile(
          dialogTitle: '请选择保存位置',
          fileName: suggestedFileName,
          bytes: Uint8List.fromList(imageBytesWithExif), // Crucially provide the bytes
        );

        if (finalSavePath != null) {
          debugPrint("ChatExportImportService: 文件已成功导出到: $finalSavePath");
          return finalSavePath; // Return the path where the file was saved
        } else {
          debugPrint("ChatExportImportService: 用户取消了文件保存操作。");
          return null; // User cancelled the save operation
        }
      }

    } catch (e, s) {
      debugPrint("ChatExportImportService: 导出失败 - $e\n$s");
       // 可以根据错误类型提供更具体的错误消息
       if (e is Exception) {
         rethrow; // 重新抛出已知异常并保留堆栈跟踪
       }
       throw Exception("导出聊天时发生未知错误: $e"); // 包装未知错误
    }
  }

  // --- 导入聊天 ---
  Future<int?> importChat() async { // Changed Id? to int?
    debugPrint("ChatExportImportService: 开始导入聊天...");

    // 1. 请求权限
    await _ensurePermissions();

    try {
      // 2. 使用 file_picker 选择文件
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image, // 只允许选择图片
        withData: kIsWeb, // Crucial for web: request bytes
        // allowedExtensions: ['jpg', 'jpeg'], 
      );

      if (result == null || result.files.isEmpty) {
        debugPrint("ChatExportImportService: 用户取消了文件选择或未选择文件。");
        return null; // 用户取消或未选择
      }

      Uint8List fileBytes;

      if (kIsWeb) {
        if (result.files.single.bytes == null) {
          debugPrint("ChatExportImportService: Web import - file bytes are null.");
          throw Exception("无法在 Web 上获取文件内容。");
        }
        fileBytes = result.files.single.bytes!;
        debugPrint("ChatExportImportService: Web import - successfully got file bytes.");
      } else {
        // Native platforms
        if (result.files.single.path == null) {
          debugPrint("ChatExportImportService: Native import - file path is null.");
          throw Exception("无法获取文件路径。");
        }
        final filePath = result.files.single.path!;
        debugPrint("ChatExportImportService: 用户选择了文件: $filePath");
        final file = File(filePath);
        fileBytes = await file.readAsBytes();
      }

      // 4. 使用 exif 包直接从字节读取 EXIF 数据
      final exifData = await readExifFromBytes(fileBytes);
       // Removed EXIF debugging prints

      if (exifData.isEmpty) {
        debugPrint("ChatExportImportService: 错误 - 无法读取图片的 EXIF 数据或图片不含 EXIF 数据。");
        throw Exception("无法读取图片的元数据，或图片不包含元数据。");
      }
      // debugPrint("ChatExportImportService: EXIF 数据已读取 (非空)。"); 

      // 5. 从 EXIF 数据中获取 JSON 字符串 (查找 ImageDescription 标签)
      String? jsonString;
      // ImageDescription 的 Key 通常是 'Image ImageDescription'
      const descriptionKey = _jsonExifJsonKey; // 使用定义的常量

      if (exifData.containsKey(descriptionKey)) {
        final tag = exifData[descriptionKey];
        // debugPrint("ChatExportImportService: Found ImageDescription tag object: $tag");
        if (tag != null) {
          dynamic rawValue = tag.values;
          // debugPrint("ChatExportImportService: Tag raw values type: ${rawValue.runtimeType}");

          String? base64String;
          if (rawValue is IfdBytes) {
            try {
              List<int> bytes = rawValue.toList().cast<int>();
              base64String = ascii.decode(bytes, allowInvalid: true);
              // debugPrint("ChatExportImportService: Decoded Base64 string from IfdBytes using ascii.decode.");
            } catch (e) {
              // debugPrint("ChatExportImportService: Failed to decode IfdBytes as ASCII: $e");
              base64String = tag.printable; 
            }
          } else if (rawValue is List<int>) {
             try {
               base64String = ascii.decode(rawValue, allowInvalid: true);
               // debugPrint("ChatExportImportService: Decoded Base64 string from List<int> using ascii.decode.");
             } catch (e) {
               // debugPrint("ChatExportImportService: Failed to decode List<int> as ASCII: $e");
               base64String = tag.printable;
             }
          } else if (rawValue is String) {
            base64String = rawValue;
            // debugPrint("ChatExportImportService: Tag values is already a String (assuming Base64).");
          } else {
             base64String = tag.printable;
             // debugPrint("ChatExportImportService: Unknown tag.values type, falling back to tag.printable for Base64.");
          }

          // --- Data Sanitization ---
          // Trim whitespace and remove potential null characters (\x00) and other non-printable chars
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
            // After cleaning, attempt to decode
            final decodedBytes = base64Decode(base64String);
            jsonString = utf8.decode(decodedBytes);
          } catch (e) {
            debugPrint("ChatExportImportService: Base64/UTF-8 decoding failed for sanitized string. Error: $e");
            debugPrint("Sanitized Base64 String (First 100 chars): ${base64String.substring(0, (base64String.length) > 100 ? 100 : (base64String.length))}");
            throw Exception("无法解码存储在图片中的聊天数据。数据可能已损坏。");
          }

        } else {
          // debugPrint("ChatExportImportService: ImageDescription tag object is null.");
          throw Exception("未找到 ImageDescription 标签对象。");
        }
      } else {
         // debugPrint("ChatExportImportService: EXIF data does not contain key '$descriptionKey'.");
         throw Exception("图片 EXIF 数据中缺少 '$descriptionKey' 标签。");
      }

       if (jsonString.isEmpty) { // Null check removed as jsonString cannot be null here
          // debugPrint("ChatExportImportService: JSON string is null or empty after decoding.");
         throw Exception("未能从图片中恢复有效的聊天数据。");
      }

      // debugPrint("ChatExportImportService: Ready to parse JSON (Length: ${jsonString.length})");

      // 6. 反序列化 JSON 为 DTO
      ChatExportDto chatDtoFromJson;
      try {
        chatDtoFromJson = ChatExportDto.fromJson(jsonDecode(jsonString));
        // debugPrint("ChatExportImportService: JSON 解析为 ChatExportDto 成功。");
      } on FormatException {
        // debugPrint("ChatExportImportService: JSON 解析失败 - $e\n$s");
        // debugPrint("ChatExportImportService: 无效的 JSON 字符串: $jsonString");
        throw Exception("导入失败：文件中的数据格式无效或已损坏。");
      }

      // --- 修改：将导入的封面图片文件字节转换为 Base64 字符串 ---
      String? importedCoverImageBase64String;
      try {
        importedCoverImageBase64String = base64Encode(fileBytes);
        debugPrint("ChatExportImportService: 导入的封面图片已成功编码为 Base64。");
      } catch (e) {
        debugPrint("ChatExportImportService: 将导入的封面图片编码为 Base64 时出错: $e");
        // 保持 importedCoverImageBase64String 为 null
      }
      // --- 结束修改 ---

      // 使用从 JSON 解析的数据以及封面图片的 Base64 字符串创建最终的 DTO
      final chatDto = ChatExportDto(
        title: chatDtoFromJson.title,
        systemPrompt: chatDtoFromJson.systemPrompt,
        isFolder: chatDtoFromJson.isFolder,
        generationConfig: chatDtoFromJson.generationConfig,
        contextConfig: chatDtoFromJson.contextConfig,
        xmlRules: chatDtoFromJson.xmlRules,
        messages: chatDtoFromJson.messages,
        apiType: chatDtoFromJson.apiType,
        selectedOpenAIConfigId: chatDtoFromJson.selectedOpenAIConfigId,
        coverImageBase64: importedCoverImageBase64String, // 使用封面图片的 Base64 字符串
        enablePreprocessing: chatDtoFromJson.enablePreprocessing,
        preprocessingPrompt: chatDtoFromJson.preprocessingPrompt,
        enablePostprocessing: chatDtoFromJson.enablePostprocessing,
        postprocessingPrompt: chatDtoFromJson.postprocessingPrompt,
        contextSummary: chatDtoFromJson.contextSummary,
      );

       // 7. 调用仓库保存数据
       final newChatId = await _chatRepository.importChat(chatDto);
       // newChatId 不会是 null，移除不必要的检查
       debugPrint("ChatExportImportService: 导入成功，新聊天 ID: $newChatId");

       // 8. 返回新创建的 Chat ID
       return newChatId;

    } catch (e, s) {
      debugPrint("ChatExportImportService: 导入失败 - $e\n$s");
       // 保持或改进错误处理
       if (e is Exception) { // 捕获我们自己抛出的或已知的异常
         rethrow; // 直接重新抛出，保留原始错误信息和堆栈跟踪
       }
       // 对于其他未知错误
      throw Exception("导入聊天时发生未知错误: $e");
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
