import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../../../domain/models/chat.dart';
import '../../../domain/models/message.dart';
import '../../../domain/enums.dart';
import '../repository_providers.dart';
import '../auth_providers.dart';
import '../../repositories/message_repository.dart';

// --- 当前激活的聊天 ID Provider ---
// 这个 Provider 允许我们拥有一个单一的 ChatScreen 实例，
// 该实例根据此状态更新其内容，而不是为每个聊天推送新的路由。
final activeChatIdProvider = StateProvider<int?>((ref) => null);

// --- 当前文件夹 ID Provider ---
final currentFolderIdProvider = StateProvider<int?>((ref) => null);

// --- 用于 chatListProvider 的参数 ---
// 使用 Record 类型来传递多个参数
typedef ChatListProviderParams = ({int? parentFolderId, ChatListMode mode});

// --- 聊天列表 Provider (Stream Family) ---
final chatListProvider =
    StreamProvider.family<List<Chat>, ChatListProviderParams>((ref, params) {
      try {
        final repo = ref.watch(chatRepositoryProvider);
        final authState = ref.watch(authProvider);

        // 最终修复：不再区分游客和普通用户，统一调用 watchChatsForUser。
        // watchChatsForUser 方法内部已经包含了处理游客和“孤儿”聊天的逻辑。
        if (authState.currentUser == null) {
          // 如果在认证完成前（例如启动时），返回一个空流。
          return Stream.value([]);
        }

        final sourceStream = repo.watchChatsForUser(
          authState.currentUser!.id,
          params.parentFolderId,
        );

        // 根据模式和新的 isTemplate 逻辑过滤数据流
        return sourceStream.map((chats) {
          switch (params.mode) {
            case ChatListMode.normal:
              // 普通模式：只显示非模板项目
              return chats.where((chat) => !chat.isTemplate).toList();
            case ChatListMode.templateSelection:
            case ChatListMode.templateManagement:
              // 模板模式：只显示模板项目
              return chats.where((chat) => chat.isTemplate).toList();
          }
        });
      } catch (e) {
        return Stream.error(e);
      }
    });

// --- 当前聊天 Provider (Stream for specific chat) ---
final currentChatProvider = StreamProvider.family<Chat?, int>((ref, chatId) {
  try {
    final repo = ref.watch(chatRepositoryProvider);
    return repo.watchChat(chatId);
  } catch (e) {
    return Stream.error(e);
  }
});

// --- 聊天消息 Provider (Stream for specific chat's messages) ---
final chatMessagesProvider = StreamProvider.family<List<Message>, int>((
  ref,
  chatId,
) {
  try {
    final repo = ref.watch(messageRepositoryProvider);
    return repo.watchMessagesForChat(chatId);
  } catch (e) {
    return Stream.error(e);
  }
});

// --- 新增：第一条模型消息 Provider (用于列表预览) ---
// 优化：从 StreamProvider 改为 FutureProvider，避免为每个列表项建立实时监听。
// 这将显著降低应用启动时的数据库负载。
final firstModelMessageProvider = FutureProvider.family<Message?, int>((
  ref,
  chatId,
) {
  // 直接调用 repository 的一次性查询方法
  return ref.watch(messageRepositoryProvider).getFirstModelMessage(chatId);
});

// --- 新增：用于生成计时的独立 Provider ---
// 优化：将高频更新的计时器状态从主 Notifier 中分离，
// 避免监听主 Notifier 的大型组件每秒都进行不必要的重建。
final generationElapsedSecondsProvider = StateProvider<int>((ref) => 0);
