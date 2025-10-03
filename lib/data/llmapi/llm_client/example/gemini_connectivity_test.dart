// lib/example/gemini_connectivity_test.dart
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:args/args.dart';
import 'package:collection/collection.dart';
import '../src/llm_client.dart';

import '../src/gemini/gemini.dart' as gemini;

// --- 有效的虚拟文件常量 ---

// 一个小的、有效的、透明的 1x1 像素 PNG 图片
const String base64DummyImage =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

// 一个小的、有效的、单页的 PDF 文件 (内容为 "Hello")
const String base64DummyPdf =
    'JVBERi0xLjQKJdPr6eEKMSAwIG9iago8PC9DcmVhdG9yIChEb2N1UmVzaW5lKSAvUHJvZHVjZXIgKERvY3VSZXNpbmUpID4+CmVuZG9iagoyIDAgb2JqCjw8L1R5cGUgL0NhdGFsb2cgL1BhZ2VzIDMgMCBSID4+CmVuZG9iagozIDAgb2JqCjw8L1R5cGUgL1BhZ2VzIC9LaWRzIFs0IDAgUiBdIC9Db3VudCAxID4+CmVuZG9iago0IDAgb2JqCjw8L1R5cGUgL1BhZ2UgL1BhcmVudCAzIDAgUiAvUmVzb3VyY2VzIDw8L0ZvbnQgPDwvRjEgOCAwIFIgPj4gPj4gL01lZGlhQm94IFswIDAgNTk1IDg0Ml0gL0NvbnRlbnRzIDcgMCBSID4+CmVuZG9iago1IDAgb2JqCjw8L0xlbmd0aCAxNiAvRmlsdGVyIC9GbGF0ZURlY29kZSA+PgpzdHJlYW0KeJwrZGrh4i0tzkxPBgAI/gItCmVuZHN0cmVhbQplbmRvYmoKNiAwIG9iago8PC9UeXBlIC9Gb250RGVzY3JpcHRvciAvRm9udE5hbWUgL0hlbHZldGljYSAvRmxhZ3MgMzIgL0ZvbnRCQm94IFstMTM5IC0zNTIgMTAwMCA5NDVdIC9Bc2NlbnQgNzE4IC9EZXNjZW50IC0yMDcgL0NhcGhlaWdodCA3MTggL1N0ZW1WIDgwID4+CmVuZG9iago3IDAgb2JqCjw8L0xlbmd0aCA1OSAvRmlsdGVyIC9GbGF0ZURlY29kZSA+PgpzdHJlYW0KeJwzNDKy1FHwzEstykxXyE7PzEnVS84vLdFRcEksS0FN0VNUMDAwAFEMFBIVMjYyMjAwAhVAgsqh6gEASc4S8AplbmRzdHJlYW0KZW5kb2JqCjggMCBvYmoKPDwvVHlwZSAvRm9udCAvU3VidHlwZSAvVHlwZTEgL0Jhc2VGb250IC9IZWx2ZXRpY2EgL0VuY29kaW5nIC9XaW5BbnNpRW5jb2RpbmcgL0ZvbnREZXNjcmlwdG9yIDYgMCBSID4+CmVuZG9iagp4cmVmCjAgOQowMDAwMDAwMDAwIDY1NTM1IGYgCjAwMDAwMDAwMTggMDAwMDAgbiAKMDAwMDAwMDA4MyAwMDAwMCBuIAowMDAwMDAwMTMwIDAwMDAwIG4gCjAwMDAwMDAxODcgMDAwMDAgbiAKMDAwMDAwMDMwMiAwMDAwMCBuIAowMDAwMDAwNDcyIDAwMDAwIG4gCjAwMDAwMDA1NjcgMDAwMDAgbiAKMDAwMDAwMDY4MiAwMDAwMCBuIAp0cmFpbGVyCjw8L1NpemUgOSAvUm9vdCAyIDAgUiAvSW5mbyAxIDAgUiA+PgpzdGFydHhyZWYKNzgzCiUlRU9GCg==';

/// Gemini API 综合测试的主入口点。
///
/// 此脚本验证 Gemini 提供程序的统一 LLM API 的全部功能。
/// 它需要通过命令行参数提供 API 密钥。
Future<void> main(List<String> args) async {
  // 1. [已修改] 设置和解析命令行参数
  final parser = ArgParser()
    ..addOption('api-key',
        abbr: 'k', help: '必需：您的 Gemini API 密钥。', mandatory: true)
    ..addOption('gemini-base-url',
        abbr: 'u', help: '可选：自定义 Gemini API 的基础 URL。')
    ..addFlag('enable-veo',
        abbr: 'v',
        help: '启用 Veo 视频生成测试（需要一个已启用结算的账户）。',
        defaultsTo: false)
    ..addFlag('enable-imagen',
        abbr: 'i',
        help: '启用 Imagen 图片生成测试（需要一个已启用结算的账户）。',
        defaultsTo: false)
    ..addMultiOption('test-name',
        abbr: 't', help: '要运行的一个或多个测试的名称。如果未提供，则运行所有测试。')
    ..addFlag('enable-tuning',
        help: '启用 Tuning 服务测试（创建和删除调优模型）。', defaultsTo: false);

  late ArgResults argResults;
  try {
    argResults = parser.parse(args);
  } on FormatException catch (e) {
    debugPrint('参数错误: ${e.message}');
    debugPrint('\n用法:\n${parser.usage}');
    exit(1);
  }

  final apiKey = argResults['api-key'] as String;
  final geminiBaseUrl = argResults['gemini-base-url'] as String?;
  final enableVeoTest = argResults['enable-veo'] as bool;
  final enableImagenTest = argResults['enable-imagen'] as bool;
  final enableTuningTest = argResults['enable-tuning'] as bool;
  final testNames = argResults['test-name'] as List<String>;

  // 3. 运行所有连通性测试。
  await runAllTests(
      apiKey: apiKey,
      baseUrl: geminiBaseUrl,
      enableVeoTest: enableVeoTest,
      enableImagenTest: enableImagenTest,
      enableTuningTest: enableTuningTest,
      testNames: testNames);
}

