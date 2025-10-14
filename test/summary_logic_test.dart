import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:mengdie/app/providers/chat_state/mixins/background_tasks.dart';
import 'package:mengdie/domain/models/chat.dart';
import 'package:mengdie/domain/models/message.dart';
import 'package:mengdie/core/common_enums.dart';
import 'package:mengdie/app/providers/chat_state/special_action_type.dart';
import 'package:mengdie/domain/enums.dart';
import 'package:mengdie/data/llmapi/llm_service.dart';
import 'package:mengdie/data/llmapi/llm_models.dart';
import 'package:mengdie/app/providers/chat_state/chat_data_providers.dart';
import 'package:mengdie/app/providers/repository_providers.dart';
import 'package:mengdie/app/providers/chat_state/mixins/ui_state_manager.dart';
import 'package:mengdie/app/tools/context_xml_service.dart';
import 'package:mengdie/app/repositories/chat_repository.dart';
import 'package:mengdie/domain/models/api_config.dart';
import 'package:flutter/material.dart';
import 'package:mengdie/app/providers/chat_state/chat_screen_state.dart';
import 'package:mengdie/app/providers/chat_state_providers.dart';
import 'package:collection/collection.dart';
import 'package:mengdie/app/providers/settings_providers.dart';

import 'summary_logic_test.mocks.dart';
import 'package:mengdie/app/providers/chat_state/chat_state_notifier.dart';

