// lib/src/gemini/models/schema.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// Type of the schema.
enum SchemaType {
  unspecified('TYPE_UNSPECIFIED'),
  string('STRING'),
  number('NUMBER'),
  integer('INTEGER'),
  boolean('BOOLEAN'),
  array('ARRAY'),
  object('OBJECT'),
  nullType('NULL');

  const SchemaType(this.value);
  final String value;
}

/// Defines the schema for a structured response.
class Schema {
  final SchemaType type;
  final String? format;
  final String? title;
  final String? description;
  final bool? nullable;
  final List<String>? enumValues;
  final Schema? items;
  final Map<String, Schema>? properties;
  final List<String>? required;
  final int? minItems;
  final int? maxItems;
  final int? minProperties;
  final int? maxProperties;
  final int? minLength;
  final int? maxLength;
  final String? pattern;
  final dynamic example;
  final List<Schema>? anyOf;
  final List<String>? propertyOrdering;
  final dynamic defaultValue;
  final double? minimum;
  final double? maximum;

  Schema({
    required this.type,
    this.format,
    this.title,
    this.description,
    this.nullable,
    this.enumValues,
    this.items,
    this.properties,
    this.required,
    this.minItems,
    this.maxItems,
    this.minProperties,
    this.maxProperties,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.example,
    this.anyOf,
    this.propertyOrdering,
    this.defaultValue,
    this.minimum,
    this.maximum,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      if (format != null) 'format': format,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (nullable != null) 'nullable': nullable,
      if (enumValues != null) 'enum': enumValues,
      if (items != null) 'items': items!.toJson(),
      if (properties != null)
        'properties':
            properties!.map((key, value) => MapEntry(key, value.toJson())),
      if (required != null) 'required': required,
      if (minItems != null) 'minItems': minItems,
      if (maxItems != null) 'maxItems': maxItems,
      if (minProperties != null) 'minProperties': minProperties,
      if (maxProperties != null) 'maxProperties': maxProperties,
      if (minLength != null) 'minLength': minLength,
      if (maxLength != null) 'maxLength': maxLength,
      if (pattern != null) 'pattern': pattern,
      if (example != null) 'example': example,
      if (anyOf != null) 'anyOf': anyOf!.map((e) => e.toJson()).toList(),
      if (propertyOrdering != null) 'propertyOrdering': propertyOrdering,
      if (defaultValue != null) 'default': defaultValue,
      if (minimum != null) 'minimum': minimum,
      if (maximum != null) 'maximum': maximum,
    };
  }

  factory Schema.fromJson(Map<String, dynamic> json) {
    return Schema(
      type: SchemaType.values.firstWhere((e) => e.value == json['type'],
          orElse: () => SchemaType.unspecified),
      format: json['format'],
      title: json['title'],
      description: json['description'],
      nullable: json['nullable'],
      enumValues:
          json['enum'] != null ? List<String>.from(json['enum']) : null,
      items: json['items'] != null ? Schema.fromJson(json['items']) : null,
      properties: json['properties'] != null
          ? (json['properties'] as Map<String, dynamic>)
              .map((key, value) => MapEntry(key, Schema.fromJson(value)))
          : null,
      required:
          json['required'] != null ? List<String>.from(json['required']) : null,
      minItems: json['minItems'],
      maxItems: json['maxItems'],
      minProperties: json['minProperties'],
      maxProperties: json['maxProperties'],
      minLength: json['minLength'],
      maxLength: json['maxLength'],
      pattern: json['pattern'],
      example: json['example'],
      anyOf: json['anyOf'] != null
          ? (json['anyOf'] as List).map((e) => Schema.fromJson(e)).toList()
          : null,
      propertyOrdering: json['propertyOrdering'] != null
          ? List<String>.from(json['propertyOrdering'])
          : null,
      defaultValue: json['default'],
      minimum: json['minimum'],
      maximum: json['maximum'],
    );
  }
}