import 'dart:io';

import 'package:duraq_isar/duraq_isar.dart';
import 'package:isar/isar.dart';
import 'package:test/test.dart';

import '../../duraq/test/support/queue_helpers.dart';
import 'support/isar_backend.dart';

/// The Isar half of the C4 and H1 reclaim tests. The SQLite half lives in
/// `duraq`, and both assert the same recovery behaviour.
void main() {
  group('Lease reclaim on IsarStorage', () {
    late IsarStorage storage;
    late Isar isar;
    late String tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('duraq_lease_isar_').path;
      await ensureIsarCore();
      isar = await Isar.open(
        IsarStorage.requiredSchemas,
        directory: tempDir,
        name: 'lease_test',
      );
      storage = IsarStorage(
        isar,
        leaseDuration: const Duration(milliseconds: 200),
      );
    });

    tearDown(() async {
      await storage.dispose();
      await isar.close();
      try {
        await Directory(tempDir).delete(recursive: true);
      } catch (_) {
        // Ignore cleanup errors
      }
    });

    test('an entry is not reclaimed while its lease is live', () async {
      await storage.store('test-queue', entry('e1'));

      expect((await storage.retrieve('test-queue'))?.id, equals('e1'));
      expect(await storage.retrieve('test-queue'), isNull);
      expect(await storage.reclaimStaleEntries(), equals(0));
    });

    test('an entry whose consumer died is handed out again', () async {
      await storage.store('test-queue', entry('e1'));
      expect((await storage.retrieve('test-queue'))?.id, equals('e1'));

      await Future<void>.delayed(const Duration(milliseconds: 300));

      final redelivered = await storage.retrieve('test-queue');
      expect(redelivered?.id, equals('e1'));
      expect(redelivered?.attempts, equals(1));
    });

    test('reclaim recovers stranded entries and reports the count', () async {
      await storage.store('test-queue', entry('e1'));
      await storage.retrieve('test-queue');
      expect(await storage.count('test-queue'), equals(0));

      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(await storage.reclaimStaleEntries(), equals(1));
      expect(await storage.count('test-queue'), equals(1));
    });
  });
}
