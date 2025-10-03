
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'content.dart';
import 'generative.dart';
import 'config.dart';

/// A cached resource that can be used to send context to the model.
class CachedContent {
  /// The resource name of the cached content.
  final String? name;

  /// Optional. The user-provided display name of the cached content.
  final String? displayName;

  /// Required. The model that this cached content is compatible with.
  final String model;

  /// Optional. The content to cache.
  final List<Content>? contents;

  /// Optional. A list of tools that are available to the model.
  final List<Tool>? tools;

  /// Optional. Tool configuration for the model.
  final ToolConfig? toolConfig;

  /// Optional. System instruction for the model.
  final Content? systemInstruction;

  /// The creation time of the cached content.
  final String? createTime;

  /// The last update time of the cached content.
  final String? updateTime;

  /// The expiration time of the cached content.
  final String? expireTime;

  /// The time-to-live (TTL) of the cached content.
  final String? ttl;

  /// Metadata on the usage of the cached content.
  final UsageMetadata? usageMetadata;

  CachedContent({
    this.name,
    this.displayName,
    required this.model,
    this.contents,
    this.tools,
    this.toolConfig,
    this.systemInstruction,
    this.createTime,
    this.updateTime,
    this.expireTime,
    this.ttl,
    this.usageMetadata,
  });

  factory CachedContent.fromJson(Map<String, dynamic> json) {
    return CachedContent(
      name: json['name'],
      displayName: json['displayName'],
      model: json['model'],
      contents: (json['contents'] as List<dynamic>?)
          ?.map((e) => Content.fromJson(e as Map<String, dynamic>))
          .toList(),
      tools: (json['tools'] as List<dynamic>?)
          ?.map((e) => Tool.fromJson(e as Map<String, dynamic>))
          .toList(),
      toolConfig: json['toolConfig'] != null
          ? ToolConfig.fromJson(json['toolConfig'] as Map<String, dynamic>)
          : null,
      systemInstruction: json['systemInstruction'] != null
          ? Content.fromJson(json['systemInstruction'] as Map<String, dynamic>)
          : null,
      createTime: json['createTime'],
      updateTime: json['updateTime'],
      expireTime: json['expireTime'],
      ttl: json['ttl'],
      usageMetadata: json['usageMetadata'] != null
          ? UsageMetadata.fromJson(json['usageMetadata'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'model': model,
    };
    if (displayName != null) {
      json['displayName'] = displayName;
    }
    if (contents != null) {
      json['contents'] = contents!.map((e) => e.toJson()).toList();
    }
    if (tools != null) {
      json['tools'] = tools!.map((e) => e.toJson()).toList();
    }
    if (toolConfig != null) {
      json['toolConfig'] = toolConfig!.toJson();
    }
    if (systemInstruction != null) {
      json['systemInstruction'] = systemInstruction!.toJson();
    }
    if (ttl != null) {
      json['ttl'] = ttl;
    }
    return json;
  }
}