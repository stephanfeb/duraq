import 'dart:io';

import 'package:duraq/duraq.dart';
import 'package:duraq_isar/duraq_isar.dart';
import 'package:isar/isar.dart';
import 'package:test/test.dart';

import 'support/isar_backend.dart';

/// The Isar half of the M13 schema-version tests. The migration runner itself
/// and the SQLite half live in `duraq`.
void main() {
  group('IsarStorage schema version', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('duraq_schema_isar_');
      await ensureIsarCore();
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // Ignore cleanup errors
      }
    });

    // Takes its own schema list, so it cannot use openTestIsar — one test here
    // opens with the schema set that shipped before the version collection
    // existed. The size cap is the same, and for the same reason.
    Future<Isar> open(String name,
            {List<CollectionSchema<dynamic>>? schemas}) async =>
        Isar.open(
          schemas ?? IsarStorage.requiredSchemas,
          directory: tempDir.path,
          name: name,
          maxSizeMiB: 32,
        );

    /// The schema set that shipped before the version collection existed.
    final previousSchemas = [
      QueueCollectionSchema,
      QueueEntryCollectionSchema,
      QueueLockCollectionSchema,
    ];

    test('a new database records the current version on first use', () async {
      final isar = await open('fresh');
      final storage = IsarStorage(isar);
      addTearDown(() async {
        await storage.dispose();
        await isar.close();
      });

      await storage.store(
        'q',
        QueueEntry<String>(id: 'e1', data: 'x', createdAt: DateTime.now()),
      );

      expect(await storage.storedSchemaVersion(),
          equals(IsarStorage.schemaVersion));
    });

    test('a database written before the version collection existed still opens',
        () async {
      // Written by the previous release: its collections, its data, no version.
      var isar = await open('upgrade', schemas: previousSchemas);
      await isar.writeTxn(() async {
        await isar.queueCollections.put(QueueCollection()
          ..name = 'q'
          ..createdAt = DateTime.now()
          ..lastUpdatedAt = DateTime.now());
        await isar.queueEntryCollections.put(QueueEntryCollection()
          ..entryId = 'e1'
          ..queueName = 'q'
          ..data = '"payload"'
          ..createdAt = DateTime.now()
          ..lastUpdatedAt = DateTime.now()
          ..attempts = 0
          ..priority = 0
          ..status = EntryStatus.pending);
      });
      await isar.close();

      isar = await open('upgrade');
      final storage = IsarStorage(isar);
      addTearDown(() async {
        await storage.dispose();
        await isar.close();
      });

      expect((await storage.retrieveAll('q')).single.data, equals('payload'));
      expect(await storage.storedSchemaVersion(), equals(1));
      expect((await storage.retrieve('q'))?.id, equals('e1'),
          reason: 'the queue still serves work after the upgrade');
    });

    test('a database from a newer DuraQ is refused, on every operation',
        () async {
      final isar = await open('future');
      await isar.writeTxn(() => isar.queueMetaCollections.put(
            QueueMetaCollection()
              ..id = metaRowId
              ..schemaVersion = 99
              ..updatedAt = DateTime.now(),
          ));

      final storage = IsarStorage(isar);
      addTearDown(() async {
        await storage.dispose();
        await isar.close();
      });

      await expectLater(
        storage.count('q'),
        throwsA(isA<SchemaVersionException>()
            .having((e) => e.found, 'found', 99)),
      );
      await expectLater(
        storage.retrieveAll('q'),
        throwsA(isA<SchemaVersionException>()),
      );
    });

    test('an instance opened without the version collection says so', () async {
      final isar = await open('handwritten', schemas: previousSchemas);
      final storage = IsarStorage(isar);
      addTearDown(() async {
        await storage.dispose();
        await isar.close();
      });

      await expectLater(
        storage.count('q'),
        throwsA(isA<DuraQException>().having(
          (e) => e.message,
          'message',
          contains('requiredSchemas'),
        )),
      );
    });
  });
}
