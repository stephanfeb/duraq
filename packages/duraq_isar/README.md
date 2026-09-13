# duraq_isar

The [Isar](https://pub.dev/packages/isar) storage backend for
[DuraQ](../duraq), the durable Dart queue.

It lives outside `duraq` so that a project using only the SQLite backend does not
resolve `isar` and its generated code, and is not held to `isar`'s version
constraint.

## Use

```yaml
dependencies:
  duraq: ^1.0.2
  duraq_isar: ^1.0.0
```

```dart
import 'package:duraq/duraq.dart';
import 'package:duraq_isar/duraq_isar.dart';

await Isar.initializeIsarCore(download: true);
final isar = await Isar.open([
  ...IsarStorage.requiredSchemas,
  // your other schemas
], directory: 'path/to/db');

final storage = IsarStorage(isar);
final queue = Queue<String>('emails', storage);

await queue.enqueue('welcome@example.com');
await queue.processNext(send);

await storage.close();  // releases locks; the caller still owns the Isar instance
await isar.close();
```

`IsarStorage` implements `StorageInterface`, so everything in the
[duraq README](../duraq/README.md) — retry policies, dead letters, scheduling,
maintenance, health checks — works the same way here.

## What is specific to this backend

- **The caller owns the Isar instance.** `IsarStorage.close()` releases the locks
  this storage holds and leaves the instance open, because you opened it and may
  be sharing it with the rest of your application.
- **Pass `IsarStorage.requiredSchemas`** rather than listing the collections by
  hand. The set grows — it gained a schema-version collection in 1.0.0 — and a
  hand-written list breaks the next time it does.
- **`removeDuplicateEntries()`** is a one-off cleanup for databases written by
  duraq 1.0.1 or earlier, which could store several rows for one entry. Run it
  once after upgrading.
- **Manual transactions throw.** An Isar write transaction takes its work as a
  callback, so `beginTransaction`/`commitTransaction`/`rollbackTransaction`
  cannot be honoured. Use `transaction()`.

## Development

This package is developed in the [DuraQ repository](https://github.com/stephanfeb/duraq).
`tool/verify.sh` at the repository root analyses and tests it alongside `duraq`.
Its suites are the contract suites from `duraq`, run against this backend.

Test concurrency is capped in `dart_test.yaml`: Isar holds a native database per
open instance, and at higher concurrency the test process is killed rather than
failing.