/// 测试检索 (Corpora/Documents/Chunks) 和调优服务的 CRUDQ 功能。
/// 注意：这是一个集成测试，会真实地创建和删除后端资源。
Future<void> testRetrievalAndTuningServices(LlmClient llm) async {
  debugPrint('运行测试: 检索与调优服务...');

  String? corpusName;
  String? tunedModelName;

  try {
    // --- 1. Corpora Service ---
    debugPrint('\n--- 测试 CorporaService ---');
    final corpusDisplayName = 'temp-corpus-${DateTime.now().millisecondsSinceEpoch}';
    final createdCorpus = await llm.corpora.create(gemini.Corpus(displayName: corpusDisplayName));
    corpusName = createdCorpus.name;
    debugPrint('成功: 已创建 Corpus: $corpusName');
    assert(createdCorpus.displayName == corpusDisplayName);

    final gotCorpus = await llm.corpora.get(corpusName!);
    debugPrint('成功: 已获取 Corpus: ${gotCorpus.name}');
    assert(gotCorpus.name == corpusName);
    assert(gotCorpus.displayName == corpusDisplayName,
        '获取的 Corpus displayName 与创建时不符。');

    final corporaList = await llm.corpora.list();
    debugPrint('成功: 已列出 ${corporaList.items.length} 个 Corpora。');
    assert(corporaList.items.any((c) => c.name == corpusName));

    final updatedCorpus = await llm.corpora.patch(corpusName, gemini.Corpus(displayName: 'updated-name'), updateMask: ['displayName']);
    debugPrint('成功: 已更新 Corpus: ${updatedCorpus.name}');
    assert(updatedCorpus.displayName == 'updated-name');
    
    // --- 2. Document & Chunk Services ---
    debugPrint('\n--- 测试 Document & Chunk Services ---');
    final documentDisplayName = 'temp-doc-${DateTime.now().millisecondsSinceEpoch}';
    final createdDocument = await llm.documents.create(parent: corpusName, document: gemini.Document(displayName: documentDisplayName));
    final documentName = createdDocument.name;
    debugPrint('成功: 已在 Corpus $corpusName 中创建 Document: $documentName');
    assert(createdDocument.displayName == documentDisplayName);

    final gotDocument = await llm.documents.get(documentName!);
    debugPrint('成功: 已获取 Document: ${gotDocument.name}');
    assert(gotDocument.displayName == documentDisplayName,
        '获取的 Document displayName 与创建时不符。');
    final documentsList = await llm.documents.list(corpusName);
    debugPrint('成功: 已列出 ${documentsList.items.length} 个 Documents。');
    assert(documentsList.items.any((d) => d.name == documentName));

    final chunkData = '这是一个用于测试的文本块。';
    final createdChunk = await llm.chunks.create(parent: documentName, chunk: gemini.Chunk(data: gemini.ChunkData(stringValue: chunkData)));
    final chunkName = createdChunk.name;
    debugPrint('成功: 已在 Document $documentName 中创建 Chunk: $chunkName');

    final gotChunk = await llm.chunks.get(chunkName!);
    debugPrint('成功: 已获取 Chunk: ${gotChunk.name}');
    assert(gotChunk.data?.stringValue == chunkData, '获取的 Chunk 数据与创建时不符。');
    final chunksList = await llm.chunks.list(documentName);
    debugPrint('成功: 已列出 ${chunksList.items.length} 个 Chunks。');
    assert(chunksList.items.any((c) => c.name == chunkName));
    
    // 等待索引
    await Future.delayed(const Duration(seconds: 5));

    final queryResult = await llm.corpora.query(corpusName, query: '测试块');
    debugPrint('成功: 查询 Corpus 返回 ${queryResult.length} 个结果。');
    assert(queryResult.isNotEmpty);
    assert(queryResult.first.chunk?.name == chunkName);


    // --- 3. Tuning Service ---
    debugPrint('\n--- 测试 TuningService ---');
    final tuningTask = gemini.TuningTask(
      trainingData: gemini.Dataset(
        examples: gemini.TuningExamples(examples: [
          gemini.TuningExample(textInput: '你好', output: '你好！有什么可以帮忙的吗？'),
          gemini.TuningExample(textInput: '再见', output: '再见！祝你有美好的一天！'),
          gemini.TuningExample(textInput: '你好吗？', output: '我很好，谢谢关心。'),
          gemini.TuningExample(textInput: '谢谢', output: '不客气。'),
          gemini.TuningExample(textInput: '今天天气怎么样？', output: '今天天气晴朗，适合出门。'),
          gemini.TuningExample(textInput: '你叫什么名字？', output: '我是Gemini AI。'),
          gemini.TuningExample(textInput: '你来自哪里？', output: '我来自一个充满代码的世界。'),
          gemini.TuningExample(textInput: '你会做什么？', output: '我可以回答问题、生成文本、提供建议等。'),
          gemini.TuningExample(textInput: '帮我写一首诗', output: '好的，关于什么主题呢？'),
          gemini.TuningExample(textInput: '讲个笑话吧', output: '从前有座山，山里有座庙...'),
          gemini.TuningExample(textInput: '明天会下雨吗？', output: '我无法预测天气，但你可以查看天气预报。'),
          gemini.TuningExample(textInput: '我爱你', output: '谢谢你的好意。'),
          gemini.TuningExample(textInput: '推荐一本书', output: '《三体》是一本很棒的科幻小说。'),
          gemini.TuningExample(textInput: '推荐一部电影', output: '《星际穿越》值得一看。'),
          gemini.TuningExample(textInput: '最近有什么新闻？', output: '你可以通过新闻应用了解最新动态。'),
          gemini.TuningExample(textInput: '如何学习编程？', output: '从基础开始，多写代码，多做项目。'),
          gemini.TuningExample(textInput: '什么是人工智能？', output: '人工智能是研究、开发用于模拟、延伸和扩展人的智能的理论、方法、技术及应用系统的一门新的技术科学。'),
          gemini.TuningExample(textInput: '生命的意义是什么？', output: '这是一个深刻的哲学问题，不同的人有不同的答案。'),
          gemini.TuningExample(textInput: '你最喜欢的颜色是什么？', output: '我喜欢数字世界的蓝色。'),
          gemini.TuningExample(textInput: '晚安', output: '晚安，祝你做个好梦。'),
        ]),
      ),
    );
    
    // 由于调优是一个长时间运行的操作，我们只测试创建请求。
    // 完整的测试需要轮询操作状态。
    final createdTunedModel = await llm.tunedModels.create(
      tunedModel: gemini.TunedModel(
        baseModel: 'models/gemini-1.5-flash-001',
        tuningTask: tuningTask,
      ),
    );
    debugPrint('成功: 已创建调优模型: ${createdTunedModel.name}');
    tunedModelName = createdTunedModel.name;


  } catch (e) {
    debugPrint('失败: 在检索或调优服务测试期间发生错误: $e');
  } finally {
    // --- 清理 ---
    if (corpusName != null) {
      debugPrint('清理资源: 正在删除 Corpus $corpusName...');
      await llm.corpora.delete(corpusName, force: true);
      debugPrint('成功: 已清理 Corpus: $corpusName');
    }
    // 在实际场景中，我们可能需要取消或删除调优操作/模型
    if (tunedModelName != null && tunedModelName.isNotEmpty) {
       debugPrint('清理资源: 正在删除调优模型 $tunedModelName...');
       await llm.tunedModels.delete(tunedModelName);
       debugPrint('成功: 已清理调优模型: $tunedModelName');
    }
  }
}

