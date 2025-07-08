import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:xml/xml.dart';

// Import models
// import '../models/models.dart'; // No longer needed for XmlRule, XmlAction if directly imported below
import '../data/database/drift/models/drift_xml_rule.dart'; // Import DriftXmlRule
import '../data/database/drift/common_enums.dart' as drift_enums; // Import Drift enums

// --- XML Processing Result Class ---
class XmlProcessResult {
  final String processedText; // Final text for display
  final String? carriedOverContent; // Serialized XML state (for save/update)

  XmlProcessResult({required this.processedText, this.carriedOverContent});
}

// --- XML Processor Class ---
class XmlProcessor {
  // Core processing method
  static XmlProcessResult process(
      String rawText,
      List<DriftXmlRule> rules, // Use DriftXmlRule
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
      List<DriftXmlRule> rules, // Use DriftXmlRule
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
        case drift_enums.XmlAction.save:
          final innerXmlToSave = node.innerXml.trim();
          if (innerXmlToSave.isNotEmpty) {
            currentCarriedOverMap[tagName] = innerXmlToSave; // Use original case 'tagName' as key
            debugPrint("XML save: <$tagName> (stored with key '$tagName')");
          } else {
            currentCarriedOverMap.remove(tagName); // Remove if content is empty
            debugPrint("XML save: <$tagName> (content empty, removed/not stored)");
          }
          // Don't process children as their content is included in innerXml
          break;

        case drift_enums.XmlAction.update:
          final currentInnerXml = node.innerXml.trim();
          
          // Find original key from previous map, case insensitively
          final String? originalKeyFromPrevious = previousCarriedOverMap.keys.firstWhereOrNull((k) => k.toLowerCase() == tagNameLower);
          final previousInnerXml = originalKeyFromPrevious != null ? previousCarriedOverMap[originalKeyFromPrevious] : null;

          debugPrint("XML update: <$tagName> (current element original case)");

          if (previousInnerXml != null && previousInnerXml.isNotEmpty) {
            try {
              final savedDoc = XmlDocument.parse('<root>$previousInnerXml</root>'); // previousInnerXml is already trimmed
              final updateDoc = XmlDocument.parse('<root>$currentInnerXml</root>'); // currentInnerXml is trimmed
              final mergedChildren = _mergeNodeLists(savedDoc.rootElement.children, updateDoc.rootElement.children);
              final tempMergedElement = XmlElement(XmlName('temp'), [], mergedChildren);
              final mergedTrimmedInnerXml = tempMergedElement.innerXml.trim();

              // Key for storage: use casing from previous map if it existed, otherwise current tag's casing.
              final String keyForStorage = originalKeyFromPrevious!; // Must exist if previousInnerXml was not null

              if (mergedTrimmedInnerXml.isNotEmpty) {
                currentCarriedOverMap[keyForStorage] = mergedTrimmedInnerXml;
                debugPrint("XML update successful for <$tagName>. Stored with key '$keyForStorage'.");
              } else {
                currentCarriedOverMap.remove(keyForStorage); // If merged result is empty, remove from map
                debugPrint("XML update successful for <$tagName> (merged to empty). Removed key '$keyForStorage'.");
              }
            } catch (e) {
              debugPrint("XML update failed for <$tagName> during parsing/merge: $e. Reverting to previous state for this tag if available.");
              // Preserve previous state for this tag using its original key
              if (originalKeyFromPrevious != null && previousCarriedOverMap.containsKey(originalKeyFromPrevious)) {
                 currentCarriedOverMap[originalKeyFromPrevious] = previousCarriedOverMap[originalKeyFromPrevious]!;
                 debugPrint("  Reverted to previous state for key '$originalKeyFromPrevious'.");
              } else {
                 // If no previous state under originalKeyFromPrevious, or it wasn't in map,
                 // ensure no entry for current 'tagName' if an optimistic add happened before error.
                 // This case (no previous state) should ideally be handled by the 'else' below,
                 // but this ensures robustness if error occurs after some map modification for 'tagName'.
                 currentCarriedOverMap.remove(tagName);
                 debugPrint("  No valid previous state to revert to for <$tagName>, ensured no entry for '$tagName'.");
              }
            }
          } else {
             // No previous state OR previous state was empty. Treat as save for current content.
             // Use current element's original casing 'tagName' as the key.
             if (currentInnerXml.isNotEmpty) {
                currentCarriedOverMap[tagName] = currentInnerXml;
                debugPrint("XML update (no previous state or previous was empty, acting as save for non-empty content): <$tagName> (stored with key '$tagName')");
             } else {
                // If current content is also empty, remove any existing entry for 'tagName' or ensure no new one is made.
                currentCarriedOverMap.remove(tagName);
                debugPrint("XML update (no previous state or previous was empty, current content also empty, no action/removed): <$tagName>");
             }
          }
          // Don't process children as their content is handled by the merge/save logic
          break;

        case drift_enums.XmlAction.ignore:
          debugPrint("XML ignore: <$tagName>");
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

  // --- Helper: Recursively merge two lists of nodes (for Update) ---
  // New logic: Map-based merge, adds new elements, ignores order for matching, keeps base attributes.
  // --- Helper: Recursively merge two lists of nodes (for Update) ---
  // New logic: Map-based merge, respects 'id' attribute, adds new elements, ignores order for matching.
  static List<XmlNode> _mergeNodeLists(List<XmlNode> baseNodes, List<XmlNode> updateNodes) {
    final List<XmlNode> mergedNodes = [];
    // Use a map for efficient lookup of update elements by a unique identifier.
    final Map<String, XmlElement> updateElementsMap = {
      for (var node in updateNodes.whereType<XmlElement>())
        _getElementIdentifier(node): node
    };
    final List<XmlNode> updateOtherNodes = updateNodes.where((n) => n is! XmlElement).toList();

    // Keep track of used update text/cdata nodes to avoid reusing them
    final Set<XmlNode> usedUpdateOtherNodes = {};

    // 1. Iterate through baseNodes and merge with/consume updateNodes
    for (final baseNode in baseNodes) {
      if (baseNode is XmlElement) {
        final baseIdentifier = _getElementIdentifier(baseNode);
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
  // Creates a unique identifier for an element, using its 'id' attribute if present.
  static String _getElementIdentifier(XmlElement element) {
    final id = element.getAttribute('id');
    if (id != null && id.isNotEmpty) {
      return '${element.name.local}#$id';
    }
    return element.name.local;
  }

  static DriftXmlRule? _findRule(List<DriftXmlRule> rules, String tagNameLower) { // Use DriftXmlRule
    // Use firstWhereOrNull for cleaner handling of not found cases
    return rules.firstWhereOrNull((r) => r.tagName?.toLowerCase() == tagNameLower);
  }

  // Parses the serialized carried-over XML string back into a map (No changes needed here)
  static Map<String, String> _parseCarriedOver(String? content) {
    Map<String, String> map = {};
    if (content == null || content.trim().isEmpty) return map;
    try {
      // Wrap content in a root element for safe parsing
      final doc = XmlDocument.parse('<carryRoot>${content.trim()}</carryRoot>');
      for (final node in doc.rootElement.children.whereType<XmlElement>()) {
        // Store original case tag name and its TRIMMED inner XML content
        final originalTagName = node.name.local;
        final innerXmlTrimmed = node.innerXml.trim();
        if (innerXmlTrimmed.isNotEmpty) { // Only store if content is not empty
          map[originalTagName] = innerXmlTrimmed;
        }
      }
    } catch (e) {
      debugPrint("Failed to parse previous carriedOverContent: $e. Content: '$content'. Returning empty map.");
      // Return empty map on parsing error
    }
    return map;
  }

  // Public wrapper for serialization (No changes needed here)
  static String? serializeCarriedOver(Map<String, String> map) {
    return _serializeCarriedOver(map);
  }

  // Serializes the state map back into an XML string for storage/carrying over
  static String? _serializeCarriedOver(Map<String, String> map) {
    if (map.isEmpty) return null;
    StringBuffer buffer = StringBuffer();
    const String specialCarryOverKey = "carry_over_xml_content"; // Key to treat specially

    map.forEach((key, value) {
      // Key is already original case. Value is already trimmed.
      if (value.isNotEmpty) { // Only process if value is not empty
        if (key == specialCarryOverKey) {
          // If the key is the special carry_over_xml_content key,
          // append its value directly without wrapping it in its own key tags.
          buffer.write('$value\n');
          debugPrint("XmlProcessor: Serializing content of '$specialCarryOverKey' directly.");
        } else {
          // For all other keys, wrap them as usual.
          // Ensure key is a valid XML tag name (basic check)
          if (key.isNotEmpty && !key.contains(RegExp(r'[ <>"/]'))) {
            buffer.write('<$key>$value</$key>\n');
          } else {
            debugPrint("XmlProcessor: Skipping serialization for invalid tag name: $key");
          }
        }
      }
    });
    final result = buffer.toString().trim();
    // Return null if the result is empty after trimming
    return result.isEmpty ? null : result;
  }

  // Simple min function utility (No longer used, can be removed if not used elsewhere)
  // static int min(int a, int b) => a < b ? a : b;

  /// Strips XML tags and their content from a string, returning only the text outside the tags.
  /// Uses XML parsing to handle structure correctly.
  static String stripXmlContent(String rawText) {
    // Trim the input first to handle leading/trailing whitespace
    final trimmedText = rawText.trim();
    // Basic check if the text likely contains any tags
    if (!trimmedText.contains('<') || !trimmedText.contains('>')) {
      return trimmedText; // Return trimmed text if no tags are apparent
    }
    try {
      // Wrap in a root element for robust parsing, even if rawText is just text or an XML fragment
      final document = XmlDocument.parse('<root>$trimmedText</root>');
      final buffer = StringBuffer();

      // Iterate through the direct children of the synthetic root element
      for (final node in document.rootElement.children) {
        if (node is XmlText) {
          // Append text nodes directly
          buffer.write(node.value);
        }
        // Ignore XmlElement nodes and their children in this context,
        // as we only want text *outside* the primary tags.
        // Also ignore comments, CDATA sections within the root for context building.
      }

      // Return the collected text, trimmed again to remove any potential whitespace
      // resulting from XML element removal.
      return buffer.toString().trim();

    } catch (e) {
      debugPrint("Error stripping XML content with XML parser: $e. Falling back to regex stripping.");
      // Fallback to regex-based stripping for incomplete chunks
      // This regex removes tag-like structures.
      // It replaces a matched tag with a space to preserve word separation, then trims.
      String strippedFallback = trimmedText.replaceAll(RegExp(r'<[^>]*>'), ' ');
      return strippedFallback.trim();
    }
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
