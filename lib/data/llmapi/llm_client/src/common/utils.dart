// lib/src/common/utils.dart

// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import '../gemini/models.dart';

/// Processes a dynamic `contents` argument into a standardized `Iterable<Content>`.
///
/// This function handles various input types:
/// - A single [String] is converted into a `Content.text`.
/// - A single [Content] object is returned as is.
/// - An `Iterable<Content>` is returned as is.
/// - An `Iterable<dynamic>` containing [String]s, [Uint8List]s, or [Part]s
///   is converted into a single `Content` object with multiple parts.
///
/// Throws an [ArgumentError] if the input type or an item in the list is unsupported.
Iterable<Content> processContents(dynamic contents) {
  if (contents is String) {
    return [Content.text(contents)];
  } else if (contents is Content) {
    return [contents];
  } else if (contents is Iterable<Content>) {
    return contents;
  } else if (contents is Iterable<dynamic>) {
    final parts = contents.map((item) {
      if (item is String) {
        return Part.text(item);
      } else if (item is Uint8List) {
        // Defaulting MIME type, consider making this configurable
        return Part.data('image/jpeg', item);
      } else if (item is Part) {
        return item;
      }
      throw ArgumentError(
          'Unsupported type in contents list: ${item.runtimeType}');
    }).toList();
    return [Content('user', parts.toList())];
  }
  throw ArgumentError('Unsupported contents type: ${contents.runtimeType}');
}

extension EnumCamelCaseToSnakeCase on Enum {
  String toScreamingSnakeCase() {
    final camelCase = name;
    final buffer = StringBuffer();
    for (var i = 0; i < camelCase.length; i++) {
      final char = camelCase[i];
      if (char == char.toUpperCase() && i > 0) {
        buffer.write('_');
      }
      buffer.write(char.toUpperCase());
    }
    return buffer.toString();
  }
}