/// 按顺序运行所有 Gemini API 测试。
///
/// [apiKey] 你的 Gemini API 密钥。
/// [baseUrl] 可选的自定义 Gemini API 基础 URL。
/// [enableVeoTest] 一个布尔值，用于决定是否运行需要付费的 Veo 测试。
/// [testNames] 要运行的单个测试的名称列表。
Future<void> runAllTests(
    {required String apiKey,
    String? baseUrl,
    required bool enableVeoTest,
    required bool enableImagenTest,
    required bool enableTuningTest,
    List<String> testNames = const []}) async {
  // 其他测试仍然需要一个 LlmClient 实例。
  final llm =
      LlmClient(provider: LlmProvider.gemini, apiKey: apiKey, baseUrl: baseUrl);

  final tests = <String, Future<void> Function(LlmClient)>{
    // === 核心能力 ===
    '文本生成 (简单)': testGenerateContent,
    '文本生成 (流式)': testGenerateContentStream,
    '对话会话': testChatSession,
    '系统指令与高级配置': testSystemInstructionsAndConfig,
    '词元计数': testTokenCounting,
    // === 多模态理解 ===
    '多模态 (图片描述)': testMultimodalImageDescription,
    '多模态 (对象检测)': testMultimodalObjectDetection,
    '多模态 (视频理解)': testMultimodalVideoUnderstanding,
    '多模态 (PDF 理解)': testMultimodalPdfUnderstanding,
    // === 多模态生成 ===
    '图片生成 (Gemini)': testImageGeneration,
    '音频链 (TTS -> 理解)': testAudioChain,
    '音乐生成 (Lyria)': testMusicApiConnection,
    // === 高级功能与工具 ===
    '函数调用 (完整周期)': testFullFunctionCallingCycle,
    '代码执行': testCodeExecution,
    'Google 搜索建立依据': testGroundingWithSearch,
    'URL 上下文': testUrlContext,
    'Gemini 思考': testGeminiThinking,
    // === 交互模式 ===
    '批处理模式': testBatchMode,
    'Live API (连接)': testLiveApiConnection,
    'Live API (认证令牌)': testCreateAuthToken,
    // === 支撑性 API ===
    '文件服务': testFileService,
    '嵌入 (Embeddings)': testEmbeddings,
    '模型服务 (列出模型)': testModelService,
    '问答 (QA)': testGenerateAnswer,
    '检索与调优服务': (llm) async {
      if (enableTuningTest) {
        await testRetrievalAndTuningServices(llm);
      } else {
        debugPrint('[跳过] Tuning 服务测试。使用 --enable-tuning 标志来运行它。');
      }
    },
  };

  // [已修改] 根据命令行参数条件性地添加 Veo 测试
  if (enableVeoTest) {
    tests['视频生成 (Veo)'] = testVideoGeneration;
  } else {
    // 只有在没有运行单个特定测试时才打印跳过消息
    if (testNames.isEmpty) {
      debugPrint('[跳过] 视频生成 (Veo) 测试。使用 --enable-veo 标志来运行它。');
    }
  }

  // [新增] 根据命令行参数条件性地添加 Imagen 测试
  if (enableImagenTest) {
    tests['图片生成 (Imagen)'] = testImagenGeneration;
  } else {
    // 只有在没有运行单个特定测试时才打印跳过消息
    if (testNames.isEmpty) {
      debugPrint('[跳过] 图片生成 (Imagen) 测试。使用 --enable-imagen 标志来运行它。');
    }
  }

  if (testNames.isNotEmpty) {
    // 运行指定的测试
    final notFound = <String>[];
    for (final testName in testNames) {
      final testToRun = tests[testName];
      if (testToRun != null) {
        debugPrint('=' * 20);
        debugPrint('正在运行指定测试: $testName');
        debugPrint('=' * 20);
        try {
          await testToRun(llm);
        } catch (e) {
          debugPrint('!!! 测试 "$testName" 期间发生未捕获的异常: $e');
        }
        debugPrint('-' * 60);
        await Future.delayed(const Duration(seconds: 1)); // 速率限制
      } else {
        notFound.add(testName);
      }
    }
    if (notFound.isNotEmpty) {
      debugPrint('错误: 未找到以下测试: ${notFound.join(', ')}');
      debugPrint('可用测试:');
      for (final key in tests.keys) {
        debugPrint(' - $key');
      }
      exit(1);
    }
  } else {
    // 运行所有测试
    for (final entry in tests.entries) {
      debugPrint('=' * 20);
      debugPrint('正在运行测试: ${entry.key}');
      debugPrint('=' * 20);
      try {
        await entry.value(llm);
      } catch (e) {
        debugPrint('!!! 测试 "${entry.key}" 期间发生未捕获的异常: $e');
      }
      debugPrint('-' * 60);
      await Future.delayed(const Duration(seconds: 5)); // 简单的速率限制
    }
  }
}

