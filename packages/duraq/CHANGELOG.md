# Changelog

All notable changes to DuraQ will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- The health check API is now exported from `package:duraq/duraq.dart`.
  `HealthCheck`, `StorageHealthCheck`, `MetricsHealthCheck`,
  `QueueHealthCheck`, `HealthCheckAggregator`, `HealthStatus` and
  `HealthCheckResult` were documented in the README but never exported, so
  following the README gave "Method not found". The existing tests passed only
  because they imported the `src/` path directly.
- `QueueHealthCheck` now reports on the queues that exist. It asked the metrics
  collector for the size of a queue called `default`, a name nothing in the
  system used, so the figure was zero unless a caller happened to record one
  there. It now reads every queue from the storage — or the ones named in the
  new `queueNames` — and reports what is waiting and what is ready per queue.
- `MetricsHealthCheck` no longer probes a queue called `health-check`, which
  nothing used either. It reads the figures the collector holds for the system
  as a whole and reports them.
- `ExponentialBackoff.getRetryDelay()` no longer overflows. The delay was
  `baseDelay.inMilliseconds * pow(2, attempts)` in integer arithmetic, which
  wraps a 64-bit int at attempt 63. `maxDelay` could not catch the wrapped
  value, so attempt 58 scheduled a retry roughly 60,000 years out, and from
  attempt 64 every delay came out zero — backoff became a tight retry loop.
  The delay is now computed in floating point and capped before jitter, so it
  is never negative, never zero, and never above `maxDelay` at any attempt
  count.
- Jitter now applies after the cap rather than before it. Previously every
  attempt at or past the ceiling returned exactly `maxDelay` with no spread at
  all, which is the point in a backoff where spreading retries matters most.
  Delays at the ceiling now land between 75% and 100% of `maxDelay`.
- `updateEntryStatus()` no longer clears fields the caller did not mention.
  Every update wrote `error_message` and `next_retry_at`, using null when they
  were not supplied, so completing an entry erased the error that explained its
  last failure and any status change dropped a pending retry time. Fields left
  out now keep their stored values, with one deliberate exception: moving an
  entry to `pending` without a retry time clears the backoff, because that is
  what making an entry available again means.
- Dead lettered and expired entries now release their claim. The lock was
  released for `completed`, `failed` and `pending` only, so an entry kept its
  lease for the rest of its duration after the work was over. The visible
  symptom was `retryDeadLetter()` appearing to do nothing: the entry went back
  to pending still locked by the claim it died under, and the scan skipped it
  until the lease ran out.
- Lock ids are now unique per acquisition. They were built from the queue name,
  the entry id and the clock in milliseconds, so two claims of the same entry
  inside one millisecond produced the same id, and a consumer holding the older
  one was accepted as the current holder — defeating the ownership check that
  exists to stop exactly that. Found by a test that flaked once in three runs.
- Taking a lock no longer reports every failure as contention. Any exception
  during the insert answered "the entry is already locked", so a broken schema,
  a failing disk, or a database that went away moved the scan on to the next
  candidate and made a failing storage look like an empty queue. Only a real
  conflict — a primary key collision on SQLite, a unique index violation on
  Isar — now means locked; everything else is raised.
- `dequeue()` now removes the entry it returns. It previously claimed the entry
  and handed back the payload with no way to acknowledge it, leaving the row in
  `processing`; once the lease expired the entry was handed out again, so every
  dequeued item came back. The claim and the delete now happen in one
  transaction. That makes `dequeue()` at-most-once: use `processNext()`, which
  is unchanged, when an item must not be lost.
- `QueueManager.queue<T>()` no longer throws a cast error when a queue is asked
  for under a second element type. The cache was keyed by name alone, so the
  first caller's type won for the life of the process and a queue first touched
  untyped could never be fetched typed. Queues are now cached per name *and*
  type, so a worker reading `Invoice` and an admin tool reading `dynamic` can
  share one queue.
- Removing an entry now releases its lock. A deleted id stayed marked as claimed
  until its lease ran out, so the same id could not be enqueued and picked up
  again in that window.
