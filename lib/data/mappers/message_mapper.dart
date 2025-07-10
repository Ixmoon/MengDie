import 'dart:convert';
import 'package:drift/drift.dart';

import '../models/message.dart' as domain;
import '../database/app_database.dart' as drift;

class MessageMapper {
  static domain.Message fromData(drift.MessageData data) {
    List<domain.MessagePart> parts = [];
    if (data.partsJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(data.partsJson);
        parts = decoded.map((json) => domain.MessagePart.fromJson(json)).toList();
      } catch (e) {
        parts = [domain.MessagePart.text(data.partsJson)];
      }
    }

    if (parts.isEmpty) {
      parts.add(domain.MessagePart.text(''));
    }

    return domain.Message(
      id: data.id,
      chatId: data.chatId,
      parts: parts,
      role: data.role,
      timestamp: data.timestamp,
      originalXmlContent: data.originalXmlContent,
      secondaryXmlContent: data.secondaryXmlContent,
    );
  }

  static drift.MessagesCompanion toCompanion(domain.Message message) {
    final String partsJson = jsonEncode(message.parts.map((p) => p.toJson()).toList());
    
    return drift.MessagesCompanion(
      id: message.id == 0 ? const Value.absent() : Value(message.id),
      chatId: Value(message.chatId),
      partsJson: Value(partsJson),
      role: Value(message.role),
      timestamp: Value(message.timestamp),
      originalXmlContent: Value(message.originalXmlContent),
      secondaryXmlContent: Value(message.secondaryXmlContent),
    );
  }
}