// =============================================================================
// I. 核心能力测试
// =============================================================================

/// 测试基本的文本生成功能。
Future<void> testGenerateContent(LlmClient llm) async {
  debugPrint('运行测试: 简单文本生成...');
  try {
    final request = gemini.GenerateContentRequest(
        contents: [gemini.Content.text('Hello, world!')]);
    final response = await llm.generateContent('gemini-2.5-flash', request);
    debugPrint('成功: ${response.text}');
    assert(response.text?.isNotEmpty ?? false);
  } catch (e) {
    debugPrint('失败: $e');
  }
}

/// 测试流式文本生成功能。
Future<void> testGenerateContentStream(LlmClient llm) async {
  debugPrint('运行测试: 流式文本生成...');
  try {
    final request = gemini.GenerateContentRequest(
        contents: [gemini.Content.text('给我讲一个短故事。')]);
    final stream = llm.streamGenerateContent('gemini-2.5-flash', request);
    await for (final chunk in stream) {
      stdout.write(chunk.text);
    }
    debugPrint('\n成功: 流已完成。');
  } catch (e) {
    debugPrint('\n失败: $e');
  }
}

/// 测试对话会话功能。
Future<void> testChatSession(LlmClient llm) async {
  debugPrint('运行测试: 基本对话会话...');
  try {
    final chat = llm.chats.startChat(model: 'gemini-2.5-flash');

    final firstResponse =
        await chat.sendMessage(gemini.Content.text('你好，我叫 Alex。'));
    debugPrint('模型: ${firstResponse.text}');

    final secondResponse =
        await chat.sendMessage(gemini.Content.text('我叫什么名字？'));
    debugPrint('模型: ${secondResponse.text}');
    assert(secondResponse.text?.toLowerCase().contains('alex') ?? false);
    debugPrint('成功: 模型从聊天历史中记住了名字。');
  } catch (e) {
    debugPrint('失败: $e');
  }
}

/// 测试使用系统指令和高级生成配置。
Future<void> testSystemInstructionsAndConfig(LlmClient llm) async {
  debugPrint('运行测试: 系统指令和高级配置...');
  try {
    final request = gemini.GenerateContentRequest(
      contents: [gemini.Content.text('电脑是怎么工作的？')],
      systemInstruction: gemini.SystemInstruction(
          gemini.TextPart('你是一个海盗。你所有的回答都必须用海盗黑话。')),
      generationConfig: const gemini.GenerationConfig(
        temperature: 0.2,
        maxOutputTokens: 10000,
      ),
    );
    final response = await llm.generateContent('gemini-2.5-flash', request);
    debugPrint('成功: ${response.text}');
    final text = response.text?.toLowerCase() ?? '';
    if (text.isNotEmpty) {
      final pirateWords = ['ahoy', 'matey', 'arrr', 'shiver me timbers', '伙计'];
      assert(pirateWords.any((word) => text.contains(word)),
          '响应不包含预期的海盗术语。响应: "$text"');
    } else {
      debugPrint('警告: 模型返回了空响应，可能是由于安全策略。但API调用成功。');
    }
  } catch (e) {
    debugPrint('失败: $e');
  }
}

/// 测试词元计数功能。
Future<void> testTokenCounting(LlmClient llm) async {
  debugPrint('运行测试: 词元计数...');
  try {
    // 1. 计算简单文本
    final textResponse = await llm.countTokens(
        'gemini-2.5-flash',
        gemini.GenerateContentRequest(contents: [
          gemini.Content.text('The quick brown fox jumps over the lazy dog.')
        ]));
    final textTokens = textResponse.totalTokens;
    debugPrint('成功: 简单文本有 $textTokens 个词元。');
    assert(textTokens > 0);

    // 2. 计算多模态内容
    final imageBytes = base64Decode(base64DummyImage);
    final multimodalResponse = await llm.countTokens(
        'gemini-2.5-flash',
        gemini.GenerateContentRequest(contents: [
          gemini.Content.multi([
            gemini.TextPart('描述这张图片:'),
            gemini.DataPart('image/png', imageBytes),
          ])
        ]));
    final multimodalTokens = multimodalResponse.totalTokens;
    debugPrint('成功: 多模态内容有 $multimodalTokens 个词元。');
    assert(multimodalTokens > textTokens);
  } catch (e) {
    debugPrint('失败: $e');
  }
}

// =============================================================================
// II. 多模态理解测试
// =============================================================================

/// 测试多模态图片描述。
Future<void> testMultimodalImageDescription(LlmClient llm) async {
  debugPrint('运行测试: 多模态图片描述...');
  try {
    final imageBytes = base64Decode(base64DummyImage);
    final request = gemini.GenerateContentRequest(contents: [
      gemini.Content.multi([
        gemini.TextPart('这张图片里有什么？'),
        gemini.DataPart('image/png', imageBytes)
      ])
    ]);
    final response = await llm.generateContent('gemini-2.5-flash', request);
    debugPrint('成功: ${response.text}');
    assert(response.text?.isNotEmpty ?? false);
  } catch (e) {
    debugPrint('失败: $e');
  }
}

/// 测试带有 JSON 输出的多模态对象检测。
Future<void> testMultimodalObjectDetection(LlmClient llm) async {
  debugPrint('运行测试: 多模态对象检测...');
  try {
    final imageBytes = base64Decode(base64DummyImage);
    final message = gemini.Content.multi([
      gemini.TextPart(
          '检测所有显著物体。box_2d 应该是 [ymin, xmin, ymax, xmax] 格式，并归一化到 0-1000。'),
      gemini.DataPart('image/png', imageBytes),
    ]);
    final request = gemini.GenerateContentRequest(
      contents: [message],
      generationConfig: const gemini.GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );
    final response = await llm.generateContent('gemini-2.5-pro', request);
    // 尝试将响应解析为 JSON 以进行验证。
    jsonDecode(response.text!);
    debugPrint('成功: 收到有效的对象检测 JSON 响应。');
    debugPrint('响应: ${response.text}');
  } catch (e) {
    debugPrint('失败: $e');
  }
}