- Concurrent calls to `SQLiteStorage.transaction()` no longer nest inside one
  another. Previously two overlapping transactions shared a single depth
  counter, so one caller's rollback discarded another caller's committed rows
  while that caller still reported success.
- Concurrent calls to `SQLiteStorage.retrieve()` no longer return null while
  entries are still pending. Ten parallel consumers against five entries now
  receive all five, each exactly once.
- Retry delays are now honoured. Both backends exclude an entry from retrieval
  until its `nextRetryAt` has passed, so `ExponentialBackoff` and any other
  `RetryPolicy` take effect instead of a failed entry being re-delivered
  immediately. Measured cost of the added predicate is 0.44 microseconds.
- `SQLiteStorage.store()` now persists `nextRetryAt`. The column was missing
  from the insert, so a pre-built entry lost its retry time silently.
- The Isar backend no longer stores one row per `store` call. `entryId` carried
  a non-unique index next to an auto-incrementing key, so storing the same
  entry twice created a second row, counted it twice, and handed the same
  payload to a processor twice. `store` now upserts through an entry identity
  index.
- `IsarStorage.transaction()` now provides atomicity. The body runs in a single
  Isar write transaction and operations called inside it join that transaction,
  so a body that throws leaves nothing behind. Previously each write committed
  on its own and a failure halfway left the earlier writes in place.
- Two processes sharing one SQLite file no longer fail each other's writes. The
  busy timeout was left at zero, so a second writer got an immediate "database
  is locked" instead of waiting its turn. Two processes doing 300 enqueues and
  50 claims each now complete with no failures, where 47 of 300 enqueues failed
  before.
- Switching a new database file to write-ahead logging no longer crashes when
  two processes open it at the same moment. That switch needs an exclusive lock
  and does not go through the busy handler, so it is retried briefly and then
  accepts the mode the file is in.
- `dispose()` no longer throws when another connection holds the write lock. It
  released its locks through a future whose failure nothing handled, so a
  contended shutdown surfaced as an unhandled exception.
- Entries are no longer stranded when a consumer dies. An entry left in
  `processing` with no live lock is returned to the queue on the next
  retrieval, so a crash, a kill, or a `dequeue()` that is never acknowledged no
  longer loses the job. Both backends.
- A consumer whose lease expired can no longer finish an entry that has since
  been given to someone else. Claims carry a lease id now: `retrieve` returns it
  on the entry, `updateEntryStatus` takes it, and a status change made against a
  lease that is no longer the live one is discarded rather than applied over the
  work of whoever holds the entry. `Queue.processNext` passes it for you. The
  lock id had been generated and returned since the beginning and then kept by
  nobody, so release deleted whatever lock was on the entry.
- `dispose()` no longer releases locks held by other consumers. The release was
  an unfiltered delete over the lock table, so one process shutting down freed
  every in-flight entry in the database, including entries other processes were
  still working on. Each lock manager now tracks and releases only its own.

### Breaking
- The declared SDK floor moves from `>=3.0.0` to `>=3.2.0`. This corrects a
  claim rather than dropping support: `sqlite3` 2.2.0, the oldest this package
  allows, itself requires 3.2.0, so `duraq` could never have resolved on 3.0 or
  3.1. Found by the CI job that builds on the advertised floor.
- **The Isar backend moved to its own package, `duraq_isar`.** A project using
  only SQLite no longer resolves `isar`, its generated code, or its version
  constraint — which was the point: `isar` is pinned to 3.1.0+1, whose generated
  code raises analyzer warnings on current Dart. Projects using Isar add
  `duraq_isar` to their pubspec and one import; `IsarStorage` behaves as before
  and existing databases open unchanged. See that package's changelog.
- `StorageInterface` gained `close()`. Custom backends must declare it; both
  built-in backends delegate to their existing `dispose()`.
- `StorageInterface` gained `countReady()`. Custom backends must declare it;
  the interface's default body filters `retrieveAll`, which is correct but
  reads every entry, so a real backend should answer with a query.
