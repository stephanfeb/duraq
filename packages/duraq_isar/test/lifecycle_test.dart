import 'dart:io';

import 'package:duraq/duraq.dart';
import 'package:duraq_isar/duraq_isar.dart';
import 'package:test/test.dart';

import 'support/isar_backend.dart';

/// The Isar half of the M11 teardown tests. The SQLite half, and the durability
/// setting that is SQLite's alone, live in `duraq`.
void main() {
  group('backend-agnostic teardown', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('duraq_lifecycle_isar_');
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // Ignore cleanup errors
      }
    });

    QueueEntry<String> entry(String id) => QueueEntry<String>(
          id: id,
          data: 'payload-$id',
          createdAt: DateTime.now(),
        );

    /// Shutdown written once, against the interface.
    Future<void> shutDown(StorageInterface storage) => storage.close();

    test('an Isar storage closes through the interface', () async {
      await ensureIsarCore();
      final isar = await openTestIsar(directory: tempDir.path, name: 'lifecycle_test');
      addTearDown(isar.close);

      final storage = IsarStorage(isar);
      await storage.store('q', entry('e1'));

      await shutDown(storage);

      await expectLater(storage.count('q'), throwsStateError);
      expect(isar.isOpen, isTrue,
          reason: 'the caller opened the Isar instance and still owns it');
    });
  });
}
