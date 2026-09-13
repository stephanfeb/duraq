import 'dart:io';

import 'package:duraq/duraq.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// Regression tests for M3.
///
/// `Queue<T>` promised "any data type" and delivered whatever `jsonEncode`
/// happens to accept. A domain object failed at enqueue with
/// `JsonUnsupportedObjectError` raised from inside the storage, and a queue
/// read through the wrong type failed with a bare `TypeError` naming neither
/// the queue nor the payload. A codec makes the boundary explicit and lifts it.

/// A payload `jsonEncode` cannot represent on its own.
class Invoice {
  final String customer;
  final int cents;

  const Invoice(this.customer, this.cents);

  @override
  bool operator ==(Object other) =>
      other is Invoice && other.customer == customer && other.cents == cents;

  @override
  int get hashCode => Object.hash(customer, cents);

  @override
  String toString() => 'Invoice($customer, $cents)';
}

QueueCodec<Invoice> invoiceCodec() => QueueCodec<Invoice>.from(
      encode: (invoice) => {
        'customer': invoice.customer,
        'cents': invoice.cents,
      },
      decode: (stored) {
        final map = stored! as Map<String, dynamic>;
        return Invoice(map['customer'] as String, map['cents'] as int);
      },
    );

void main() {
  late SQLiteStorage storage;
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('duraq_codec_');
    storage = SQLiteStorage(dbPath: path.join(tempDir.path, 'duraq_test.db'));
  });

  tearDown(() {
    storage.dispose();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('a queue with a codec', () {
    test('round-trips a payload jsonEncode cannot represent', () async {
      final queue = Queue<Invoice>('invoices', storage, codec: invoiceCodec());
      await queue.enqueue(const Invoice('acme', 1999));

      expect(await queue.dequeue(), equals(const Invoice('acme', 1999)));
    });

    test('hands the processor a decoded payload', () async {
      final queue = Queue<Invoice>('invoices', storage, codec: invoiceCodec());
      await queue.enqueue(const Invoice('globex', 250));

      Invoice? seen;
      await queue.processNext((invoice) => seen = invoice);

      expect(seen, equals(const Invoice('globex', 250)));
    });

    test('encodes a pre-built entry too', () async {
      final queue = Queue<Invoice>('invoices', storage, codec: invoiceCodec());
      await queue.enqueueEntry(QueueEntry<Invoice>(
        id: 'inv-1',
        data: const Invoice('initech', 7),
        createdAt: DateTime.now(),
        priority: 2,
      ));

      final stored = (await storage.retrieveAll('invoices')).single;
      expect(stored.data, isA<Map<String, dynamic>>(),
          reason: 'the storage holds the encoded form');
      expect(stored.priority, equals(2), reason: 'other fields survive');
      expect(await queue.dequeue(), equals(const Invoice('initech', 7)));
    });

    test('decodes dead letters through the same codec', () async {
      final queue = Queue<Invoice>('invoices', storage, codec: invoiceCodec());
      await queue.enqueue(const Invoice('hooli', 42));
      await expectLater(
        queue.processNext((_) => throw StateError('boom')),
        throwsStateError,
      );

      final dead = DeadLetterQueue<Invoice>(
        'invoices',
        storage,
        codec: invoiceCodec(),
      );
      expect((await dead.retrieve())?.data, equals(const Invoice('hooli', 42)));
      expect((await dead.list()).single.data,
          equals(const Invoice('hooli', 42)));
    });
  });

  group('without a codec', () {
    test('an unencodable payload names the type and the way out', () async {
      final queue = Queue<Invoice>('invoices', storage);

      await expectLater(
        queue.enqueue(const Invoice('acme', 1)),
        throwsA(
          isA<PayloadCodecException>()
              .having((e) => e.payloadType, 'payloadType', Invoice)
              .having((e) => e.queueName, 'queueName', 'invoices')
              .having((e) => e.message, 'message', contains('QueueCodec'))
              .having((e) => e.cause, 'cause', isNotNull),
        ),
      );
    });

    test('reading a queue as the wrong type names both types', () async {
      await Queue<String>('mixed', storage).enqueue('hello');

      await expectLater(
        Queue<int>('mixed', storage).dequeue(),
        throwsA(
          isA<PayloadCodecException>()
              .having((e) => e.message, 'message', contains('String'))
              .having((e) => e.message, 'message', contains('int')),
        ),
      );
    });

    test('a JSON-friendly payload still needs nothing', () async {
      final queue = Queue<Map<String, dynamic>>('plain', storage);
      await queue.enqueue({'id': 7, 'tags': ['a', 'b']});

      expect(await queue.dequeue(), equals({'id': 7, 'tags': ['a', 'b']}));
    });
  });

  group('when a codec fails', () {
    test('an encode that returns something unencodable is reported', () async {
      final queue = Queue<Invoice>(
        'invoices',
        storage,
        codec: QueueCodec<Invoice>.from(
          encode: (invoice) => invoice, // still not JSON
          decode: (stored) => stored! as Invoice,
        ),
      );

      await expectLater(
        queue.enqueue(const Invoice('acme', 1)),
        throwsA(isA<PayloadCodecException>()
            .having((e) => e.message, 'message', contains('codec'))),
      );
    });

    test('a decode that throws leaves the entry in the queue', () async {
      var healthy = false;
      final queue = Queue<Invoice>(
        'invoices',
        storage,
        codec: QueueCodec<Invoice>.from(
          encode: (invoice) => invoice.cents,
          decode: (stored) {
            if (!healthy) throw const FormatException('cannot read that');
            return Invoice('recovered', stored! as int);
          },
        ),
      );
      await queue.enqueue(const Invoice('acme', 99));

      await expectLater(
        queue.dequeue(),
        throwsA(isA<PayloadCodecException>()
            .having((e) => e.cause, 'cause', isA<FormatException>())),
      );

      // dequeue deletes the entry it hands out, so decoding has to happen
      // inside that transaction: a codec that throws must not destroy the
      // payload on its way past.
      final stranded = await storage.retrieveAll('invoices');
      expect(stranded, hasLength(1));
      expect(stranded.single.status, equals(EntryStatus.pending));

      healthy = true;
      expect(await queue.dequeue(), equals(const Invoice('recovered', 99)));
    });
  });

  group('QueueCodec.from', () {
    test('applies the functions it was given', () {
      final codec = QueueCodec<Invoice>.from(
        encode: (invoice) => '${invoice.customer}:${invoice.cents}',
        decode: (stored) {
          final parts = (stored! as String).split(':');
          return Invoice(parts.first, int.parse(parts.last));
        },
      );

      expect(codec.encode(const Invoice('acme', 5)), equals('acme:5'));
      expect(codec.decode('acme:5'), equals(const Invoice('acme', 5)));
    });
  });
}