- `IsarStorage.requiredSchemas` now includes `QueueMetaCollectionSchema`.
  Callers already passing `...IsarStorage.requiredSchemas` to `Isar.open` need
  no change and their databases upgrade in place. A caller that listed DuraQ's
  collections by hand must add it; doing so raises a `DuraQException` naming the
  fix rather than Isar's own `Missing TypeSchema`, which names neither the
  collection nor what to do.
- `updateEntryStatus()` now throws `EntryNotFoundException` when no entry with
  that id is in the queue. It previously reported success, so a typo, a stale
  id, or an entry already removed by a retention pass all looked like work
  completing normally. A change discarded because the caller's lease expired
  still returns quietly: the entry exists and someone else holds the claim.
- `StorageInterface.store()` takes a new `onConflict` parameter,
  `updateEntryStatus()` takes a new `leaseId` parameter, and `StorageInterface`
  gained `runMaintenance()`. Custom backends must add all three.
  Dart's `implements` copies only signatures, so the default `runMaintenance`
  body does not reach a class that implements the interface rather than
  extending it.
- Storing an entry whose id is already in the storage now throws
  `DuplicateEntryException` on every backend. SQLite previously threw a raw
  `SqliteException` carrying the failing statement and its parameters, which
  put the entry payload into the error text; Isar silently added a second row.
  Pass `StoreConflict.replace` or `StoreConflict.ignore` where a repeated store
  is expected.
- `IsarStorage.beginTransaction()`, `commitTransaction()` and
  `rollbackTransaction()` now throw `UnsupportedError`. Isar write transactions
  take their work as a callback, so a transaction cannot be opened in one call
  and closed in another. Previously these moved a counter and guaranteed
  nothing: work done between them was already committed, and a rollback
  discarded nothing. Use `transaction()`, which now runs the whole body in one
  Isar write transaction.
- The Isar schema changed: indexes that no queries used were removed, and
  indexes matching the queries this package runs were added. Existing databases
  open and migrate on their own; no action is needed beyond the duplicate
  cleanup below.

### Performance
- Dequeue no longer slows down as the backlog grows. The per-queue expiry sweep
  on the retrieval path could not use the partial expiry index and fell back to
  scanning every pending entry in the queue. A `(queue_name, expires_at)`
  partial index turns it into a seek: 6.29 microseconds against 1,086 at a
  backlog of 20,000. End to end, a dequeue and acknowledge at that depth went
  from 1,187 microseconds to 294, and the cost is now flat across depths.
- Retrieval reads candidates in batches instead of one row at a time with a
  growing offset, which re-read the head of the queue on every locked
  candidate. Both backends.
- The Isar backend now uses indexes. Every query ran as a full collection scan
  followed by an in-memory sort, while the model declared ten indexes no query
  referenced. Queries now go through an entry identity index, a composite
  index that returns entries already in retrieval order, and a per-queue expiry
  index; the unused ones are gone. At a backlog of 20,000 a dequeue and
  acknowledge went from 3,599 microseconds to 542, enqueue from 2,563 per
  second to 5,960, and neither now degrades as the backlog grows.

### Added
- `runMaintenance({policy, queueName})` on `StorageInterface` and both backends:
  one periodic pass that returns entries whose consumer died, marks entries that
  outlived their deadline, and deletes finished entries older than the retention
  policy allows. It reports what it did as a `MaintenanceReport`. Nothing calls
  it on a schedule; run it from your own timer or at startup.
- `RetentionPolicy`, controlling how long completed, failed, dead lettered and
  expired entries are kept. Defaults to 7 days for completed and failed, 30 for
  dead letters, 1 for expired. `RetentionPolicy.keepEverything()` deletes
  nothing.
- `StoreConflict` and a `DuraQException` hierarchy with `DuplicateEntryException`,
  so a duplicate id can be handled without catching driver-specific errors. The
  entry payload is deliberately kept out of the error text.
- `onConflict` on `Queue.enqueueEntry`, for producers that retry an enqueue they
  got no answer for.
- `busyTimeout` on `SQLiteStorage`: how long to keep trying to start a write
  when another process or isolate holds the write lock. Defaults to 5 seconds.
  The wait is spent in short slices with the isolate free in between, rather
  than one long block inside the driver.
