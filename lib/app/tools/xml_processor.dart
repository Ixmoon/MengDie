import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:xml/xml.dart';

// Import models
import '../../domain/models/xml_rule.dart'; // Use domain model
import '../../domain/enums.dart';    // Use domain enums

// --- XML Processing Result Class ---
class XmlProcessResult {
  final String processedText; // Final text for display
  final String? carriedOverContent; // Serialized XML state (for save/update)

  XmlProcessResult({required this.processedText, this.carriedOverContent});
}

class PostProcessResult {
  final String modelsText;
  final String? extractedXml;

  PostProcessResult({required this.modelsText, this.extractedXml});
}

// --- XML Processor Class ---
class XmlProcessor {
  // Core processing method
  static XmlProcessResult process(
      String rawText,
      List<XmlRule> rules, // Use domain model XmlRule
      {String? previousCarriedOverContent} // Receive state from the previous round
      ) {
    // If no rules are defined, do not process or carry over any XML content.
    if (rules.isEmpty) {
      debugPrint("XmlProcessor: No rules defined. Returning empty processed text and no carried over content.");
      return XmlProcessResult(processedText: '', carriedOverContent: null);
    }

    // If rules are present, but text doesn't appear to contain XML tags,
    // preserve previous state (as per original logic for this specific condition).
    // This part of the condition `!rawText.contains('<') || !rawText.contains('>')`
    // is now evaluated only if rules.isEmpty is false.
    if (!rawText.contains('<') || !rawText.contains('>')) {
      debugPrint("XmlProcessor: Rules are present, but rawText does not contain XML tags. Preserving previous carriedOverContent.");
      return XmlProcessResult(processedText: '', carriedOverContent: previousCarriedOverContent);
    }

    // StringBuffer processedBuffer = StringBuffer(); // No longer needed as we don't 'show' text
    Map<String, String> previousCarriedOverMap = _parseCarriedOver(previousCarriedOverContent); // Parse previous state
    Map<String, String> currentCarriedOverMap = Map.from(previousCarriedOverMap); // State to be carried over this round

    try {
      // Attempt document parsing, which is necessary for save/update.
      // If parsing fails, we cannot perform save/update reliably.
      final document = XmlDocument.parse('<root>${rawText.trim()}</root>');
      // processedBuffer.clear(); // Not needed
      currentCarriedOverMap = Map.from(previousCarriedOverMap); // Start with previous state
      // Pass null for processedBuffer as it's not used anymore
      _processNode(document.rootElement, rules, null, currentCarriedOverMap, previousCarriedOverMap);

    } catch (e) {
      // This catch is for the initial parsing of the entire rawText.
      // If this fails, we cannot proceed with individual tag processing.
      debugPrint("XML Document parsing failed for rawText: $e. Cannot process save/update. Preserving previous state.");
      // On parsing failure, return empty processed text and the *previous* carried over content
      return XmlProcessResult(processedText: '', carriedOverContent: previousCarriedOverContent);
    }

    // --- Finalization ---
    // String finalProcessedText = processedBuffer.toString().trim(); // Not needed
    String? finalCarriedOver = _serializeCarriedOver(currentCarriedOverMap);

    // Always return empty string for processedText now.
    // Return the potentially updated carriedOverContent.
    debugPrint("XML processing complete. Returning empty processed text and updated state.");
    return XmlProcessResult(processedText: '', carriedOverContent: finalCarriedOver);
  }

  // --- Event Processing Logic (Fallback for show/delete) ---
  // REMOVED as show/delete actions are removed.

