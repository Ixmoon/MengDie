import 'package:drift/drift.dart';
import 'chats.dart'; // To define the foreign key relationship
import '../type_converters.dart'; // For MessageRoleConverter

// Drift table for Messages
@DataClassName('MessageData') // To avoid conflict with existing Message model
class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  
  // Foreign key to the Chats table
  IntColumn get chatId => integer().references(Chats, #id)(); 
  
  TextColumn get rawText => text().named('raw_text')(); // Mapped from DTO, stores parts as JSON
  TextColumn get role => text().map(const MessageRoleConverter())();
  DateTimeColumn get timestamp => dateTime()();

  // Stores the original XML content if it was overwritten by post-processing
  TextColumn get originalXmlContent => text().nullable()();
 
  // Stores the XML content from secondary generation
  TextColumn get secondaryXmlContent => text().nullable()();
 
  // autoIncrement() on id column automatically makes it the primary key.
}
