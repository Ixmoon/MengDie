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
              final mergedChildren = _mergeNodeLists(previousElement.children, node.children);
              
              // Create the new merged element, preserving the original's name and attributes
              final mergedElement = XmlElement(
                previousElement.name.copy(),
                previousElement.attributes.map((a) => a.copy()),
                mergedChildren,
              );
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

  // --- Helper: Recursively merge two lists of nodes (for Update) ---
  // New logic: Map-based merge, adds new elements, ignores order for matching, keeps base attributes.
  // --- Helper: Recursively merge two lists of nodes (for Update) ---
  // New logic: Map-based merge, respects 'id' attribute, adds new elements, ignores order for matching.
  static List<XmlNode> _mergeNodeLists(List<XmlNode> baseNodes, List<XmlNode> updateNodes) {
    final List<XmlNode> mergedNodes = [];
    // Use a map for efficient lookup of update elements by a unique identifier.
    final Map<String, XmlElement> updateElementsMap = {
      for (var node in updateNodes.whereType<XmlElement>())
        getElementIdentifier(node): node
    };
    final List<XmlNode> updateOtherNodes = updateNodes.where((n) => n is! XmlElement).toList();

    // Keep track of used update text/cdata nodes to avoid reusing them
    final Set<XmlNode> usedUpdateOtherNodes = {};
// 1. Iterate through baseNodes and merge with/consume updateNodes
for (final baseNode in baseNodes) {
  if (baseNode is XmlElement) {
    final baseIdentifier = getElementIdentifier(baseNode);
    final matchingUpdateElement = updateElementsMap[baseIdentifier];


        if (matchingUpdateElement != null) {
          // Found a matching update element, consume it from the map.
          updateElementsMap.remove(baseIdentifier);

          // Recursively merge children.
          final mergedChildren = _mergeNodeLists(baseNode.children, matchingUpdateElement.children);
          // Create merged element: keep base name and attributes, use merged children.
          mergedNodes.add(XmlElement(
            baseNode.name.copy(),
            baseNode.attributes.map((a) => a.copy()), // Keep base attributes
            mergedChildren,
          ));
        } else {
          // No matching update element found, keep the base node.
          mergedNodes.add(baseNode.copy());
        }
      } else if (baseNode is XmlText || baseNode is XmlCDATA) {
        // This logic attempts to replace a text node with a corresponding one from the update list.
        // It's heuristic and might not be perfect for all cases.
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
    for (final newElement in updateElementsMap.values) {
      mergedNodes.add(newElement.copy());
    }

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
  // It uses the value of the *first* attribute found, regardless of its name (e.g., id, Name, uuid).
  static String getElementIdentifier(XmlElement element) {
    if (element.attributes.isNotEmpty) {
      // Use the value of the first attribute as the unique part of the identifier.
      final firstAttrValue = element.attributes.first.value;
      if (firstAttrValue.isNotEmpty) {
        return '${element.name.local}#$firstAttrValue';
      }
    }
    // If no attributes or the first attribute has an empty value, fall back to just the tag name.
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

  // Serializes the state map back into a single XML string for storage.
  static String? _serializeCarriedOver(Map<String, String> map) {
    if (map.isEmpty) return null;
    // The values in the map are already complete XML strings.
    // We just need to join them together.
    final result = map.values.join('\n');
    return result.isEmpty ? null : result;
  }

  // Simple min function utility (No longer used, can be removed if not used elsewhere)
  // static int min(int a, int b) => a < b ? a : b;

  /// Strips XML tags and their content from a string, returning only the text outside the tags.
  /// Uses a robust method that first tries strict parsing and falls back to a more lenient approach.
  static String stripXmlContent(String rawText) {
    final trimmedText = rawText.trim();
    if (!trimmedText.contains('<') || !trimmedText.contains('>')) {
      return trimmedText;
    }

    // --- First Pass: Strict XML Parsing ---
    // This is the most accurate way to strip content if the XML is well-formed.
    try {
      final document = XmlDocument.parse('<root>$trimmedText</root>');
      final buffer = StringBuffer();
      for (final node in document.rootElement.children) {
        if (node is XmlText) {
          buffer.write(node.value);
        }
      }
      return buffer.toString().trim();
    } catch (e) {
      debugPrint("Error stripping XML with strict parser: $e. Falling back to robust regex stripping.");
      // --- Fallback: Robust Regex-based Stripping ---
      // This regex finds all occurrences of <tag>...</tag> and removes them.
      // It's non-greedy and handles nested tags within the outer tag being removed.
      String result = trimmedText;
      final tagNames = RegExp(r'<(\w+)[^>]*>').allMatches(trimmedText).map((m) => m.group(1)!).toSet();

      for (final tagName in tagNames) {
        final regex = RegExp(r'<' + tagName + r'\b[^>]*>.*?</' + tagName + r'>', dotAll: true, caseSensitive: false);
        result = result.replaceAll(regex, ' ');
      }
      // Final cleanup for any remaining stray tags.
      result = result.replaceAll(RegExp(r'<[^>]+>'), ' ');
      return result.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
  }

  /// Strips only the XML tags that have an 'ignore' rule, returning all other text and XML.
  /// This method is robust and handles incomplete or malformed XML gracefully.
  static String stripIgnoredXmlContent(String rawText, List<XmlRule> rules) {
    final trimmedText = rawText.trim();
    if (!trimmedText.contains('<') || !trimmedText.contains('>')) {
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

    // Regex to find all well-formed, complete tags (either self-closing or with a matching closing tag).
    final tagRegex = RegExp(r'<(\w+)\b[^>]*?(?:\/>|>(?:.|\s)*?<\/\1>)', dotAll: true, caseSensitive: false);

    for (final match in tagRegex.allMatches(trimmedText)) {
      // Append the text between the last match and this one.
      buffer.write(trimmedText.substring(lastIndex, match.start));
      
      final tagName = match.group(1)!.toLowerCase();
      
      // If the found tag is NOT in the ignored set, append it to the buffer.
      if (!ignoredTags.contains(tagName)) {
        buffer.write(match.group(0)!);
      }
      
      lastIndex = match.end;
    }

    // Append any remaining text after the last complete tag.
    // This ensures incomplete tags at the end are preserved.
    if (lastIndex < trimmedText.length) {
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