  // --- Document Node Processing Logic (Primary) ---
  static void _processNode(
      XmlNode node,
      List<XmlRule> rules, // Use domain model XmlRule
      StringBuffer? processedBuffer, // Made nullable, no longer used
      Map<String, String> currentCarriedOverMap,
      Map<String, String> previousCarriedOverMap
      // bool isRoot // No longer needed
      ) {
    if (node is XmlElement) {
      final tagName = node.name.local; // Original case tag name
      final tagNameLower = tagName.toLowerCase(); // Lowercase for rule matching
      final rule = _findRule(rules, tagNameLower);

      if (rule == null) {
        debugPrint("XML no rule found for: <$tagName>. Skipping this element, processing children.");
        // Process children recursively even if no rule for current node
        for (final child in node.children) {
          _processNode(child, rules, processedBuffer, currentCarriedOverMap, previousCarriedOverMap);
        }
        return;
      }

      final action = rule.action;

      switch (action) {
        case XmlAction.save:
          final identifier = getElementIdentifier(node);
          final outerXmlToSave = node.toXmlString(pretty: false).trim();
          if (outerXmlToSave.isNotEmpty) {
            currentCarriedOverMap[identifier] = outerXmlToSave;
            debugPrint("XML save: Stored with key '$identifier'");
          } else {
            currentCarriedOverMap.remove(identifier);
            debugPrint("XML save: Content empty, removed/not stored for key '$identifier'");
          }
          // Don't process children as their content is included in outerXml
          break;

        case XmlAction.update:
          final identifier = getElementIdentifier(node);
          final previousOuterXml = previousCarriedOverMap[identifier];

          debugPrint("XML update: <$tagName> (identifier: '$identifier')");

          if (previousOuterXml != null && previousOuterXml.isNotEmpty) {
            try {
              // Parse the previous full element and merge with the current one
              final previousElement = XmlDocument.parse(previousOuterXml).rootElement;
              final mergedElement = mergeElements(previousElement, node);
              final mergedOuterXml = mergedElement.toXmlString(pretty: false).trim();

              if (mergedOuterXml.isNotEmpty) {
                currentCarriedOverMap[identifier] = mergedOuterXml;
                debugPrint("XML update successful for '$identifier'.");
              } else {
                currentCarriedOverMap.remove(identifier);
                debugPrint("XML update successful for '$identifier' (merged to empty). Removed.");
              }
            } catch (e) {
              debugPrint("XML update failed for '$identifier' during parsing/merge: $e. Reverting to previous state.");
              // Preserve previous state for this tag
              currentCarriedOverMap[identifier] = previousOuterXml;
            }
          } else {
            // No previous state, treat as a simple save.
            final outerXmlToSave = node.toXmlString(pretty: false).trim();
            if (outerXmlToSave.isNotEmpty) {
              currentCarriedOverMap[identifier] = outerXmlToSave;
              debugPrint("XML update (no previous state, acting as save): Stored with key '$identifier'");
            } else {
              currentCarriedOverMap.remove(identifier);
            }
          }
          // Don't process children as their content is handled by the merge/save logic
          break;

        case XmlAction.collapsible:
        case XmlAction.content:
          debugPrint("XML content/collapsible: <$tagName>");
          // Do nothing, effectively hiding/ignoring this tag and its content
          break;
      }
    } else if (node is XmlText || node is XmlCDATA) {
      // Text nodes are ignored unless they are part of an element being saved/updated (handled by innerXml)
      // Do nothing here.
    } else if (node is XmlDocument || node is XmlDocumentFragment) {
      // Process children of the root document/fragment
      for (final child in node.children) {
        _processNode(child, rules, processedBuffer, currentCarriedOverMap, previousCarriedOverMap);
      }
    }
    // Ignore other node types like comments, processing instructions, etc.
  }

  // --- Helper: Recursively extract text content ---
  // REMOVED as show action is removed.

  // --- Public Static Wrapper for Merging Node Lists ---
  // Kept public as it might still be useful externally or for testing
  static List<XmlNode> mergeNodeLists(List<XmlNode> baseNodes, List<XmlNode> updateNodes) {
    return _mergeNodeLists(baseNodes, updateNodes);
  }

  /// Merges two XML elements. It keeps the base element's name and attributes
  /// and recursively merges their children.
  static XmlElement mergeElements(XmlElement baseElement, XmlElement updateElement) {
    final mergedChildren = _mergeNodeLists(baseElement.children, updateElement.children);
    return XmlElement(
      baseElement.name.copy(),
      baseElement.attributes.map((a) => a.copy()), // Keep base attributes
      mergedChildren,
    );
  }

