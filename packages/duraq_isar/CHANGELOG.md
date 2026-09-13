# Changelog

## [2.0.0] - 2026-09-14

Tracks `duraq` 3.0.0: an entry id now identifies an entry **within its queue**,
rather than across the whole database.

### Upgrading from 1.0.x

**1. Move both packages together.** This release requires `duraq` 3.0.0.

```yaml
dependencies:
  duraq: ^3.0.0
  duraq_isar: ^2.0.0
```

**2. Check whether you relied on ids being unique across the database.** `store`
no longer searches every queue for the id before writing, so two queues may each
hold `order-42`. See the `duraq` 3.0.0 notes for what that affects.

**3. Back up the database if you may need to roll back.** The first open records
schema version 2, and duraq_isar 1.x will then refuse the database with a
`SchemaVersionException`. Nothing in the file is rewritten — version 1 refused
to store an id another queue held, so no version 1 database can contain anything
the new rule disallows. The version exists purely so that an older release stops
rather than opening a database whose entries it would misread: 1.x would treat a
second queue's `order-42` as a duplicate of the first and delete it under
`StoreConflict.replace`.

**4. Nothing else changes.** `Isar.open` still takes
`...IsarStorage.requiredSchemas`, and the collection set is unchanged.

### Breaking
- **An entry id is now unique within its queue, not across the whole
  database**, matching the change in `duraq`. `store` no longer searches every
  queue for the id before writing, so two queues may each hold `order-42`.
  Requires `duraq` 3.0.0.

- The Isar schema is at version 2. Nothing in a version 1 database needs
  rewriting — version 1 refused to store an id another queue held, so no such
  database can contain anything the new rule disallows. The version is recorded
  so that an older release *refuses* the database rather than opening it: a
  version 2 database may hold `order-42` in two queues, and duraq_isar 1.x
  would treat the second as a duplicate of the first and delete it under
  `StoreConflict.replace`.

### Changed
- `QueueEntryCollection.entryId` is no longer indexed on its own. The only
  query that used that index was the cross-queue lookup this release removes;
  identity goes through the `entryKey` index, which already covers the queue
  name and the id together. Isar applies the change when it next opens the
  database.

## [1.0.0] - 2026-09-14

First release as a separate package.

The Isar backend was part of `duraq` up to 1.0.1. It moves here so that a
project using only the SQLite backend does not resolve `isar`, its generated
code, or its version constraint.

### Migrating from duraq 1.0.1

Add the dependency and change one import:

```yaml
dependencies:
  duraq: ^2.0.0
  duraq_isar: ^1.0.0
```

```dart
import 'package:duraq/duraq.dart';
import 'package:duraq_isar/duraq_isar.dart';   // add this
```

`IsarStorage` and the collection schemas are unchanged in behaviour, and
existing databases open as they are. Everything else — `Queue`, `QueueManager`,
retry policies, dead letters, health checks — still comes from `duraq`.

### Included from the duraq 1.0.2 work

This package carries the Isar half of the durability fixes released in duraq
2.0.0, which are described in that package's changelog: single-row entry
identity, real transactions, index use, lease reclaim and ownership, retry
timing, maintenance and retention, schema versioning, and ready counts.
