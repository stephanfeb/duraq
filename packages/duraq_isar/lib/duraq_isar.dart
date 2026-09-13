/// Isar storage backend for DuraQ.
///
/// Lives outside `duraq` so that a project using only the SQLite backend does
/// not resolve `isar` and its generated code. Everything else — queues, retry
/// policies, dead letters, health checks — comes from `package:duraq/duraq.dart`,
/// which this package does not replace:
///
/// ```dart
/// import 'package:duraq/duraq.dart';
/// import 'package:duraq_isar/duraq_isar.dart';
///
/// final isar = await Isar.open(IsarStorage.requiredSchemas, directory: dir);
/// final storage = IsarStorage(isar);
/// final manager = QueueManager(storage);
/// ```
library duraq_isar;

// Exported whole: the generated part file defines the collection schemas
// and the `isar.queueEntryCollections` extensions, which callers need to
// open Isar and which a `show` list would hide.
export 'src/isar_models.dart';
export 'src/isar_storage.dart';
