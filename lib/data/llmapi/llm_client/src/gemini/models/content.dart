// lib/src/gemini/models/content.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import './video.dart';

/// Represents content sent to or received from the model.
class Content {
  final String? role;
  final List<Part> parts;

  Content(this.role, this.parts);

  factory Content.text(String text) => Content('user', [TextPart(text)]);
  factory Content.multi(List<Part> parts) => Content('user', parts);

  factory Content.fromJson(Map<String, dynamic> json) {
    return Content(
      json['role'],
      (json['parts'] as List? ?? [])
          .map((partJson) => Part.fromJson(partJson))
          .toList(),
    );
  }

  Map<String, dynamic> toJson({bool includeRole = true}) {
    final Map<String, dynamic> json = {
      'parts': parts.map((p) => p.toJson()).toList(),
    };
    if (includeRole && role != null) {
      json['role'] = role;
    }
    return json;
  }
}

/// Abstract base class for a piece of content.
abstract class Part {
  const Part();

  Map<String, dynamic> toJson();

  /// Creates a [Part] from a text string.
  factory Part.text(String text) => TextPart(text);

  /// Creates a [Part] from raw data bytes.
  factory Part.data(String mimeType, Uint8List bytes) => DataPart(mimeType, bytes);

  factory Part.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('text')) {
      return TextPart.fromJson(json);
    }
    if (json.containsKey('inlineData')) {
      return DataPart.fromJson(json);
    }
    if (json.containsKey('functionCall')) {
      return FunctionCallPart.fromJson(json);
    }
    if (json.containsKey('functionResponse')) {
      return FunctionResponsePart.fromJson(json);
    }
    if (json.containsKey('fileData')) {
      return FileDataPart.fromJson(json);
    }
    if (json.containsKey('executableCode')) {
      return ExecutableCodePart.fromJson(json);
    }
    if (json.containsKey('codeExecutionResult')) {
      return CodeExecutionResultPart.fromJson(json);
    }
    throw ArgumentError('Unknown Part type in response: $json');
  }
}

/// A text part of the content.
class TextPart extends Part {
  final String text;
  final bool? thought;
  final String? thoughtSignature;
  const TextPart(this.text, {this.thought, this.thoughtSignature});

  factory TextPart.fromJson(Map<String, dynamic> json) {
    return TextPart(json['text'],
        thought: json['thought'], thoughtSignature: json['thoughtSignature']);
  }

  @override
  Map<String, dynamic> toJson() => {
        'text': text,
        if (thought != null) 'thought': thought,
        if (thoughtSignature != null) 'thoughtSignature': thoughtSignature,
      };
}

/// A data part of the content, usually for images or audio.
class DataPart extends Part {
  final String mimeType;
  final Uint8List bytes;
  const DataPart(this.mimeType, this.bytes);

  factory DataPart.fromJson(Map<String, dynamic> json) {
    final inlineData = json['inlineData'];
    return DataPart(inlineData['mimeType'], base64Decode(inlineData['data']));
  }

  @override
  Map<String, dynamic> toJson() => {
        'inline_data': {'mime_type': mimeType, 'data': base64Encode(bytes)}
      };
}

/// A part containing a file URI.
class FileDataPart extends Part {
  final String mimeType;
  final String fileUri;
  final VideoMetadata? videoMetadata;
  const FileDataPart(this.mimeType, this.fileUri, {this.videoMetadata});

  factory FileDataPart.fromJson(Map<String, dynamic> json) {
    final fileData = json['fileData'];
    return FileDataPart(
      fileData['mimeType'],
      fileData['fileUri'],
      videoMetadata: fileData.containsKey('videoMetadata')
          ? VideoMetadata.fromJson(fileData['videoMetadata'])
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'file_data': {
          'mime_type': mimeType,
          'file_uri': fileUri,
          if (videoMetadata != null) ...videoMetadata!.toJson(),
        }
      };
}

/// A function call part from the model.
class FunctionCallPart extends Part {
  final FunctionCall functionCall;
  final bool? thought;
  final String? thoughtSignature;
  const FunctionCallPart(this.functionCall, {this.thought, this.thoughtSignature});

  factory FunctionCallPart.fromJson(Map<String, dynamic> json) {
    return FunctionCallPart(
      FunctionCall.fromJson(json['functionCall']),
      thought: json['thought'],
      thoughtSignature: json['thoughtSignature'],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'functionCall': functionCall.toJson(),
        if (thought != null) 'thought': thought,
        if (thoughtSignature != null) 'thoughtSignature': thoughtSignature,
      };
}

enum Scheduling {
  unspecified,
  always,
  never,
}

/// A function response part sent to the model.
class FunctionResponsePart extends Part {
  final String name;
  final Map<String, dynamic> response;
  final String? id;
  final bool? willContinue;
  final Scheduling? scheduling;

  const FunctionResponsePart(this.name, this.response,
      {this.id, this.willContinue, this.scheduling});

  factory FunctionResponsePart.fromJson(Map<String, dynamic> json) {
    final funcResponse = json['functionResponse'];
    return FunctionResponsePart(funcResponse['name'], funcResponse['response'],
        id: funcResponse['id'],
        willContinue: funcResponse['willContinue'],
        scheduling: funcResponse['scheduling'] != null
            ? Scheduling.values
                .byName((funcResponse['scheduling'] as String).toLowerCase())
            : null);
  }

  @override
  Map<String, dynamic> toJson() => {
        'functionResponse': {
          'name': name,
          'response': response,
          if (id != null) 'id': id,
          if (willContinue != null) 'willContinue': willContinue,
          if (scheduling != null) 'scheduling': scheduling!.name.toUpperCase(),
        }
      };
}


/// A part containing executable code.
class ExecutableCodePart extends Part {
  final String language;
  final String code;
  const ExecutableCodePart(this.language, this.code);

  factory ExecutableCodePart.fromJson(Map<String, dynamic> json) {
    final ec = json['executableCode'];
    return ExecutableCodePart(ec['language'], ec['code']);
  }

  @override
  Map<String, dynamic> toJson() => {
        'executableCode': {'language': language, 'code': code}
      };
}

/// A part containing the result of a code execution.
class CodeExecutionResultPart extends Part {
  final String outcome;
  final String output;
  const CodeExecutionResultPart(this.outcome, this.output);

  factory CodeExecutionResultPart.fromJson(Map<String, dynamic> json) {
    final cer = json['codeExecutionResult'];
    return CodeExecutionResultPart(cer['outcome'], cer['output']);
  }

  @override
  Map<String, dynamic> toJson() => {
        'codeExecutionResult': {'outcome': outcome, 'output': output}
      };
}

/// Represents a function call requested by the model.
class FunctionCall {
  final String name;
  final Map<String, dynamic> args;

  const FunctionCall(this.name, this.args);

  factory FunctionCall.fromJson(Map<String, dynamic> json) {
    return FunctionCall(json['name'], json['args']);
  }

  Map<String, dynamic> toJson() => {'name': name, 'args': args};
}