/// 使用 YouTube URL 测试视频理解。
Future<void> testMultimodalVideoUnderstanding(LlmClient llm) async {
  debugPrint('运行测试: 多模态视频理解 (YouTube)...');
  try {
    final message = gemini.Content.multi([
      gemini.TextPart('用一句话总结这个视频。'),
      gemini.FileDataPart(
          'video/mp4', 'https://www.youtube.com/watch?v=9hE5-98ZeCg') // Google I/O 2024
    ]);
    final request = gemini.GenerateContentRequest(contents: [message]);
    final response = await llm.generateContent('gemini-2.5-flash', request);
    debugPrint('成功: ${response.text}');
    assert(response.text?.isNotEmpty ?? false);
  } catch (e) {
    debugPrint('失败: $e');
  }
}

/// 测试音频生成和理解的链式调用。
Future<void> testAudioChain(LlmClient llm) async {
  debugPrint('运行测试: 音频链 (TTS -> 理解)...');
  Uint8List? generatedAudioData;
  gemini.File? uploadedFile;

  try {
    // 1. 语音生成 (TTS)
    debugPrint('步骤 1: 正在生成语音...');
    final speechConfig = gemini.SpeechConfig(
      voiceConfig: gemini.VoiceConfig(
        prebuiltVoiceConfig: gemini.PrebuiltVoiceConfig(voiceName: 'Puck'),
      ),
    );
    final genConfig = gemini.GenerationConfig(
        speechConfig: speechConfig, responseModalities: ["AUDIO"]);
    final ttsRequest = gemini.GenerateContentRequest(
      contents: [gemini.Content.text('Hello from the Gemini API!')],
      generationConfig: genConfig,
    );
    final ttsResponse =
        await llm.generateContent('gemini-2.5-flash-preview-tts', ttsRequest);

    final audioPart = ttsResponse.candidates.first.content.parts
        .whereType<gemini.DataPart>()
        .firstOrNull;

    if (audioPart != null && audioPart.mimeType.startsWith('audio/')) {
      debugPrint('成功: 语音生成完成并返回了 ${audioPart.mimeType} 数据。');
      assert(audioPart.bytes.isNotEmpty);
      generatedAudioData = audioPart.bytes;
    } else {
      debugPrint('失败: 未返回音频数据。响应文本: ${ttsResponse.text}');
      assert(false, '未在响应中找到音频数据。');
      return; // 如果 TTS 失败则停止
    }

    // 2. 音频理解
    debugPrint('\n步骤 2: 正在理解生成的音频...');
    debugPrint('正在上传由 TTS 生成的音频文件...');
    uploadedFile = await llm.files.upload(generatedAudioData, 'audio/mp3');
    debugPrint('成功: 音频文件已上传。URI: ${uploadedFile.uri}');

    await Future.delayed(const Duration(seconds: 3)); // 等待文件处理

    final message = gemini.Content.multi([
      gemini.TextPart('转录此音频文件。'),
      gemini.FileDataPart('audio/mp3', uploadedFile.uri)
    ]);
    final request = gemini.GenerateContentRequest(contents: [message]);
    final response = await llm.generateContent('gemini-2.5-flash', request);
    debugPrint('成功: 转录响应: ${response.text}');
  } on gemini.GeminiApiException catch (e) {
    if (e.toString().contains('500')) {
      debugPrint('警告: 收到 500 内部服务器错误，这可能是暂时的后端问题。跳过此测试。');
    } else {
      debugPrint('失败: $e');
    }
  } catch (e) {
    debugPrint('失败: $e');
  } finally {
    if (uploadedFile != null) {
      await llm.files.delete(uploadedFile.name.split('/').last);
      debugPrint('成功: 已清理上传的音频文件。');
    }
  }
}

/// 通过上传文件并请求摘要来测试 PDF 文档理解。
Future<void> testMultimodalPdfUnderstanding(LlmClient llm) async {
  debugPrint('运行测试: 多模态 PDF 理解...');
  gemini.File? uploadedFile;
  try {
    final pdfBytes = base64Decode(base64DummyPdf);
    debugPrint('正在上传虚拟 PDF 文件...');
    uploadedFile = await llm.files.upload(pdfBytes, 'application/pdf');
    debugPrint('成功: PDF 文件已上传。URI: ${uploadedFile.uri}');

    await Future.delayed(const Duration(seconds: 3));

    final message = gemini.Content.multi([
      gemini.TextPart('用一个词总结这个文档。'),
      gemini.FileDataPart('application/pdf', uploadedFile.uri)
    ]);
    final request = gemini.GenerateContentRequest(contents: [message]);
    final response = await llm.generateContent('gemini-2.5-flash', request);
    debugPrint('成功: PDF 摘要响应: ${response.text}');
    assert(response.text != null, 'PDF 理解测试应返回非空的文本响应。');
  } catch (e) {
    debugPrint('失败: $e');
  } finally {
    if (uploadedFile != null) {
      await llm.files.delete(uploadedFile.name.split('/').last);
      debugPrint('成功: 已清理虚拟 PDF 文件。');
    }
  }
}

// =============================================================================
// III. 多模态生成测试
// =============================================================================

/// 测试图片生成功能。
Future<void> testImageGeneration(LlmClient llm) async {
  debugPrint('运行测试: 图片生成 (Gemini)...');
  try {
    final request = gemini.GenerateContentRequest(
      contents: [gemini.Content.text('A beautiful sunset over the ocean.')],
      generationConfig:
          const gemini.GenerationConfig(responseModalities: ["TEXT", "IMAGE"]),
    );
    final response = await llm.generateContent(
        'gemini-2.0-flash-exp-image-generation', request);

    final imagePart = response.candidates.firstOrNull?.content.parts
        .whereType<gemini.DataPart>()
        .firstWhereOrNull((p) => p.mimeType.startsWith('image/'));

    if (imagePart != null) {
      debugPrint('成功: 图片生成请求完成，并返回了 ${imagePart.mimeType} 数据。');
      assert(imagePart.bytes.isNotEmpty, '返回的图片数据不应为空。');
    } else if (response.text != null && response.text!.isNotEmpty) {
      debugPrint('警告: 图片生成请求完成，但只返回了文本响应: ${response.text}');
      // 这是一个非预期的成功，因为我们请求了图片。可以添加一个软断言或警告。
    } else {
      debugPrint('失败: 图片生成请求未返回文本或图片数据。');
      assert(false, '图片生成响应为空。');
    }
  } catch (e) {
    debugPrint('失败: $e');
  }
}


