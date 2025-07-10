import 'dart:convert'; // For base64Encode, base64Decode
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart'; // For picking images

// 导入模型、Provider 和仓库
import '../../data/providers/chat_state_providers.dart'; // Needs currentChatProvider
import '../../repositories/chat_repository.dart'; // Needs chatRepositoryProvider
import '../widgets/cached_image.dart'; // 导入缓存图片组件

// 本文件包含用于管理聊天封面和背景图片的屏幕界面。

// --- 聊天图库屏幕 ---
// 使用 ConsumerWidget 因为主要逻辑在辅助函数中，不需要复杂的状态管理。
class ChatGalleryScreen extends ConsumerWidget {
  const ChatGalleryScreen({super.key});

  // --- 业务逻辑：选择并设置封面图片 (Base64) ---
  Future<void> _pickAndSetCoverImageBase64(ImageSource source, BuildContext context, WidgetRef ref) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: source);
      if (image == null) {
        debugPrint("图片选择已取消。");
        return;
      }

      final Uint8List imageBytes = await image.readAsBytes();
      final String newBase64String = base64Encode(imageBytes);

      final chatId = ref.read(activeChatIdProvider);
      if (chatId == null) return;
      final chat = ref.read(currentChatProvider(chatId)).value;
      if (chat != null) {
        final chatToUpdate = chat;
        chatToUpdate.coverImageBase64 = newBase64String;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatId = ref.watch(activeChatIdProvider);

    if (chatId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('封面图片管理')),
        body: const Center(child: Text('没有活动的聊天。')),
      );
    }

    final chatAsync = ref.watch(currentChatProvider(chatId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          shadows: <Shadow>[
            Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 1.0)
          ],
        ),
        title: Text(
          '封面图片管理',
          style: TextStyle(
            shadows: <Shadow>[
              Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 1.0)
            ],
          ),
        ),
      ),
      body: chatAsync.when(
        data: (chat) {
          if (chat == null) return const Center(child: Text('聊天未找到'));

          final String? coverImageBase64 = chat.coverImageBase64;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                _CoverImageDisplay(base64String: coverImageBase64),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('选择封面图片'),
                      onPressed: () => _pickAndSetCoverImageBase64(ImageSource.gallery, context, ref),
                    ),
                  ],
                ),
                if (coverImageBase64 != null)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    label: const Text('移除封面图片', style: TextStyle(color: Colors.redAccent)),
                    onPressed: () async {
                      final chatToUpdate = ref.read(currentChatProvider(chatId)).value;
                      if (chatToUpdate != null && chatToUpdate.coverImageBase64 != null) {
                        chatToUpdate.coverImageBase64 = null;
                        await ref.read(chatRepositoryProvider).saveChat(chatToUpdate);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('封面图片已移除')));
                        }
                      }
                    },
                  ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (err, stack) => Center(child: Text('无法加载图片信息: $err')),
      ),
    );
  }
}

/// 封面图片显示区域的小部件
class _CoverImageDisplay extends StatelessWidget {
  final String? base64String;

  const _CoverImageDisplay({this.base64String});

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (base64String != null && base64String!.isNotEmpty) {
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final screenWidth = MediaQuery.of(context).size.width;
      imageWidget = CachedImageFromBase64(
        base64String: base64String!,
        fit: BoxFit.contain,
        cacheWidth: (screenWidth * pixelRatio).round(),
        cacheHeight: (150 * pixelRatio).round(),
        errorBuilder: (ctx, err, st) => Icon(Icons.broken_image, size: 60, color: Colors.grey.shade400),
      );
    } else {
      imageWidget = Icon(Icons.image_outlined, size: 60, color: Colors.grey.shade400);
    }

    return Column(
      children: [
        Text('当前封面图片', style: Theme.of(context).textTheme.titleMedium),
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
}