- `StorageBusyException`, thrown when that budget runs out. It replaces the raw
  `SqliteException` a caller would otherwise have to recognise, and the work is
  untouched, so retrying the call is safe.
- `leaseDuration` on both storage backends: how long a retrieved entry stays
  claimed before another consumer may take it. Defaults to five minutes, which
  is the duration that was previously hardcoded.
- `maxDeliveryAttempts` on both storage backends: how many times an entry may be
  delivered before an expiring lease sends it to the dead letter queue instead
  of back to the queue. Defaults to 5, so a job that crashes its consumer cannot
  cycle forever.
- `reclaimStaleEntries({String? queueName})` on both storage backends, for
  recovering entries at startup that a previous run left claimed. Returns the
  number of entries returned to pending.
- `IsarStorage.removeDuplicateEntries()`, a one-off cleanup for databases
  written by earlier versions. Those versions could store several rows for one
  entry; this collapses them, keeping the most recently updated row, and
  returns how many rows it removed. Run it once after upgrading.
- `close()` on `StorageInterface`, implemented by both backends. Neither
  `dispose` nor `close` appeared on the interface before, and the two backends
  disagreed on the shape — SQLite's was synchronous and returned void, Isar's
  was asynchronous — so shutdown could not be written without knowing which
  backend was underneath. `dispose()` stays on both concrete classes for
  callers already using it; the Isar backend still leaves the Isar instance
  open, since the caller owns it.
- `synchronous` on `SQLiteStorage`, with `SqliteSynchronous` and the
  `activeSynchronous` getter that reads the setting back from the live
  connection. Write-ahead logging runs at `NORMAL`, which is unchanged and
  still the default: a DuraQ process that dies loses nothing, but the machine
  going down can lose the most recent commits — for a queue, jobs that were
  accepted. `SqliteSynchronous.full` closes that at a measured cost of about
  half the single-enqueue throughput (13,496/s to 6,913/s, median of five
  interleaved rounds).
- `countReady()` on `StorageInterface`, both backends and `Queue.readyLength`:
  the number of entries that can be handed out *now*. `count()` includes
  entries scheduled for later and entries waiting out a retry backoff, so a
  queue could report a length of two and hand out nothing — an autoscaler
  reading it scales up for work that is not due. `count()` is unchanged and
  still reports the backlog; its documentation now says which is which. The
  interface carries a working default that filters `retrieveAll`, but Dart's
  `implements` copies signatures only, so a custom backend must declare it.
- A `metrics` parameter on `Queue` and `QueueManager`. Nothing in the library
  recorded a metric, so every rate a `QueueMetrics` could report read zero
  however busy the system was. A queue given a collector now records enqueues,
  dequeues, completions, failures, latencies and processing times, each
  labelled with the queue's name. Throughput counts attempts rather than
  successes, so `getErrorRate` stays a proportion.
- `maxReadyBacklog` on `QueueHealthCheck`, which reports degraded when too much
  work is ready to run. Deliberately compared against ready rather than
  waiting: a queue full of entries scheduled for next week is not falling
  behind. Running the check also samples each queue's size into the metrics
  collector, so `getCurrentQueueSize` stops reading zero forever.
- Schema versioning on both backends. SQLite records its version in the
  `user_version` pragma; Isar records it in a new `QueueMetaCollection` row,
  which is what Isar has no equivalent of. A database written by a newer DuraQ
  is now refused on open with `SchemaVersionException` rather than being read as
  if nothing had changed, and both backends have a migration runner so the next
  change of shape or meaning has a way to reach databases already in the field.
  Before this, tables were created if absent and never versioned.
- `SQLiteStorage.schemaVersion` and `IsarStorage.schemaVersion`, the version
  this release writes, alongside `SQLiteStorage.storedSchemaVersion` and
  `IsarStorage.storedSchemaVersion()` for what a given database is at.
- `SchemaVersionException`, raised when a storage is at a version this release
  does not understand, and when an entry carries a status string this release
  has no name for. The latter previously surfaced as
  `ArgumentError: Invalid argument (name)`, naming neither the entry nor why.
