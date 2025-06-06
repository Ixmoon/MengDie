import 'dart:convert'; // For base64Encode, base64Decode
import 'dart:io'; // For File (still needed for ImagePicker XFile, and potentially background image if kept)
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart'; // For picking images
import 'package:path_provider/path_provider.dart'; // For getting app directory
import 'package:path/path.dart' as p; // For path manipulation (basename, join)

// 导入模型、Provider 和仓库
import '../providers/chat_state_providers.dart'; // Needs currentChatProvider
import '../repositories/chat_repository.dart'; // Needs chatRepositoryProvider

// 本文件包含用于管理聊天封面和背景图片的屏幕界面。

// --- 聊天图库屏幕 ---
// 使用 ConsumerWidget 因为主要逻辑在辅助函数中，不需要复杂的状态管理。
class ChatGalleryScreen extends ConsumerWidget {
  final int chatId; // 通过路由传递的聊天 ID
  const ChatGalleryScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
     // 监听当前聊天数据流
     final chatAsync = ref.watch(currentChatProvider(chatId));
     // 创建 ImagePicker 实例
     final ImagePicker picker = ImagePicker();

     // --- 辅助函数：选择并设置封面图片 (Base64) ---
     Future<void> _pickAndSetCoverImageBase64(ImageSource source, BuildContext context, WidgetRef ref) async {
       try {
         final XFile? image = await picker.pickImage(source: source);
         if (image == null) {
            debugPrint("图片选择已取消。");
            return;
         }

         final Uint8List imageBytes = await image.readAsBytes();
         final String newBase64String = base64Encode(imageBytes);

         final chat = ref.read(currentChatProvider(chatId)).value;
         if (chat != null) {
            // 创建一个副本或确保 chat 对象是可变的
            // 对于 Riverpod StateNotifier, 通常是不可变的，所以需要创建新实例或使用 copyWith
            // 假设 chatRepository.saveChat 接受一个 Chat 对象并处理更新
            final chatToUpdate = chat; // 如果 Chat 是类且可变
            chatToUpdate.coverImageBase64 = newBase64String;
            // backgroundImagePath 保持不变

            await ref.read(chatRepositoryProvider).saveChat(chatToUpdate);

            if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('封面图片已更新')));
            }
         }
       } catch (e) {
         debugPrint("设置封面图片 (Base64) 时出错: $e");
         if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('图片处理失败: $e'), backgroundColor: Colors.red));
         }
       }
     }
    // --- 结束辅助函数 ---

    // --- 构建封面图片显示区域的辅助函数 ---
    Widget _buildCoverImageDisplay(BuildContext context, String? base64String, String imageLabel, IconData defaultIcon) {
      Widget imageWidget;
      if (base64String != null && base64String.isNotEmpty){
          try {
            final Uint8List imageBytes = base64Decode(base64String);
            imageWidget = Image.memory(imageBytes, fit: BoxFit.contain,
              errorBuilder: (ctx, err, st) => Icon(Icons.broken_image, size: 60, color: Colors.grey.shade400),
            );
          } catch (e) {
            // Base64 解码失败
            imageWidget = Icon(Icons.broken_image, size: 60, color: Colors.grey.shade400);
            debugPrint("解码 Base64 封面图片时出错: $e");
          }
      } else {
        imageWidget = Icon(defaultIcon, size: 60, color: Colors.grey.shade400);
      }
      return Column(
         children: [
            Text(imageLabel, style: Theme.of(context).textTheme.titleMedium),
             const SizedBox(height: 10),
             Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                   color: Colors.grey.shade200,
                   borderRadius: BorderRadius.circular(8),
                ),
                child: imageWidget,
             ),
         ],
      );
    }
    // --- 结束构建图片显示区域辅助函数 ---

    return Scaffold(
      appBar: AppBar(title: const Text('封面图片管理')), // 修改标题
      // 处理聊天数据加载状态
      body: chatAsync.when(
         data: (chat) {
             if (chat == null) return const Center(child: Text('聊天未找到'));

             final String? coverImageBase64 = chat.coverImageBase64;

             return Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                   children: [
                      // --- 封面图片部分 ---
                      _buildCoverImageDisplay(context, coverImageBase64, '当前封面图片', Icons.image_outlined),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           ElevatedButton.icon(
                             icon: const Icon(Icons.photo_library),
                             label: const Text('选择封面图片'),
                             onPressed: () => _pickAndSetCoverImageBase64(ImageSource.gallery, context, ref),
                           ),
                           // 可选：添加拍照按钮
                           // const SizedBox(width: 10),
                           // ElevatedButton.icon(
                           //   icon: const Icon(Icons.camera_alt),
                           //   label: const Text('拍照设置封面'),
                           //   onPressed: () => _pickAndSetCoverImageBase64(ImageSource.camera, context, ref),
                           // ),
                        ],
                      ),
                       if (coverImageBase64 != null)
                          TextButton.icon(
                             icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              label: const Text('移除封面图片', style: TextStyle(color: Colors.redAccent)),
                              onPressed: () async {
                                 final chatToUpdate = ref.read(currentChatProvider(chatId)).value;
                                 if (chatToUpdate != null && chatToUpdate.coverImageBase64 != null) {
                                    chatToUpdate.coverImageBase64 = null; // 清除 Base64 数据
                                   await ref.read(chatRepositoryProvider).saveChat(chatToUpdate);
                                    // 无需删除文件，因为 Base64 直接存储在数据库中
                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('封面图片已移除')));
                                }
                              },
                          ),
                      // 注意：背景图片 (backgroundImagePath) 的管理已从此屏幕移除，以专注于封面图片 Base64 的重构。
                      // 如果需要管理背景图片，应添加单独的 UI 和逻辑。
                    ],
                 ),
              );
         },
          loading: () => const Center(child: CircularProgressIndicator()), // const
          error: (err, stack) => Center(child: Text('无法加载图片信息: $err')),
      )
    );
  }
}
