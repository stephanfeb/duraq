# Changelog

## [1.0.0]

First release as a separate package.

The Isar backend was part of `duraq` up to 1.0.1. It moves here so that a
project using only the SQLite backend does not resolve `isar`, its generated
code, or its version constraint.

### Migrating from duraq 1.0.1

Add the dependency and change one import:

```yaml
dependencies:
  duraq: ^1.0.2
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
1.0.2, which are described in that package's changelog: single-row entry
identity, real transactions, index use, lease reclaim and ownership, retry
timing, maintenance and retention, schema versioning, and ready counts.