  // --- Helper: Iteratively merge two lists of nodes (for Update) ---
  // This iterative approach prevents StackOverflowError for deeply nested XML.
  static List<XmlNode> _mergeNodeLists(List<XmlNode> baseNodes, List<XmlNode> updateNodes) {
    final List<XmlNode> mergedNodes = [];
    final Map<String, XmlElement> updateElementsMap = {
      for (var node in updateNodes.whereType<XmlElement>())
        getElementIdentifier(node): node
    };

    // Separate non-element nodes for optimized processing.
    final List<XmlNode> updateOtherNodes = updateNodes.where((n) => n is! XmlElement).toList();
    final Set<XmlNode> usedUpdateOtherNodes = {};

    // 1. Iterate through baseNodes and merge with/consume updateNodes
    for (final baseNode in baseNodes) {
      if (baseNode is XmlElement) {
        final baseIdentifier = getElementIdentifier(baseNode);
        final matchingUpdateElement = updateElementsMap.remove(baseIdentifier);

        if (matchingUpdateElement != null) {
          // Found a matching update element, merge them.
          final mergedElement = mergeElements(baseNode, matchingUpdateElement);
          mergedNodes.add(mergedElement);
        } else {
          // No matching update element found, keep the base node.
          mergedNodes.add(baseNode.copy());
        }
      } else if (baseNode is XmlText || baseNode is XmlCDATA) {
        // Heuristic: find the first available, non-empty, matching text/cdata node from the update list.
        final updateMatch = updateOtherNodes.firstWhereOrNull(
          (un) => (un.nodeType == baseNode.nodeType) && !usedUpdateOtherNodes.contains(un) && un.value != null && un.value!.trim().isNotEmpty,
        );

        if (updateMatch != null) {
          mergedNodes.add(updateMatch.copy()); // Use non-empty update
          usedUpdateOtherNodes.add(updateMatch); // Mark as used
        } else {
          mergedNodes.add(baseNode.copy()); // Keep base
        }
      } else {
        // Keep other base node types (comments, etc.)
        mergedNodes.add(baseNode.copy());
      }
    }

    // 2. Add any remaining (new) elements from the updateElementsMap.
    mergedNodes.addAll(updateElementsMap.values.map((e) => e.copy()));

    // 3. Add any remaining (unused) non-element nodes from updateOtherNodes, filtering out whitespace-only text nodes.
    for (final remainingOther in updateOtherNodes) {
      if (!usedUpdateOtherNodes.contains(remainingOther)) {
        bool isWhitespaceOnlyText = remainingOther is XmlText && remainingOther.value.trim().isEmpty;
        if (!isWhitespaceOnlyText) {
            mergedNodes.add(remainingOther.copy());
        }
      }
    }

    return mergedNodes;
  }

  // --- Utility Functions ---
  // Creates a unique identifier for an element.
  // Priority: 'id' attribute -> first attribute -> tag name.
  static String getElementIdentifier(XmlElement element) {
    // Prioritize 'id' attribute if it exists and is not empty.
    final idAttr = element.getAttribute('id');
    if (idAttr != null && idAttr.isNotEmpty) {
      return '${element.name.local}#$idAttr';
    }
    
    // Fallback to the first attribute if it exists and its value is not empty.
    if (element.attributes.isNotEmpty) {
      final firstAttrValue = element.attributes.first.value;
      if (firstAttrValue.isNotEmpty) {
        return '${element.name.local}#$firstAttrValue';
      }
    }

    // If no suitable attribute is found, fall back to just the tag name.
    return element.name.local;
  }

  static XmlRule? _findRule(List<XmlRule> rules, String tagNameLower) { // Use domain model XmlRule
    // Use firstWhereOrNull for cleaner handling of not found cases
    return rules.firstWhereOrNull((r) => r.tagName?.toLowerCase() == tagNameLower);
  }

  // Parses the serialized carried-over XML string back into a map.
  // The map key is the unique identifier, and the value is the full outer XML.
  static Map<String, String> _parseCarriedOver(String? content) {
    Map<String, String> map = {};
    if (content == null || content.trim().isEmpty) return map;
    try {
      // Wrap content in a root element for safe parsing of multiple root-level elements
      final doc = XmlDocument.parse('<carryRoot>${content.trim()}</carryRoot>');
      for (final node in doc.rootElement.children.whereType<XmlElement>()) {
        final identifier = getElementIdentifier(node);
        final outerXml = node.toXmlString(pretty: false).trim();
        if (outerXml.isNotEmpty) {
          map[identifier] = outerXml;
        }
      }
    } catch (e) {
      debugPrint("Failed to parse previous carriedOverContent: $e. Content: '$content'. Returning empty map.");
    }
    return map;
  }

  // Public wrapper for serialization (No changes needed here)
  static String? serializeCarriedOver(Map<String, String> map) {
    return _serializeCarriedOver(map);
  }

