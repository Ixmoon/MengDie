// This file is being phased out.
// The models previously defined here (XmlRule, SafetySettingRule, GenerationConfig, ContextConfig, OpenAIAPIConfig)
// have been recreated as plain Dart objects with toJson/fromJson methods
// in the lib/data/database/drift/models/ directory for use with Drift type converters.

// import 'package:isar/isar.dart'; // Temporarily commented out
// import 'package:uuid/uuid.dart'; 
// import 'enums.dart'; 

// part 'embedded_models.g.dart'; // Temporarily commented out

// --- All classes below are commented out as they are replaced by Drift-specific models ---

/*
class XmlRule {
  String? tagName; 
  XmlAction action = XmlAction.ignore; 
  XmlRule(); 
  XmlRule.create({required this.tagName, required this.action});
}

class SafetySettingRule {
  LocalHarmCategory category = LocalHarmCategory.harassment; 
  LocalHarmBlockThreshold threshold = LocalHarmBlockThreshold.none; 
  SafetySettingRule();
  SafetySettingRule.create({required this.category, required this.threshold});
}

class GenerationConfig {
  String modelName = 'gemini-2.5-pro-exp-03-25'; 
  double? temperature; 
  double? topP; 
  int? topK; 
  int? maxOutputTokens = 60000; 
  List<String>? stopSequences; 
  List<SafetySettingRule> safetySettings = [ 
    SafetySettingRule.create(category: LocalHarmCategory.harassment, threshold: LocalHarmBlockThreshold.none),
    SafetySettingRule.create(category: LocalHarmCategory.hateSpeech, threshold: LocalHarmBlockThreshold.none),
    SafetySettingRule.create(category: LocalHarmCategory.sexuallyExplicit, threshold: LocalHarmBlockThreshold.none),
    SafetySettingRule.create(category: LocalHarmCategory.dangerousContent, threshold: LocalHarmBlockThreshold.none),
  ];
  GenerationConfig();
}

class ContextConfig {
  ContextManagementMode mode = ContextManagementMode.turns; 
  int maxTurns = 10; 
  int? maxContextTokens; 
  ContextConfig(); 
}

class OpenAIAPIConfig {
  late final String id; 
  String name;
  String baseUrl;
  String? apiKey;
  String modelName;

  OpenAIAPIConfig({
    String? idParam, 
    this.name = 'My OpenAI Endpoint',
    this.baseUrl = 'https://api.openai.com/v1',
    this.apiKey,
    this.modelName = 'gpt-3.5-turbo',
  }) {
      id = idParam ?? const Uuid().v4(); 
  }
}
*/