@GenerateMocks([
  ProviderRef,
  LlmService,
  ChatRepository,
  ContextXmlService,
  ChatStateNotifier,
])
void main() {
  group('BackgroundTasks Summarization Logic', () {
    late MockProviderRef mockRef;
    late MockLlmService mockLlmService;
    late MockChatRepository mockChatRepository;
    late MockContextXmlService mockContextXmlService;
    late MockChatStateNotifier mockChatStateNotifier;
    late TestBackgroundTasksMixin testMixin;
    late Chat mockChat;
    late ApiConfig mockApiConfig;

    setUp(() {
      mockRef = MockProviderRef();
      mockLlmService = MockLlmService();
      mockChatRepository = MockChatRepository();
      mockContextXmlService = MockContextXmlService();
      mockChatStateNotifier = MockChatStateNotifier();

      mockChat = Chat(
        id: 1,
        title: 'Test Chat',
        systemPrompt: 'You are a helpful assistant.',
        preprocessingPrompt: 'Summarize the following conversation.',
        preprocessingApiConfigId: 'test_config',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      provideDummy<LlmService>(MockLlmService());
      provideDummy<ChatRepository>(MockChatRepository());
      provideDummy<ContextXmlService>(MockContextXmlService());
      provideDummy<AsyncValue<Chat?>>(AsyncValue.data(mockChat));
      provideDummy<ChatStateNotifier>(MockChatStateNotifier());

      mockApiConfig = ApiConfig(
        id: 'test_config',
        name: 'Test Config',
        baseUrl: 'http://localhost',
        apiKey: 'test_key',
        model: 'test_model',
        apiType: LlmType.gemini,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        maxOutputTokens: 1000,
      );

      when(mockRef.read(llmServiceProvider)).thenReturn(mockLlmService);
      when(mockRef.read(chatRepositoryProvider)).thenReturn(mockChatRepository);
      when(mockRef.read(contextXmlServiceProvider)).thenReturn(mockContextXmlService);
      when(mockRef.read(currentChatProvider(1))).thenReturn(AsyncValue.data(mockChat));
      when(mockRef.read(chatStateNotifierProvider(1).notifier)).thenReturn(mockChatStateNotifier);
      when(mockChatStateNotifier.getEffectiveApiConfig(specificConfigId: anyNamed('specificConfigId'))).thenReturn(mockApiConfig);
      when(mockRef.read(summaryRatioProvider)).thenReturn(0.7);

      testMixin = TestBackgroundTasksMixin(mockRef, 1);
    });

    test('triggers summarization with correct chunk content and order', () async {
      final List<Message> allMessages = List.generate(100, (i) {
        return Message(
          id: i + 1,
          chatId: 1,
          role: MessageRole.user,
          parts: [MessagePart.text('Message ${i + 1}')],
          timestamp: DateTime.now().add(Duration(minutes: i)),
        );
      });

      final messagesToDrop = allMessages.sublist(0, 80);
      final messagesToKeep = allMessages.sublist(80);
      
      when(mockContextXmlService.predictContextUsage(chatId: anyNamed('chatId')))
          .thenAnswer((_) async => ContextPredictionResult(
                willExceed: true,
                droppedMessages: messagesToDrop,
                keptMessages: messagesToKeep,
              ));

      when(mockContextXmlService.buildApiRequestContext(
        chatId: anyNamed('chatId'),
        currentUserMessage: anyNamed('currentUserMessage'),
        historyOverride: anyNamed('historyOverride'),
        chatSystemPromptOverride: anyNamed('chatSystemPromptOverride'),
      )).thenAnswer((invocation) async {
        final List<Message> history = invocation.namedArguments[#historyOverride] as List<Message>;
        final chunkSize = 20;
        if (history.isEmpty) {
          return ApiRequestContext(keptMessages: [], droppedMessages: [], contextParts: []);
        }
        // Corrected logic: buildApiRequestContext keeps the NEWEST messages
        if (history.length <= chunkSize) {
          return ApiRequestContext(keptMessages: history, droppedMessages: [], contextParts: []);
        } else {
          return ApiRequestContext(
            keptMessages: history.sublist(history.length - chunkSize),
            droppedMessages: history.sublist(0, history.length - chunkSize),
            contextParts: [],
          );
        }
      });

      when(mockLlmService.sendMessageOnce(
        llmContext: anyNamed('llmContext'),
        apiConfig: anyNamed('apiConfig'),
      )).thenAnswer((invocation) async {
        final List<LlmContent> llmContext = invocation.namedArguments[#llmContext] as List<LlmContent>;
        
        debugPrint("--- START LLM Context for Summarization Request ---");
        String chunkIdentifier = "Unknown Chunk";
        List<int> messageIdsInChunk = [];
        List<String> fullContextContent = []; // 用于收集完整的上下文内容

        for (final content in llmContext) {
          String roleInfo = "Role: ${content.role}";
          if (content.messageId != null) {
            roleInfo += ", MessageId: ${content.messageId}";
          }
          fullContextContent.add(roleInfo);

          for (final part in content.parts) {
            if (part is LlmTextPart) {
              fullContextContent.add("  Text Part: ${part.text}");
            } else if (part is LlmDataPart) {
              fullContextContent.add("  Data Part: ${part.mimeType}");
            }
          }
        }
        String chunkContextString = fullContextContent.join('\n');
        debugPrint("--- END LLM Context for this chunk ---");

        // 将完整的上下文内容作为“总结”返回
        return LlmResponse(
          isSuccess: true,
          parts: [MessagePart.text(chunkContextString)],
        );
      });

      await testMixin.executePreprocessing(mockChat);

      final captured = verify(mockChatRepository.saveChat(captureAny)).captured;
      expect(captured.length, 1);
      
      final savedChat = captured.first as Chat;
      final summary = savedChat.contextSummary;

      debugPrint("--- Final Saved Summary Content (Full Context) ---");
      debugPrint(summary);
      debugPrint("--------------------------------------------------");

      // 验证 lastSummarizedMessageId
      expect(savedChat.lastSummarizedMessageId, 86);

      // 由于最终总结内容会非常长且动态，我们不再进行精确的 equals 比较
      // 而是检查它是否包含每个块的预期起始消息，并验证整体结构
      final expectedChunkStarts = [
        'Role: user, MessageId: 1\n  Text Part: Message 1',
        'Role: user, MessageId: 7\n  Text Part: Message 7',
        'Role: user, MessageId: 27\n  Text Part: Message 27',
        'Role: user, MessageId: 47\n  Text Part: Message 47',
        'Role: user, MessageId: 67\n  Text Part: Message 67',
      ];

      for (final start in expectedChunkStarts) {
        expect(summary, contains(start));
      }

      // 验证分隔符是否存在且数量正确
      final separators = summary!.split('\n\n---\n\n'); // 添加空安全断言
      expect(separators.length, 5); // 5个块，4个分隔符
    });
  });
}

class TestBackgroundTasksMixin extends StateNotifier<ChatScreenState> with UiStateManager, BackgroundTasks {
  @override
  Future<Chat?> executePreprocessing(Chat chat) {
    return super.executePreprocessing(chat);
  }

  @override
  final Ref ref;
  @override
  final int chatId;

  TestBackgroundTasksMixin(this.ref, this.chatId) : super(const ChatScreenState());

  @override
  bool get mounted => true;

  @override
  void showTopMessage(String message, {Duration duration = const Duration(seconds: 3), Color? backgroundColor}) {}

  @override
  void stopUpdateTimer() {}

  @override
  Future<void> updateContextDebugInfo() async {}

  @override
  Future<void> generateHelpMeReply({Function(List<String>)? onSuggestionsReady, bool forceRefresh = false}) async {}

  @override
  Future<String> executeSpecialAction({
    required String prompt,
    required ApiConfig apiConfig,
    required SpecialActionType actionType,
    required Message targetMessage,
  }) async {
    return "Special action result";
  }

  @override
  ApiConfig getEffectiveApiConfig({String? specificConfigId}) {
    return ApiConfig(
      id: specificConfigId ?? 'default_config',
      name: 'Mock API Config',
      baseUrl: 'http://mockapi.com',
      apiKey: 'mock_key',
      model: 'mock_model',
      apiType: LlmType.gemini,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      maxOutputTokens: 1000,
    );
  }

  Future<String> callSummarizeMessages(List<Message> messages, String? existingSummary, {List<Message>? followingMessages}) {
    return super.summarizeMessages(messages, existingSummary, followingMessages: followingMessages);
  }
}