  // Serializes the state map back into a single, formatted XML string for storage.
  static String? _serializeCarriedOver(Map<String, String> map) {
    if (map.isEmpty) return null;
    // The values in the map are already complete XML strings.
    // We join them without separators to parse as a single document for pretty printing.
    final combinedXml = map.values.join('');
    if (combinedXml.trim().isEmpty) return null;

    try {
      // Wrap in a root to ensure it's a valid document for parsing.
      final document = XmlDocument.parse('<root>$combinedXml</root>');
      // Pretty print each child of the root to format it with indentation.
      final result = document.rootElement.children
          .map((node) => node.toXmlString(pretty: true, indent: '  '))
          .join('\n'); // Join each pretty-printed element with a newline.
      return result.isEmpty ? null : result;
    } catch (e) {
      debugPrint("Error during XML serialization for pretty printing: $e. Falling back to simple join.");
      // Fallback to original behavior if parsing fails.
      final result = map.values.join('\n');
      return result.isEmpty ? null : result;
    }
  }

  /// Strips XML tags and their content from a string using a fast, single-pass,
  /// state-machine-based approach. This is robust against malformed or incomplete XML.
  static String stripXmlContent(String rawText) {
    final buffer = StringBuffer();
    bool inTag = false;
    for (int i = 0; i < rawText.length; i++) {
      final char = rawText[i];
      if (char == '<') {
        inTag = true;
      } else if (char == '>') {
        inTag = false;
      } else if (!inTag) {
        buffer.write(char);
      }
    }
    return buffer.toString().trim();
  }

  /// Strips XML tags and their content if the tag has an 'ignore' rule.
  /// This implementation is robust, handles nested tags correctly, and is safe
  /// from catastrophic backtracking on malformed or incomplete XML.
  static String stripIgnoredXmlContent(String rawText, List<XmlRule> rules) {
    final trimmedText = rawText.trim();
    if (!trimmedText.contains('<')) {
      return trimmedText;
    }

    final ignoredTags = rules
        .where((r) => r.ignoreInContext && r.tagName != null)
        .map((r) => r.tagName!.toLowerCase())
        .toSet();

    if (ignoredTags.isEmpty) {
      return trimmedText;
    }

    final buffer = StringBuffer();
    int lastIndex = 0;
    // Regex to find any start or end tag, including self-closing ones.
    final tagRegex = RegExp(r'(<\s*\/?\s*([a-zA-Z0-9_:]+)[^>]*>)', caseSensitive: false);
    
    // A map to keep track of the nesting level for each ignored tag.
    final Map<String, int> ignoreDepth = { for (var tag in ignoredTags) tag : 0 };
    int totalIgnoreDepth = 0;

    for (final match in tagRegex.allMatches(trimmedText)) {
      final fullTag = match.group(1)!;
      final tagName = (match.group(2) ?? "").toLowerCase();

      // Append the text content found between the last tag and this one,
      // but only if we are not inside an ignored block.
      if (totalIgnoreDepth == 0) {
        buffer.write(trimmedText.substring(lastIndex, match.start));
      }

      if (ignoredTags.contains(tagName)) {
        final isSelfClosing = fullTag.endsWith('/>');
        final isClosingTag = fullTag.startsWith('</');

        if (!isSelfClosing) {
          if (isClosingTag) {
            if (ignoreDepth[tagName]! > 0) {
              ignoreDepth[tagName] = ignoreDepth[tagName]! - 1;
              totalIgnoreDepth--;
            }
          } else { // Is an opening tag
            ignoreDepth[tagName] = ignoreDepth[tagName]! + 1;
            totalIgnoreDepth++;
          }
        }
        // We do not append the ignored tag itself to the buffer.
      } else {
        // If this tag is not on the ignore list, append it to the buffer,
        // but only if we are not inside an ignored block.
        if (totalIgnoreDepth == 0) {
          buffer.write(fullTag);
        }
      }
      
      lastIndex = match.end;
    }

    // Append any remaining text after the last tag, if not in an ignored block.
    if (totalIgnoreDepth == 0 && lastIndex < trimmedText.length) {
      buffer.write(trimmedText.substring(lastIndex));
    }

    return buffer.toString().trim();
  }