/// 测试使用 Imagen 模型生成图片。
Future<void> testImagenGeneration(LlmClient llm) async {
  debugPrint('运行测试: 图片生成 (Imagen)...');
  try {
    final model =
        llm.imagenModel(model: 'imagen-4.0-generate-preview-06-06');
    final response = await model.generateImages(
      prompt: 'A cute cat wearing a wizard hat.',
      parameters: const gemini.ImagenParameters(numberOfImages: 1),
    );
    if (response.predictions.isNotEmpty) {
      debugPrint('成功: Imagen 图片生成完成并返回了 ${response.predictions.length} 张图片。');
      assert(response.predictions.first.isNotEmpty);
    } else {
      debugPrint('失败: Imagen 未返回图片数据。');
    }
  } catch (e) {
    debugPrint('失败: $e');
  }
}

/// 测试视频生成功能。
Future<void> testVideoGeneration(LlmClient llm) async {
  debugPrint('运行测试: 视频生成 (启动操作)...');
  try {
    final model = llm.videoModel(model: 'veo-3.0-generate-preview');
    final response = await model
        .generateVideo(config: gemini.VeoConfig(prompt: 'A fast car driving on a racetrack.'));
    debugPrint('成功: 视频生成任务已完成。');
    assert(response.generatedVideos.isNotEmpty);
  } catch (e) {
    debugPrint('失败: $e');
  }
}


/// 测试 Lyria 音乐 API 的连接。
Future<void> testMusicApiConnection(LlmClient llm) async {
  debugPrint('运行测试: 音乐 API 连接...');
  try {
    final model = llm.musicModel(model: 'lyria-realtime-exp');
    final musicSession = await model.connect();
    debugPrint('成功: MusicSession 已连接。');
    await musicSession.close();
    debugPrint('成功: MusicSession 已关闭。');
  } catch (e) {
    debugPrint('失败: $e');
  }
}

// =============================================================================
// IV. 高级功能与工具测试
// =============================================================================

/// 测试完整的函数调用周期。
Future<void> testFullFunctionCallingCycle(LlmClient llm) async {
  debugPrint('运行测试: 完整函数调用周期...');
  try {
    final tool = gemini.Tool(functionDeclarations: [
      gemini.FunctionDeclaration(
        name: 'get_weather',
        description: '获取一个城市的天气',
        parameters: {
          'type': 'object',
          'properties': {
            'city': {'type': 'string', 'description': '城市名称'}
          },
          'required': ['city']
        },
      )
    ]);

    final initialContent = gemini.Content.text('东京的天气怎么样？');

    // 步骤 1: 模型请求函数调用
    final request1 =
        gemini.GenerateContentRequest(contents: [initialContent], tools: [tool]);
    final response1 = await llm.generateContent('gemini-2.5-flash', request1);

    final functionCallPart = response1.candidates.firstOrNull?.content.parts
        .whereType<gemini.FunctionCallPart>()
        .firstOrNull;

    if (functionCallPart == null) {
      throw Exception('失败: 未收到函数调用。响应: ${response1.text}');
    }
    final functionCall = functionCallPart.functionCall;

    debugPrint('成功: 收到函数调用。');
    debugPrint('函数名称: ${functionCall.name}');
    debugPrint('函数参数: ${functionCall.args}');
    assert(functionCall.name == 'get_weather');

    // 步骤 2: 执行函数（模拟）并将结果返回
    final functionResponse = gemini.Content('user', [
      gemini.FunctionResponsePart(
          functionCall.name, {'temperature': '25°C', 'condition': 'sunny'})
    ]);

    final history = [
      initialContent,
      response1.candidates.first.content, // 将模型的调用请求也加入历史
      functionResponse,
    ];

    // 步骤 3: 将函数响应发送回模型
    final request2 = gemini.GenerateContentRequest(contents: history);
    final response2 = await llm.generateContent('gemini-2.5-flash', request2);

    debugPrint('成功: 函数调用后的最终模型响应: ${response2.text}');
    assert(response2.text?.contains('25°C') ?? false);
  } catch (e) {
    debugPrint('失败: $e');
  }
}

/// 测试代码执行工具。
Future<void> testCodeExecution(LlmClient llm) async {
  debugPrint('运行测试: 代码执行...');
  try {
    final request = gemini.GenerateContentRequest(
      contents: [gemini.Content.text('计算前10个素数的和。')],
      tools: [gemini.Tool(codeExecution: {})],
    );
    final response = await llm.generateContent('gemini-2.5-flash', request);

    final codeExecutionPart = response.candidates.first.content.parts
        .whereType<gemini.ExecutableCodePart>()
        .firstOrNull;

    if (codeExecutionPart != null) {
      debugPrint('成功: 代码执行工具被使用。');
      debugPrint('代码: ${codeExecutionPart.code}');
    } else {
      debugPrint('警告: 未显式返回代码执行工具。响应: ${response.text}');
    }
    debugPrint('最终文本: ${response.text}');
  } catch (e) {
    debugPrint('失败: $e');
  }
}


/// 测试使用 Google 搜索建立依据。
Future<void> testGroundingWithSearch(LlmClient llm) async {
  debugPrint('运行测试: 使用 Google 搜索建立依据...');
  try {
    final request = gemini.GenerateContentRequest(
      contents: [gemini.Content.text('最近一届 FIFA 世界杯的冠军是谁？')],
      tools: [gemini.Tool(googleSearch: {})],
    );
    final response = await llm.generateContent('gemini-2.5-pro', request);

    final groundingMetadata = response.candidates.firstOrNull?.groundingMetadata;

    if (groundingMetadata != null) {
      debugPrint('成功: 返回了建立依据的元数据。');
      debugPrint('搜索查询: ${groundingMetadata.webSearchQueries}');
      assert(groundingMetadata.webSearchQueries?.isNotEmpty ?? false);
    } else {
      debugPrint('失败: 未返回建立依据的元数据。响应: ${response.text}');
    }
    debugPrint('最终文本: ${response.text}');
  } catch (e) {
    debugPrint('失败: $e');
  }
}

