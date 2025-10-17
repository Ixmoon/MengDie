// ignore_for_file: constant_identifier_names

import 'package:json_annotation/json_annotation.dart';

// This file contains enums used by Drift tables and type converters.
// These are kept separate from UI-level or Isar-specific enums if needed.

@JsonEnum()
enum LlmType { gemini, openai }

@JsonEnum()
enum MessageRole { user, model }

@JsonEnum()
enum XmlAction { save, update, collapsible, content }

enum LocalHarmCategory {
  harassment,
  hateSpeech,
  sexuallyExplicit,
  dangerousContent,
  unknown,
}

enum LocalHarmBlockThreshold {
  none,
  lowAndAbove,
  mediumAndAbove,
  highAndAbove,
  unspecified,
}

@JsonEnum()
enum ContextManagementMode { turns, tokens }

@JsonEnum()
enum PromptInjectionRole { system, user, model }

// ThemeModeSetting is not directly stored in the database tables being refactored
// so it's not included here for now.
