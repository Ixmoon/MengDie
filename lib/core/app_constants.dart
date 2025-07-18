/// 全局默认提示词常量
///
/// 将这些常量放在数据模型层，以便数据库层和UI层都可以安全地访问，而不会造成不当的跨层级依赖。
// ignore: unnecessary_library_name
library app_constants;

/// 用于自动生成聊天标题的默认提示词。
const String defaultTitleGenerationPrompt = '根据对话，为本次聊天生成一个简洁的、不超过10个字的标题。（你的回复内容只能是纯标题，不能包含任何其他内容）';

/// 用于在模型输出中断后继续生成的默认提示词。
const String defaultResumePrompt = '继续生成被中断的回复，请直接从最后一个字甚至是符号后继续，不要包含任何其他内容。';