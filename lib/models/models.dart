// 导出模型文件，方便统一导入。
export 'enums.dart';
export 'collection_models.dart';

// -- Re-exporting Drift-generated data classes for wider use --
// This allows other layers (like UI) to import data models from a single,
// consistent location ('package:*/models/models.dart') without directly
// depending on the database layer's file structure.
export '../database/app_database.dart' show ApiConfig;
export '../database/models/drift_xml_rule.dart' show DriftXmlRule;


// Isar 代码生成需要这个 part 指令。
// 运行 `flutter pub run build_runner build` 来生成此文件。