/// 测试 URL 上下文工具。
Future<void> testUrlContext(LlmClient llm) async {
  debugPrint('运行测试: URL 上下文...');
  try {
    final request = gemini.GenerateContentRequest(
        contents: [
          gemini.Content.text(
              '总结这篇文章的要点: https://blog.google/technology/ai/google-gemini-ai/')
        ],
        tools: [
          gemini.Tool(urlContext: {})
        ]);
    final response = await llm.generateContent('gemini-2.5-flash', request);

    if (response.text != null && response.text!.isNotEmpty) {
      debugPrint('成功: 返回了 URL 内容的摘要。');
      final urlContextMetadata =
          response.candidates.firstOrNull?.urlContextMetadata;
      if (urlContextMetadata != null &&
          urlContextMetadata.urlMetadata.isNotEmpty) {
        final metadata = urlContextMetadata.urlMetadata.first;
        debugPrint('URL 上下文元数据 URL: ${metadata.retrievedUrl}');
        debugPrint('URL 上下文元数据状态: ${metadata.urlRetrievalStatus}');
        assert(metadata.retrievedUrl?.isNotEmpty ?? false);
      }
    } else {
      debugPrint('失败: 未返回 URL 内容的摘要。');
    }
    debugPrint('最终文本: ${response.text}');
    assert(response.text?.isNotEmpty ?? false);
  } catch (e) {
    debugPrint('失败: $e');
  }
}

/// 测试 Gemini 思考功能。
Future<void> testGeminiThinking(LlmClient llm) async {
  debugPrint('运行测试: Gemini 思考...');
  try {
    final request = gemini.GenerateContentRequest(
      contents: [
        gemini.Content.text(
            '解决这个逻辑谜题：一个人正在看一幅肖像。有人问他在看谁的肖像，他回答说：“我没有兄弟姐妹，但那个人的父亲是我父亲的儿子。” 这个人在看谁的肖像？')
      ],
      generationConfig: const gemini.GenerationConfig(
        thinkingConfig: gemini.ThinkingConfig(includeThoughts: true),
      ),
    );
    final response = await llm.generateContent('gemini-2.5-pro', request);

    final thoughts = response.candidates.first.content.parts
        .whereType<gemini.TextPart>()
        .where((p) => p.thought == true);

    if (thoughts.isNotEmpty) {
      debugPrint('成功: 模型返回了思考过程。');
      for (final t in thoughts) {
        debugPrint('思考: ${t.text}');
      }
    } else {
      debugPrint('警告: 未返回思考过程。');
    }
    debugPrint('最终文本: ${response.text}');
    assert(response.text?.toLowerCase().contains('他儿子') ??
        response.text?.toLowerCase().contains('his son') ??
        false);
  } catch (e) {
    debugPrint('失败: $e');
  }
}

// =============================================================================
// V. 交互模式测试
// =============================================================================

/// 测试批处理模式。
Future<void> testBatchMode(LlmClient llm) async {
  debugPrint('运行测试: 批处理模式 (嵌入)...');
  try {
    final request = gemini.BatchEmbedContentsRequest(requests: [
      gemini.EmbedContentRequest(
          model: 'models/embedding-001',
          content: gemini.Content.text('法国的首都是哪里？')),
      gemini.EmbedContentRequest(
          model: 'models/embedding-001',
          content: gemini.Content.text('144 的平方根是多少？')),
    ]);
    final response = await llm.batchEmbedContents('embedding-001', request);
    debugPrint('成功: 为 ${response.embeddings.length} 个文档生成了批量嵌入。');
    assert(response.embeddings.length == 2);
    assert(response.embeddings.first.values.isNotEmpty);
  } catch (e) {
    debugPrint('失败: $e');
  }
}


/// 测试 Live API 的连接。
Future<void> testLiveApiConnection(LlmClient llm) async {
  debugPrint('运行测试: Live API 连接...');
  try {
    final model = llm.liveModel(model: 'gemini-live-2.5-flash-preview');
    final liveSession = await model
        .connect(const gemini.LiveConnectConfig(responseModalities: ['TEXT']));
    debugPrint('成功: LiveSession 已连接。');
    await liveSession.close();
    debugPrint('成功: LiveSession 已关闭。');
  } catch (e) {
    debugPrint('失败: $e');
  }
}

/// 测试为 Live API 创建临时认证令牌。
Future<void> testCreateAuthToken(LlmClient llm) async {
  debugPrint('运行测试: 临时令牌创建...');
  try {
    final config = gemini.AuthTokenConfig(
      uses: 1,
      expireTime: DateTime.now().add(const Duration(minutes: 5)),
      newSessionExpireTime: DateTime.now().add(const Duration(minutes: 1)),
      liveConnectConstraints: gemini.LiveConnectConstraints(
        model: 'gemini-live-2.5-flash-preview',
        config: const gemini.LiveConnectConfig(responseModalities: ['TEXT']),
      ),
    );
    final token = await llm.authTokens.create(config);
    debugPrint('成功: 认证令牌已创建: ${token.name}');
    assert(token.name.isNotEmpty);
  } catch (e) {
    debugPrint('失败: $e');
  }
}

// =============================================================================
// VI. 支撑性 API 测试
// =============================================================================