- `QueueCodec<T>` and a `codec` parameter on `Queue`, `DeadLetterQueue` and
  `QueueManager.queue`. Payloads are stored as JSON, which limited a queue to
  what `jsonEncode` accepts no matter what its type argument said. A codec makes
  that boundary explicit and lifts it, so `Queue<Invoice>` can hold an `Invoice`.
  `QueueCodec.from(encode:, decode:)` builds one from a pair of functions.
- `PayloadCodecException`, raised when a payload cannot cross that boundary: an
  unencodable payload with no codec, a codec that threw, or a queue read through
  an element type its entries were not written with. Each replaces an error that
  named only the failing conversion — `JsonUnsupportedObjectError`, or a bare
  `TypeError` about two unrelated types — with one naming the queue, the type,
  and the way out.
- `QueueEntry.withData<R>()`, which copies an entry around a payload of a
  different type. `copyWith` cannot change the payload type, and both encoding
  and decoding do.
- `tool/verify.sh`, the project's gate: `dart analyze --fatal-infos
  --fatal-warnings` followed by the test suite. `tool/verify.sh --flake N` runs
  the suite N times instead, to surface timing flakes. `tool/install-hooks.sh`
  points git at `.githooks/`, whose `pre-push` hook runs the gate before
  anything leaves the machine.
- `analysis_options.yaml`. The `lints` dev dependency has been declared since
  1.0.0 but was never applied, because nothing told the analyzer to use it.
  Generated Isar code is excluded; `test/analysis_options.yaml` relaxes two
  rules that only make sense for shipped code.
- A GitHub Actions workflow running the same script. The repository had no
  workflows before, so nothing had ever been checked automatically. A second,
  non-blocking job reports whether the advertised Dart 3.0 floor still builds
  and re-runs the suite to watch for flakes.

### Changed
- Operations on a `SQLiteStorage` instance are serialized, and calls made from
  inside a `transaction()` body remain re-entrant. Measured cost is under
  0.3 microseconds per operation.
- `beginTransaction()` now holds exclusive access to the storage until the
  transaction is committed or rolled back. A manual transaction that is never
  closed will block later operations; prefer `transaction()`.
- Raw generic types are written out. `QueueEntry` in a signature now reads
  `QueueEntry<dynamic>`, which is the same type spelled honestly: the storage
  layer is untyped by design. No behaviour changes.
- `sqlite3` now requires 2.2.0 or later, up from 2.1.0, which is the version
  that replaced the deprecated `getUpdatedRows()` with `updatedRows`. The
  package already resolved well above this floor in practice.
- `test` now requires 1.25.0 or later, for the reporter `tool/verify.sh` uses.
  Dev dependency only; consumers are unaffected.

## [1.0.0] - 2026-03-22

### Changed
- **BREAKING CHANGE**: `IsarStorage` now requires an external Isar instance instead of creating its own
- `IsarStorage.create()` factory method has been removed
- `IsarStorage` constructor now accepts an `Isar` instance parameter
- `IsarStorage.dispose()` no longer closes the Isar instance (caller responsibility)
- Added `IsarStorage.requiredSchemas` static getter to help users configure Isar with required schemas

### Added
- Support for shared Isar instances across multiple components
- Better integration with external systems that manage Isar lifecycle
- Comprehensive documentation for new Isar usage patterns

### Migration Guide
**Before:**
```dart
final storage = await IsarStorage.create(dbPath: 'path/to/queue.isar');
// ... use storage
await storage.dispose(); // Closed Isar automatically
```

**After:**
```dart
await Isar.initializeIsarCore(download: true);
final isar = await Isar.open([
  ...IsarStorage.requiredSchemas,
  // Add your other schemas here
], directory: 'path/to/db');

final storage = IsarStorage(isar);
// ... use storage
await storage.dispose(); // Releases locks only
await isar.close(); // Caller manages Isar lifecycle
```

## [0.0.1] - 2024-01-24

### Added
- Initial release with core functionality
- Queue management system with type safety
- SQLite storage backend implementation
- Queue entry tracking and metadata
- Comprehensive test suite
- Basic documentation and examples