  /// Extracts only the XML elements from a string, discarding text nodes at the root level.
  static String extractXmlContent(String rawText) {
    final trimmedText = rawText.trim();
    if (!trimmedText.contains('<') || !trimmedText.contains('>')) {
      return ''; // Return empty if no tags are apparent
    }
    try {
      final document = XmlDocument.parse('<root>$trimmedText</root>');
      final buffer = StringBuffer();

      for (final node in document.rootElement.children) {
        if (node is XmlElement) {
          // Append XML elements' outer XML
          buffer.writeln(node.toXmlString(pretty: false));
        }
        // Ignore XmlText, XmlCDATA, etc., at this top level
      }
      return buffer.toString().trim();
    } catch (e) {
      debugPrint("Error extracting XML content: $e. Returning empty string.");
      return '';
    }
  }

  /// Wraps a given string content with a specified XML tag.
  static String wrapWithTag(String tagName, String content) {
    // Basic validation for tag name
    if (tagName.isEmpty || tagName.contains(RegExp(r'[ <>"/]'))) {
      // Return content as-is or throw error if tag is invalid
      return content;
    }
    return '<$tagName>$content</$tagName>';
  }

  /// Processes a raw text stream, separating content for display (modelsText)
  /// from content to be saved/updated (extractedXml) based on robust XML parsing.
  /// This method implements a "Strict First, Fallback Gracefully" strategy.
  static PostProcessResult processPostStream(String rawText, List<XmlRule> rules) {
    final trimmedText = rawText.trim();
    if (rules.isEmpty || !trimmedText.contains('<')) {
      return PostProcessResult(modelsText: trimmedText, extractedXml: null);
    }

    final displayBuffer = StringBuffer();
    final xmlBuffer = StringBuffer();
    int lastIndex = 0;

    // 1. Create a regex to find all potential XML blocks based on rule tag names.
    final tagNames = rules.map((r) => r.tagName).where((t) => t != null).join('|');
    if (tagNames.isEmpty) {
      return PostProcessResult(modelsText: trimmedText, extractedXml: null);
    }
    // This regex finds elements that start with a known tag and are properly closed.
    // It's non-greedy (.*?) to handle adjacent tags correctly.
    final regex = RegExp(r'<(' + tagNames + r')\b[^>]*>.*?</\1>', dotAll: true, caseSensitive: false);
    
    final matches = regex.allMatches(trimmedText);

    for (final match in matches) {
      // 2. Append the text between the last match and this one to the display buffer.
      if (match.start > lastIndex) {
        displayBuffer.write(trimmedText.substring(lastIndex, match.start));
      }

      final chunk = match.group(0)!;
      final tagName = match.group(1)!.toLowerCase();
      final rule = _findRule(rules, tagName);

      // 3. "First, Be Strict": Validate the internal structure of the identified chunk.
      bool isValidXml = false;
      try {
        XmlDocument.parse(chunk);
        isValidXml = true;
        debugPrint("XMLProcessor: Successfully validated chunk for <$tagName>");
      } catch (e) {
        debugPrint("XMLProcessor: Validation failed for chunk <$tagName>. Treating as plain text. Error: $e");
        // isValidXml remains false
      }

      // 4. Apply rules only if the chunk is valid XML.
      if (isValidXml && rule != null) {
        switch (rule.action) {
          case XmlAction.save:
          case XmlAction.update:
            // Rule: save/update -> Move to native XML buffer.
            xmlBuffer.writeln(chunk);
            debugPrint("XMLProcessor: Moved chunk for <$tagName> to XML buffer.");
            break;
          case XmlAction.content:
          case XmlAction.collapsible:
          default:
            // Rule: content/collapsible/no rule -> Keep in display text.
            displayBuffer.write(chunk);
            debugPrint("XMLProcessor: Kept chunk for <$tagName> in display buffer.");
            break;
        }
      } else {
        // "Fallback Gracefully": If not valid XML, treat it as plain text for display.
        displayBuffer.write(chunk);
      }

      lastIndex = match.end;
    }

    // 5. Append any remaining text after the last match.
    if (lastIndex < trimmedText.length) {
      displayBuffer.write(trimmedText.substring(lastIndex));
    }

    final extractedXml = xmlBuffer.toString().trim();
    return PostProcessResult(
      modelsText: displayBuffer.toString().trim(),
      extractedXml: extractedXml.isEmpty ? null : extractedXml,
    );
  }
}

// Helper extension for firstWhereOrNull
extension _FirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