/// 测试文件服务功能 (上传, 获取, 列表, 删除, 下载)。
Future<void> testFileService(LlmClient llm) async {
  debugPrint('运行测试: 完整文件服务周期...');
  gemini.File? uploadedFile;
  try {
    // 1. 在内存中创建一个虚拟文件。
    final fileContent = '这是一个用于下载验证的测试文件。';
    final fileBytes = Uint8List.fromList(utf8.encode(fileContent));
    debugPrint('正在上传文件...');

    // 2. 上传文件。
    uploadedFile = await llm.files.upload(fileBytes, 'text/plain');
    debugPrint('成功: 文件已上传。名称: ${uploadedFile.name}');
    final fileId = uploadedFile.name.split('/').last;

    // 3. 为后端同步添加延迟。
    await Future.delayed(const Duration(seconds: 5));

    // 4. 获取文件以进行验证。
    final gotFile = await llm.files.get(fileId);
    debugPrint('成功: 获取到文件。名称: ${gotFile.name}');
    assert(gotFile.name == uploadedFile.name);

    // 5. 列出文件以进行验证。
    final files = await llm.files.list();
    debugPrint('成功: 找到 ${files.items.length} 个文件。');
    assert(files.items.any((f) => f.name == uploadedFile?.name),
        '在列表中未找到上传的文件 ${uploadedFile.name}。');
    debugPrint('成功: 在列表中找到了上传的文件。');

    // 6. 下载验证被移除，因为 API 不支持下载用户上传的文件。
    // API 的主要用途是使用文件作为模型输入。
    debugPrint('成功: 上传、获取和列出文件的测试已通过。');
  } catch (e) {
    debugPrint('失败: $e');
  } finally {
    // 7. 通过删除文件进行清理。
    if (uploadedFile != null) {
      final fileId = uploadedFile.name.split('/').last;
      await llm.files.delete(fileId);
      debugPrint('成功: 已清理并删除文件 ${uploadedFile.name}。');
    }
  }
}

/// 测试嵌入功能。
Future<void> testEmbeddings(LlmClient llm) async {
  debugPrint('运行测试: 嵌入 (Embeddings)...');
  try {
    // 1. 测试单个内容嵌入
    final embedRequest = gemini.EmbedContentRequest(
      model: 'models/embedding-001',
      content: gemini.Content.text('这是一个用于嵌入的测试。'),
      taskType: gemini.TaskType.retrievalDocument,
    );
    final embedResponse = await llm.embedContent(embedRequest);
    debugPrint('成功: 单个嵌入已生成。');
    debugPrint('嵌入向量长度: ${embedResponse.embedding.values.length}');
    assert(embedResponse.embedding.values.isNotEmpty);

    // 2. 测试批量内容嵌入
    final batchEmbedRequest = gemini.BatchEmbedContentsRequest(requests: [
      gemini.EmbedContentRequest(model: 'models/embedding-001', content: gemini.Content.text('用于批处理的第一个文档。')),
      gemini.EmbedContentRequest(model: 'models/embedding-001', content: gemini.Content.text('用于批处理的第二个文档。')),
    ]);
    final batchEmbedResponse =
        await llm.batchEmbedContents('embedding-001', batchEmbedRequest);
    debugPrint(
        '成功: 为 ${batchEmbedResponse.embeddings.length} 个文档生成了批量嵌入。');
    assert(batchEmbedResponse.embeddings.length == 2);
  } catch (e) {
    debugPrint('失败: $e');
  }
}

/// 测试模型服务功能 (列出模型)。
Future<void> testModelService(LlmClient llm) async {
  debugPrint('运行测试: 模型服务 (列出模型)...');
  try {
    final response = await llm.models.list();
    debugPrint('成功: 找到 ${response.items.length} 个模型。');
    assert(response.items.isNotEmpty);

    final geminiFlash = response.items.firstWhereOrNull((m) => m.name.contains('gemini-2.5-flash'));
    if (geminiFlash != null) {
      debugPrint('找到模型: ${geminiFlash.displayName}');
      debugPrint('支持的生成方法: ${geminiFlash.supportedGenerationMethods}');
      assert(
          geminiFlash.supportedGenerationMethods.contains('generateContent'),
          'gemini-2.5-flash 模型应支持 "generateContent"。');
    } else {
      debugPrint('警告: 在列表中未找到 "gemini-2.5-flash"。');
    }
  } catch (e) {
    debugPrint('失败: $e');
  }
}

/// 测试问答 (QA) 功能。
Future<void> testGenerateAnswer(LlmClient llm) async {
  debugPrint('运行测试: 问答 (QA)...');
  try {
    // 动态查找并列出所有支持 'generateAnswer' 的模型
    final modelsList = await llm.models.list();
    final qaModels = modelsList.items
        .where((m) => m.supportedGenerationMethods.contains('generateAnswer'))
        .toList();

    if (qaModels.isEmpty) {
      debugPrint("[跳过] 未找到任何支持 'generateAnswer' 的模型。");
      return;
    }

    debugPrint('找到 ${qaModels.length} 个支持问答 (QA) 的模型:');
    for (final model in qaModels) {
      debugPrint(
          '  - 名称: ${model.name}, 显示名称: ${model.displayName}, 支持的方法: ${model.supportedGenerationMethods}');
    }

    // 为了测试，我们继续使用列表中的第一个模型
    final qaModel = qaModels.first;
    debugPrint("\n将使用第一个找到的模型 '${qaModel.name}' 进行问-答测试。");

    final response = await llm.generateAnswer(
        qaModel.name,
        gemini.GenerateAnswerRequest(
          contents: [gemini.Content.text('法国的首都是哪里？')],
          answerStyle: gemini.AnswerStyle.abstractive,
          inlinePassages: gemini.GroundingPassages(passages: [
            gemini.GroundingPassage(
                id: 'passage1',
                content: gemini.Content.text(
                    '法国是西欧的一个国家。它的首都是巴黎，也是该国最大的城市。'))
          ]),
        ));

    debugPrint('成功: 生成了答案。');
    final answerText = response.answer?.content.parts
        .whereType<gemini.TextPart>()
        .map((p) => p.text)
        .join('');
    debugPrint('答案: $answerText');
    debugPrint('可回答性概率: ${response.answerableProbability}');
    assert(answerText?.toLowerCase().contains('paris') ?? false);
    assert((response.answerableProbability ?? 0) > 0.5,
        '可回答性概率应大于 0.5，但得到的是 ${response.answerableProbability}。');
  } catch (e) {
    debugPrint('失败: $e');
  }
}
