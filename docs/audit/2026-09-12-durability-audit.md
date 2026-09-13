# DuraQ Durability Audit

**Package** duraq 1.0.1 · **Commit** 5315698 · **Reviewed** 12 Sep 2026
**Environment** Dart 3.11.5, macOS arm64 (darwin 23.6.0)
**Rendered copy** [2026-09-12-durability-audit.html](./2026-09-12-durability-audit.html) · published at https://claude.ai/code/artifact/2b516c4d-ee5d-4e99-87e9-f850716bbcfd

The structure is sound and the SQLite schema is well chosen, but DuraQ does not
currently hold the guarantees its README advertises. Six defects can lose or
duplicate a job, and one of them is already failing in the repository's own test
suite.

| Signal | Value |
| --- | --- |
| Tests failing on a clean checkout of the published version | 1 |
| Defects that lose, duplicate, or silently discard work | 6 |
| Line coverage of `lib`, excluding generated code | 48.7% |
| Dequeue slowdown as the backlog grows from 1k to 20k | 4.8× |

Every defect below was reproduced against commit 5315698 with standalone
programs driving the public API. Query-plan and timing figures come from the
same database files the library creates.

---

## Remediation status

Updated 13 Sep 2026. Findings carry a **Status** paragraph where work has
landed; this table is the index.

| ID | Finding | Status |
| --- | --- | --- |
| C1 | Overlapping transactions roll back each other's work | Fixed (residual: manual transaction API) |
| C2 | Parallel consumers told the queue is empty | Fixed |
| C3 | Retry backoff ignored | Fixed |
| C4 | Nothing recovers an entry left in processing | Fixed |
| C5 | Isar stores and delivers one job many times | Fixed (residual: index not unique) |
| C6 | Isar transactions provide no atomicity | Fixed (manual API now throws) |
| H1 | Disposing releases every lock in the database | Fixed |
| H2 | Lock owner identifier never checked | Fixed (unconditional updates still possible by omitting the lease) |
| H3 | Multi-process use not configured for | Fixed |
| H4 | Dequeue rescans the backlog | Fixed |
| H5 | Isar declares ten indexes and uses none | Fixed |
| H6 | Finished work never removed | Fixed (caller must schedule it) |
| H7 | Backends disagree on a duplicate id | Fixed (residual: ids global, not per queue) |
| M4 | Store drops the retry time | Fixed with C3 |
| M1 | `dequeue` does not remove anything | Fixed (now at-most-once by contract) |
| M2 | Queue manager caches by name and casts | Fixed |
| M3 | Type safety is nominal | Fixed (`QueueCodec`; JSON is still the storage form) |
| M5 | Backoff arithmetic overflows | Fixed |
| M6 | Status updates clear fields nobody asked them to clear | Fixed (missing id now throws) |
| M8 | Dead-lettered and expired entries keep their lock | Fixed |
| M10 | Lock acquisition swallows every error as contention | Fixed |
| M13 | No schema version, no migration path | Fixed (unblocks the two deferred decisions) |
| M7 | Queue length counts jobs that cannot be dequeued | Fixed (`countReady` added; `count` unchanged) |
| M9 | Metrics and health checks are inert | Fixed |
| M11 | The storage interface has no teardown | Fixed |
| M14 | Durability is one notch below what the name suggests | Fixed (default unchanged, now sayable) |
| M12 | Isar is a hard dependency for everyone | Fixed (split into `duraq_isar`) |
| Q1 | Published version fails its own tests | Fixed, suite is green |
| Q2 | Coverage thinnest where the risk is | **Open**, not re-measured since |
| Q3 | The isolation test cannot fail | Partly: real isolation tests exist in `serialization_test.dart`, the vacuous assertion in `transaction_test.dart` remains |
| Q4 | No CI, no lint configuration | Fixed |
| Q5 | Untested behaviours are the ones that fail | Mostly closed; TTL of an in-flight entry and dead-letter lock release are still untested |
| Q6 | Tests lean on real databases and wall-clock waits | Partly: six flakes found and fixed, two of which were real defects rather than bad tests. `tool/verify.sh --flake` hunts for more. The suites still use real databases and real elapsed time |

### Where the work lives

Committed on branch `audit-remediation`, branched from `main` at `5315698`, not
pushed. The repository is now two packages under `packages/`; paths below that
predate the split are relative to `packages/duraq/`. `7c78742` carries C1 to C6, H1 and H3 to H7; `701069a` carries H2;
`291bc56` carries the gate (Q4); `1dd3bad` carries M1 to M3;
`e2804ce` carries M5, M6, M8 and M10; `7ef3ab6` carries M13;
`8dfd163` carries M7 and M9; `bf03923` carries M11 and M14;
`923a6e8` carries M12.
The first is a single commit because the changes for different findings
interleave inside the two storage files, and the intermediate states were
never committed, so a per-finding split would have meant staging hunks by hand
into commits nobody ever ran the tests against.

182 tests pass; `dart analyze` reports two pre-existing deprecation notices
outside generated code.

New source files: `lib/src/errors.dart`,
`lib/src/concurrent/serial_lock.dart`, `lib/src/storage/maintenance.dart`,
`lib/src/storage/isar_write_scope.dart`.

New test files: `serialization_test.dart` (C1, C2), `retry_backoff_test.dart`
(C3, M4), `lease_reclaim_test.dart` (C4, H1), `candidate_scan_test.dart` (H4),
`isar_semantics_test.dart` (C5, C6, H5), `contract_test.dart` (H6, H7, run
against both backends), `contention_test.dart` (H3),
`lease_ownership_test.dart` (H2, run against both backends).

Modified: both storage backends and both lock managers, the storage interface,
`queue.dart`, `duraq.dart`, the Isar models and their generated code,
`packages/duraq/test/utils/mock_storage.dart`, `retry_lock_release_test.dart`, plus the README
and CHANGELOG.

A sensible commit split, smallest first: the serialization change (C1, C2); the
retry gate (C3, M4); the lease reclaim and lock ownership (C4, H1); the SQLite
retrieval path (H4); the Isar backend rewrite (C5, C6, H5); the interface work
(H6, H7); the contention work (H3).

### Decisions worth not relitigating

- **Isar entry identity is enforced in code, not by a unique index.** A unique
  index makes an existing database holding duplicates fail to open, which was
  verified against a database written by the current release. Revisit with M13.
- **Entry ids are unique across the storage, not per queue.** SQLite makes the
  id the table's primary key; changing that needs a table rebuild, so Isar was
  brought in line. Per-queue identity is the better model, also M13.
- **The manual transaction API is single-caller on SQLite and unsupported on
  Isar.** Neither backend can identify the owner of a transaction that spans two
  calls. A handle-based API would fix both and changes `StorageInterface`.
- **Maintenance is never scheduled by the package.** A library that starts
  timers in someone else's process is worse than one that asks to be called.
- **`cleanupExpiredEntries()` now overlaps `runMaintenance()`.** Left in place
  rather than deprecated; worth resolving when the interface is next touched.

### Verifying

```
tool/verify.sh             # the gate: strict analyze, then the suite
tool/verify.sh --flake 5   # the suite five times, to hunt timing flakes
tool/install-hooks.sh      # run the gate before every push

dart run build_runner build --delete-conflicting-outputs   # after model edits
```

The gate is 182 tests and a clean `dart analyze --fatal-infos
--fatal-warnings`, in about five seconds.

Multi-process behaviour was stressed with two OS processes writing one file,
twenty runs, zero failures. `test/storage/contention_test.dart` covers the same
ground in-process.

---

## Critical defects (C1–C6) — job loss or duplication

### C1 — Overlapping transactions roll back each other's committed work

**Where** `lib/src/storage/sqlite_storage.dart:179` (`transaction`), `:138`
(`beginTransaction`), `:19` (`_transactionDepth`)

Transaction nesting is tracked by a single integer on the storage object, while
`transaction()` is asynchronous. Two callers that overlap nest inside one
another by accident: the second caller's `SAVEPOINT` is taken after the first
has already started writing, so the second caller's `ROLLBACK TO SAVEPOINT`
discards the first caller's rows. The first caller still returns normally.

Reproduced — two concurrent transactions, one storing a row and one throwing:

```
txn B failed as expected: Bad state: this transaction fails
txn A reported success
rows persisted: []
```

**Fix** Serialize storage operations through a single-slot lock, and recognise a
nested transaction only when it comes from the same logical caller — for example
by issuing a token from `beginTransaction` rather than counting depth globally.

**Contradicts** README "Isolation: Concurrent transactions don't interfere with
each other" and "Atomicity".

**Status — fixed, not yet released.** `SerialLock` in
`lib/src/concurrent/serial_lock.dart` serializes storage operations, with
re-entrancy detected through the zone the body runs in. Covered by
`test/storage/serialization_test.dart`.

**Residual.** The fix covers `transaction()`. The manual
`beginTransaction`/`commitTransaction` API cannot identify its own caller across
separate calls, so while a manual transaction is open other operations still
join it rather than queueing. It now takes exclusive access and must be closed,
and the limitation is documented, but closing it properly needs a handle-based
API — a separate decision, since it changes `StorageInterface`.

---

### C2 — Parallel consumers are told the queue is empty while jobs wait in it

**Where** `lib/src/storage/sqlite_storage.dart:248` (`retrieve`), `:263`
(`_retrieveInternal`)

The same interleaving corrupts retrieval. Ten parallel `retrieve` calls against
five pending entries hand out three, return null seven times, and leave two
entries pending. A worker pool reads those nulls as an idle queue and backs off
while work sits there.

Reproduced — deterministic across runs, and already failing in the repository:

```
test/storage/concurrent_processing_test.dart
"should handle multiple concurrent queue operations"
  Expected: <5>   Actual: <3>

handed to workers: [e0, e2, e4]
  e1: pending    e3: pending   (never offered)
```

**Fix** Make a claim atomic — one statement that selects and marks in a single
step, or a serialized critical section around the claim. Same root cause as C1;
both close together.

**Status — fixed, not yet released.** Closed by the same serialization change.
Ten parallel consumers against five entries now receive all five, each exactly
once, with none left pending. The Isar backend was re-checked and does not show
this symptom, because its own write transactions already serialize writes.

---

### C3 — Retry backoff is calculated, stored, and then ignored

**Where** `lib/src/queue.dart:99` writes it; `lib/src/storage/sqlite_storage.dart:288`
and `lib/src/storage/isar_storage.dart:207` never read it

On failure the queue computes a delay and writes `next_retry_at` to the entry,
but neither backend's candidate query filters on that column — only on
`scheduled_for` and `expires_at`. A failed job returns to pending and is
immediately eligible again, so a permanently failing job spins at full speed
through its whole attempt budget instead of backing off. Exponential backoff is
a headline feature and it has no effect on either backend.

Reproduced — ten-minute base delay, SQLite and Isar alike:

```
after failure: status=pending attempts=1
             nextRetryAt=2026-09-12 11:00:53
immediate retrieve returns the same entry
```

**Fix** Add the retry gate to the candidate query on both backends and index it.
The SQLite index `idx_queue_entries_retry` already exists and is unused. See
also M4: the insert statement omits the column entirely, so a pre-built entry
loses the value before it is ever read.

**Status — fixed, not yet released.** Both backends now exclude an entry from
retrieval until `nextRetryAt` has passed, and M4 is fixed alongside it since the
gate is meaningless without it. Covered by `test/storage/retry_backoff_test.dart`
on both backends. The predicate costs 0.44 µs against a candidate select of
13.15 µs; no extra index was added, because changing the existing composite
index would not reach databases already in the field (see M13).

**Follow-on.** A backlog of entries that are all waiting on a retry is now
scanned on every retrieval that returns nothing: 5,000 waiting entries cost
713 µs per empty retrieve. That cost is the expiry sweep in H4, not the new
predicate, and it disappears when H4 is fixed.

---

### C4 — Nothing ever recovers an entry left in processing

**Where** `lib/src/storage/sqlite_storage.dart:328`, `lib/src/storage/isar_storage.dart:248`

Retrieval marks an entry as `processing` and takes a five-minute lock. If the
worker crashes, the process is killed, or the caller used `dequeue()`, that row
stays `processing` forever. The lock expires; the status does not. No query
looks at processing rows again, so the job is unreachable and the queue reports
its length as zero. For a library whose purpose is surviving restarts, this is
the most consequential gap in the design.

Reproduced — retrieve an entry, then simulate the worker dying:

```
next retrieve: null ; queue length = 0
row status now: processing   (no reaper exists)
```

**Fix** Introduce a visibility timeout. Persist the lease expiry on the entry
itself and let retrieval reclaim processing rows whose lease has passed, bounded
by the attempt count so a poisonous job still reaches the dead letter queue.
Expose an explicit reclaim call for startup.

**Status — fixed, not yet released.** Implemented without a schema change: the
lock table already records lease expiry, so an entry that is `processing` with
no live lock is stranded by definition. Retrieval reclaims those for its queue
before looking for work, and `reclaimStaleEntries({queueName})` does it on
demand at startup. A reclaim increments `attempts`; an entry that uses up
`maxDeliveryAttempts` (default 5) is dead-lettered rather than redelivered.
`leaseDuration` is now configurable per storage instance. Covered by
`test/storage/lease_reclaim_test.dart` on both backends.

**Cost** The reclaim adds two indexed statements to each retrieval, 12.13 µs
with nothing in flight, against the 1,079 µs expiry sweep already on that path
(H4). Both use the retrieval index; the lock check uses the lock table's primary
key.

---

### C5 — Isar stores one job many times and delivers it many times

**Where** `lib/src/storage/isar_models.dart:23` (`@Index() late String entryId`),
`lib/src/storage/isar_storage.dart:169` (`put`)

`entryId` carries a non-unique index and the collection uses an auto-incrementing
primary key, so storing the same entry twice creates two independent rows.
`count()` sees both. `updateEntryStatus` uses `findFirst` and updates only one.
The processor runs on the payload once per row, which turns a retried enqueue or
a replayed request into duplicate side effects.

Reproduced — one entry stored twice, then drained through the queue:

```
payload delivered to the processor 2 time(s) for one logical job
rows: same-id completed · same-id processing (stranded)
```

Storing the same entry three times gave three rows and `count()` = 3.

**Fix** Put a unique composite index on (`queueName`, `entryId`) and write
through it. Then settle the cross-backend contract in H7.

**Status — fixed, not yet released.** `store` now upserts through an entry
identity index: it reuses the row that is already there, and drops extra rows
left by earlier versions. Three stores of one entry produce one row and one
delivery, against three rows and two deliveries before.

**The index is not unique, deliberately.** A unique index was built and tested
first, and it makes an existing database that already holds duplicates **fail to
open** with `IsarError: Unique index violated`. That would turn an upgrade into
a startup failure in the field, with no way out: the old schema is gone with the
old version, so the data cannot be cleaned either. Identity is enforced in
`store` instead, and `removeDuplicateEntries()` collapses what earlier versions
left behind. A unique index remains the right end state once M13 gives the
package a migration path.

---

### C6 — The Isar transaction API provides no atomicity at all

**Where** `lib/src/storage/isar_storage.dart:91–130`

`beginTransaction`, `commitTransaction` and `rollbackTransaction` only move a
counter, and rollback does nothing else. Each individual write has already
committed in its own `writeTxn`, so a multi-step operation that throws halfway
leaves the earlier steps in place. Callers get the same method signature as the
SQLite backend and a different guarantee. The README carries a note about this,
but the interface still promises atomicity and rollback still returns success.

Reproduced — a transaction that stores a row, then throws:

```
transaction threw: Bad state: rollback please
rows after rolled-back transaction: [a]
```

**Fix** Run the body inside one `_isar.writeTxn` and have the storage methods
join the ambient transaction instead of opening their own. Until that lands,
make `rollbackTransaction` throw `UnsupportedError` rather than pretend.

**Status — fixed, not yet released.** `transaction()` now runs its body in a
single Isar write transaction, and operations called inside it join that
transaction rather than committing separately. Membership is tracked through the
zone the body runs in, the same mechanism as C1. A transaction that throws now
leaves nothing behind, including status changes made before the failing step.

**The manual API is gone on Isar.** `beginTransaction` and its pair throw
`UnsupportedError`, because an Isar write transaction takes its work as a
callback and cannot be opened in one call and closed in another. This is a
breaking change against a method that previously moved a counter and guaranteed
nothing.

---

## High severity (H1–H7) — correctness under load and across processes

### H1 — Disposing one storage instance releases every lock in the database

**Where** `lib/src/concurrent/queue_lock.dart:130` (`DELETE FROM queue_locks`
with no WHERE), called from `sqlite_storage.dart:525`; Isar equivalent
`isar_lock.dart:113` (`clear()`)

Any process, isolate, or component shutting down drops the locks held by every
other consumer of the same file, across every queue in it. The next retrieval
can hand out an entry that is still in flight elsewhere.

**Fix** Track the lock identifiers this instance owns and delete only those, or
leave the lock table alone on disposal and let leases expire.

**Status — fixed, not yet released.** Fixed with C4, which depends on it: once
retrieval treats "no live lock" as "stranded", a shutdown that wipes the lock
table would hand another process's in-flight entries to a new consumer. Both
lock managers now track the ids they acquired and release only those. Covered by
the two-instance test in `test/storage/lease_reclaim_test.dart`.

**Note** This changes the meaning of the public `QueueLock.releaseAllLocks()`
from "empty the lock table" to "release the locks this instance holds", which is
what `dispose()` wanted. Nothing in the package relied on the wider behaviour.

---

### H2 — Locks have an owner identifier that is never checked

**Where** `lib/src/concurrent/queue_lock.dart:44` (generates `lockId`), `:77`
(`release` deletes by queue + entry only)

Acquiring a lock generates, stores and returns an identifier, but nothing keeps
it and release deletes by queue and entry alone. A worker whose lease has
already expired will release its successor's lock when it finishes, and any
caller can release any lock through a status update. The identifier gives the
appearance of ownership without enforcing it.

**Fix** Carry the lock identifier with the claimed entry and make release
conditional on it.

**Status — fixed, not yet released.** `retrieve` returns the lease id on the
entry, `updateEntryStatus` accepts it, and a change made against a lease that is
no longer the live one is discarded instead of applied over the work of whoever
holds the entry now. Release is conditional on the lease id, so a stale consumer
cannot free its successor's claim. `Queue.processNext` passes the lease
automatically, on completion and on failure alike. Covered for both backends by
`test/storage/lease_ownership_test.dart`.

**Omitting the lease still updates unconditionally.** Administrative changes and
the dead letter flows hold no claim, and requiring one would break every direct
caller. So the escape hatch the finding describes is still open to code that
asks for it; what is closed is the library's own path, which is where the
double-processing came from.

---

### H3 — Multi-process use is not configured for, and fails loudly

**Where** `lib/src/storage/sqlite_storage.dart:45–46` (pragmas)

WAL is enabled, which invites multi-process use, but `busy_timeout` is left at
0. A second process writing the same file gets an immediate locked error rather
than waiting. Disposal can fail the same way and throw out of a shutdown path.

Measured — two processes, 300 enqueues each, same database file:

```
B: committed=253 failed=47
   SqliteException(5): database is locked
(a second run crashed the losing process inside dispose)
```

**Fix** Set a busy timeout, retry on contention, and state the supported
concurrency model in the README. Several projects sharing one queue file is
exactly the situation this package invites.

**Status — fixed, not yet released.** A `busyTimeout` (default 5 seconds) now
covers starting a write, and the wait is spent in short slices with an async
retry in between rather than one long block inside the driver, so the isolate
stays responsive while a write waits its turn. Only the outermost `BEGIN
IMMEDIATE` is retried, where nothing has executed yet, so a retry repeats no
work. When the budget runs out the caller gets a `StorageBusyException` instead
of a driver error, and nothing was written, so retrying is safe. The README now
states the model. Covered by `test/storage/contention_test.dart`, including a
timer that has to keep ticking while a write is blocked.

**Two more failures surfaced while testing this.** Switching a new file to
write-ahead logging needs an exclusive lock and, unlike an ordinary write, does
not go through the busy handler, so two processes opening the same fresh file
collided and one crashed in its constructor; that switch is now retried briefly
and then accepts the mode the file is in, since the winner's change is
persistent. And `dispose()` released its locks through a future whose failure
nothing handled, so a contended shutdown surfaced as an unhandled exception
rather than the caught one it looked like in the source.

| Two processes, 300 enqueues and 50 claims each | Before | After |
| --- | --- | --- |
| Failed operations | 47 of 300 enqueues | 0 |
| Runs ending in a crash | 1 in 2 | 0 in 20 |

---

### H4 — Every dequeue rescans the entire backlog before it looks for work

**Where** `lib/src/storage/sqlite_storage.dart:267` (expiry sweep inside
`_retrieveInternal`)

The sweep runs across all pending rows of the queue on each call, even though
the candidate query that follows already excludes expired rows. It cannot use
the partial expiry index and falls back to `idx_queue_entries_retrieval`, so its
cost is proportional to the backlog.

Measured — backlog of 20,000, no row carrying an expiry at all:

```
expiry sweep     1086 us per dequeue
candidate select   52 us
lock cleanup        5 us
```

**Fix** Take the sweep out of the hot path and run it in periodic maintenance;
the candidate query already handles expiry lazily. While there, replace the
offset-walking loop at `:286` that rescans from the start on each lock attempt.

**Status — fixed for SQLite, not yet released.** The sweep was kept rather than
moved, because marking entries `expired` promptly is documented behaviour, and
made cheap instead: a partial `(queue_name, expires_at)` index turns it from a
scan of every pending entry into a seek. The offset walk now reads candidates in
batches of 16. Covered by `test/storage/candidate_scan_test.dart`, including a
locked-candidate case that crosses a batch boundary.

| Measurement, backlog of 20,000 | Before | After |
| --- | --- | --- |
| Expiry sweep per retrieval | 1,086 µs | 6.29 µs |
| Dequeue and acknowledge | 1,187 µs | 294 µs |
| Dequeue with a TTL on every entry | not measured | 302 µs |

Dequeue cost no longer tracks the backlog: 342, 244 and 294 µs at depths of
1,000, 5,000 and 20,000, which is flat within run-to-run variance. The new index
is partial, so entries without a TTL cost nothing to maintain; batched enqueue of
entries that all carry a TTL measured 131,063/s against 144,442/s without one.

**Still open for Isar.** The Isar backend runs the same sweep as an unindexed
`findAll` followed by a write per expired entry. It cannot be fixed the same way
because no Isar query in the package uses an index at all, which is H5.

---

### H5 — The Isar backend declares ten indexes and uses none of them

**Where** `lib/src/storage/isar_storage.dart` — 21 `.filter()` call sites, zero
indexed `.where(...)` lookups; `lib/src/storage/isar_models.dart:23–68` declares
the indexes

`.filter()` walks the whole collection and sorts matches in memory. The model
meanwhile declares ten indexes, including a composite `retrievalKey` no query
mentions. They cost write time on every `put` and return nothing on read. Isar
enqueues at roughly a sixth of SQLite's rate.

**Fix** Query through the composite index that already exists and delete the
ones nothing reads.

**Status — fixed, not yet released.** The model now declares three indexes that
the queries actually use, and the ten that nothing referenced are gone. An entry
identity index serves every by-id lookup; a composite `(queue + status,
priority, createdAt)` index returns entries already in retrieval order, so no
sort runs over the results; a `(queueName, expiresAt)` index makes the expiry
sweep a seek, which is the Isar half of H4. Covered by
`test/storage/isar_semantics_test.dart`, including retrieval order and queue
isolation.

| Isar, backlog of 20,000 | Before | After |
| --- | --- | --- |
| Dequeue and acknowledge | 3,599 µs | 542 µs |
| Enqueue, one call per entry | 2,563/s | 5,960/s |

Neither now degrades with the backlog: dequeue measures 579, 446 and 542 µs at
depths of 1,000, 5,000 and 20,000, and enqueue 5,724, 6,568 and 5,960 per
second. Enqueue improved despite `store` now doing an identity lookup, because
ten indexes no longer have to be maintained on every write.

---

### H6 — Finished work is never removed

**Where** `lib/src/storage/sqlite_storage.dart:346` (`cleanupExpiredEntries`),
absent from `storage_interface.dart`

Nothing deletes completed, failed, or dead-lettered rows. The one cleanup
routine covers expired entries only, exists on the concrete classes rather than
the interface, and is never called by the library or reachable generically. A
queue that runs for months keeps every job it has ever processed.

**Fix** Put a retention policy and a maintenance entry point on the interface,
and document who runs it and how often.

**Status — fixed, not yet released.** `runMaintenance({policy, queueName})` is on
`StorageInterface` and both backends. One pass reclaims stranded entries, marks
entries that outlived their deadline, and deletes finished entries older than
`RetentionPolicy` allows, reporting all three counts. Defaults keep completed and
failed entries for 7 days, dead letters for 30 and expired for 1;
`RetentionPolicy.keepEverything()` deletes nothing. Unfinished work is never
deleted, whatever the policy says. Covered for both backends by
`test/storage/contract_test.dart`.

**Still the caller's job to schedule.** Nothing in the package runs maintenance
on a timer. A library that starts timers in someone else's process is worse than
one that asks to be called, but that has to stay visible in the README rather
than only in the API docs.

---

### H7 — The two backends disagree about storing a duplicate identifier

**Where** `sqlite_storage.dart:223` (`INSERT`, no conflict clause) vs
`isar_storage.dart:169` (`put`)

SQLite throws a raw driver exception with the failing statement and its
parameters attached; Isar silently creates a second row. A caller writing
against the interface cannot handle both, and the payload appears in the SQLite
error text, which is a logging concern of its own.

```
SqliteException(1555): UNIQUE constraint failed: queue_entries.id
  Causing statement: INSERT INTO queue_entries (...)
  parameters: dup, q, "x", 1789181109702, ...
```

**Fix** Decide whether `store` is an upsert or an error, implement it identically
on both backends, translate driver exceptions into a package-level error type,
and test the contract against every backend.

**Status — fixed, not yet released.** The caller decides, rather than the
backend: `store` takes a `StoreConflict` of `fail` (the default), `replace` or
`ignore`. Both backends now throw `DuplicateEntryException`, a `DuraQException`,
which carries the queue and id but deliberately not the payload, so the SQLite
driver error that embedded the entry data in its text no longer escapes.
`Queue.enqueueEntry` exposes the same choice, which is what an idempotent
enqueue needs. The contract is tested against both backends by the same suite in
`test/storage/contract_test.dart`.

**One divergence closed the awkward way.** SQLite makes the entry id the table's
primary key, so ids are unique across the whole storage, while Isar's identity
was per queue. Changing SQLite to a per-queue identity means rebuilding the
table, which needs the migration path M13 describes, so Isar was brought in line
with SQLite instead: an id already used by another queue is a conflict. Per-queue
identity is the better model and should be revisited with M13.

---

## Medium severity (M1–M14) — contract, clarity, and dead weight

| ID | Finding | Detail |
| --- | --- | --- |
| M1 | `dequeue` does not remove anything | Documented as retrieving and removing; it marks the entry processing and returns the payload with no way to acknowledge it. Every call leaks a row by the C4 mechanism. Implement as claim-and-delete or retire it in favour of `processNext`. |
| M2 | Queue manager caches by name and casts | `queue_manager.dart:13`. Asking for the same queue with a different element type throws `_TypeError`; the first caller's type wins for the process lifetime. A queue first touched untyped can never be fetched typed. |
| M3 | Type safety is nominal | Payloads round-trip through JSON. A plain Dart object throws `JsonUnsupportedObjectError` at enqueue; a mismatched type surfaces as a cast error at dequeue. The feature list promises "generic support for any data type". A codec parameter on `Queue<T>` would make the constraint explicit and lift it. |
| M4 | Storing an entry drops its retry time | **Fixed, not yet released.** `sqlite_storage.dart` omitted `next_retry_at` from the insert column list, so a pre-built entry carrying one lost it silently. Fixed with C3, which depends on it. |
| M5 | Backoff arithmetic overflows into a negative delay | `exponential_backoff.dart:38`. At 60 attempts it returns a negative `Duration` (retry scheduled in the past); beyond ~1100 it returns zero. `maxDelay` is bypassed in both cases because the clamp compares against the overflowed value. |
| M6 | Status updates clear fields nobody asked them to clear | `sqlite_storage.dart:444`. Each update overwrites `error_message` and `next_retry_at` with null unless both are supplied, and no update checks that a row matched, so a wrong identifier is a silent success. |
| M7 | Queue length counts jobs that cannot be dequeued | `count()` includes entries scheduled for the future and entries awaiting a retry. A queue reporting length 1 can return nothing on the next call, which makes the figure unsafe for health checks or scaling. |
| M8 | Dead-lettered and expired entries keep their lock | `sqlite_storage.dart:455` releases on completed / failed / pending only; those two paths hold a lease for its full duration after the entry is finished with. |
| M9 | Metrics and health checks are inert | No library code records a metric, so every rate reads zero. `MetricsHealthCheck` probes a hardcoded `'health-check'` queue and is therefore always healthy; `QueueHealthCheck` reads a queue called `'default'`. As shipped, the health surface reports nothing about the running system. |
| M10 | Lock acquisition swallows every error as contention | `queue_lock.dart:70`. Any exception, including a genuine storage failure, is reported as "already locked", which drives the candidate scan forward instead of surfacing the problem. |
| M11 | The storage interface has no teardown | Neither `dispose` nor `close` appears on `StorageInterface`; SQLite's is sync and void, Isar's is async. Backend-agnostic shutdown is not expressible. |
| M12 | Isar is a hard dependency for everyone | A SQLite-only project still pulls `isar` and its native core, pinned to 3.1.0+1 whose generated code already raises analyzer warnings on current Dart. Splitting the backend into its own package removes that from every SQLite consumer. |
| M13 | No schema version, no migration path | Tables are created if absent and never versioned; `EntryStatus.values.byName` throws on an unrecognised status string. Any future column or status value has no safe way to reach databases already in the field. |
| M14 | Durability is one notch below what the name suggests | WAL runs at `synchronous=NORMAL`, so recently committed jobs can be lost on an OS crash or power loss. A reasonable default, but the package should say so and let the caller ask for FULL. |

---

## Performance

Both backends slow down as the backlog grows, which is the opposite of what a
queue should do: the deeper the queue, the slower it drains. The cause differs
per backend, and in both cases it is avoidable work rather than a storage limit.

One job per operation, claim and acknowledge, single process:

| Backlog | SQLite enqueue | SQLite dequeue | Isar enqueue | Isar dequeue |
| --- | --- | --- | --- | --- |
| 100 entries | 9,239/s | 325 µs | 3,072/s | 909 µs |
| 1,000 entries | 17,112/s | 248 µs | 4,304/s | 958 µs |
| 5,000 entries | 21,919/s | 453 µs | 3,622/s | 1,423 µs |
| 20,000 entries | 22,679/s | 1,187 µs | 2,563/s | 3,599 µs |

Two further measurements worth acting on:

- Enqueueing inside one transaction reaches **149,903/s** against 22,679/s for
  individual calls. A batch enqueue on the public API would pay for itself.
- Of the 1,187 µs a dequeue costs at 20,000 entries, **1,086 µs is the expiry
  sweep** (H4), against 52 µs for the query that actually finds the job.

---

### Status: M1, M2 and M3 fixed

**M1.** Reproduced first: two items enqueued, one dequeued, and 300 ms later
`dequeue` returned the *same* payload again. With C4's reclaim in place the old
behaviour was worse than a leaked row — every dequeued item came back until
`maxDeliveryAttempts` sent it to the dead letter queue.

`dequeue` now claims and deletes in one transaction, which is what its
documentation always said it did. That fixes the redelivery and settles the
contract: `dequeue` is at most once, `processNext` is at least once, and the
README now carries a table saying so rather than leaving a reader to infer it.
Deleting an entry also releases its lock, which it did not before — a deleted id
stayed claimed until its lease ran out, so the id could not be re-enqueued and
picked up in that window.

Eight of the twelve new tests in `queue_dequeue_test.dart` fail against the old
`dequeue`, and the lock test fails on both backends when only the lock release
is reverted.

**M2.** The cache was keyed by name and the result cast to the caller's type, so
`queue<int>('x')` after `queue<String>('x')` threw
`type 'Queue<String>' is not a subtype of type 'Queue<int>'` out of the cache,
and a queue first touched untyped could never be fetched typed. The key is now
the name *and* the element type. Two typed views of one queue are legitimate —
a worker reading `Invoice` while an admin tool reads `dynamic` — and both now
work over the same entries. `removeQueue` clears every view of the name.

**M3.** `Queue<T>` promised "any data type" and delivered whatever `jsonEncode`
accepts. `QueueCodec<T>` makes that boundary explicit and lifts it; JSON is
still the storage form, which keeps existing databases readable. The codec
reaches `DeadLetterQueue` too, because those are the same entries moved aside,
and a codec that only worked on the happy path would not be a fix.

Three failures now report `PayloadCodecException` naming the queue, the type and
the way out, in place of a `JsonUnsupportedObjectError` or a bare `TypeError`
about two unrelated types: an unencodable payload with no codec, a codec that
threw, and a queue read through the wrong element type.

One thing the reproduction changed: `dequeue` decodes *inside* the transaction,
before the delete. A codec that throws would otherwise destroy the payload on
its way past. Verified on both backends — the entry stays pending and the
retry after the codec recovers returns it.

Not addressed, and not claimed: a payload still round-trips through JSON, so
`Queue<double>` reading an entry stored as `1` still meets an `int`. The codec
is the supported way to control that.

### Status: M5, M6, M8 and M10 fixed

**M5** is worse than the finding recorded. Measured across attempt counts with
`baseDelay` 100 ms and `maxDelay` 30 s: attempt 58 asked for 1,881,667,198,283,816 ms,
about 60,000 years, with the cap bypassed entirely; from attempt 64 every delay
came out **zero**, which is not a slow retry but a tight loop. Both are the same
cause — `pow(2, attempts)` in integer arithmetic wraps a 64-bit int at 63, and
the cap was comparing against the wrapped value.

The delay is now computed in floating point, where overflow saturates to
infinity and `min` handles it. A second change came out of writing the test:
jitter used to be applied *before* the cap, so every attempt at or past the
ceiling returned exactly `maxDelay` with no spread at all — the point in a
backoff where spread matters most. Jitter now applies after the cap, so delays
at the ceiling land between 75% and 100% of it.

**M6** had two halves. Every update wrote `error_message` and `next_retry_at`
whether or not the caller mentioned them, so completing an entry erased the
error explaining its last failure — reproduced by failing an entry with
"disk on fire" and watching it complete with a null error. The update now writes
only the fields it is given, with one deliberate exception: moving an entry to
`pending` without a retry time clears the backoff, because leaving a stale one
would withhold an entry the caller just made ready.

The other half, a wrong id reporting success, now throws
`EntryNotFoundException`. A change discarded because the caller's lease expired
still returns quietly — the entry exists and someone else holds the claim — and
a test pins that distinction.

**M8** had a user-visible symptom the finding did not name: `retryDeadLetter`
appeared to do nothing. The entry went back to pending still locked by the claim
it died under, so the candidate scan skipped it for the rest of the lease, five
minutes by default. The rule is now simply that anything other than `processing`
releases the claim.

**M10** is narrower than recorded. The catch-all wraps the insert only, so a
failure in the expired-lock cleanup already propagated. What it did swallow was
every insert failure: demonstrated with a lock table the insert cannot satisfy,
where a `NOT NULL` violation was reported as "the entry is already locked". Only
a genuine conflict — primary key on SQLite, unique index on Isar — now means
locked, and everything else is raised rather than sending the scan to the next
candidate and making a broken database look like an empty queue.

**A defect found on the way through, not in the audit.** A new test flaked once
in three runs: a change made under a lease that should have been stale was
applied. The cause was not the test. Lock ids were built as
`queueName_entryId_millisecondsSinceEpoch`, so two claims of the same entry
inside one millisecond produced *the same id*, and a consumer holding the older
one passed the ownership check as the current holder — defeating H2 entirely in
exactly the case it was written for, back-to-back claims. Ids now carry a UUID.
A loop of 200 back-to-back acquire/release cycles produces 200 distinct ids
with the fix and collides without it, and the suite has run eight consecutive
times clean since.

Eleven of the twenty tests in `update_semantics_test.dart` fail against the old
implementation, symmetrically across both backends. `packages/duraq/test/utils/mock_storage.dart`
was updated to match the contract: it could not clear those fields at all, so
the mock and the real backends had quietly disagreed about M6 all along.

### Status: M13 fixed

Both backends now record a schema version and can migrate a database forward.
SQLite uses its own `user_version` pragma, which costs nothing and needs no
table. Isar has no equivalent, so it gets a one-row `QueueMetaCollection`.

The behaviour that matters is symmetric on both: a database written by a **newer**
DuraQ is refused with `SchemaVersionException` rather than read as though
nothing had changed, and a database written by an **older** one is brought up to
date in place. A database from before versioning existed is taken to be version
1 — the shape every release up to now wrote — and stamped on first contact.

The migration runner was extracted into `SqliteSchema` so it could be tested
with real migrations rather than asserted against an empty map: the tests walk a
three-version schema, check that only the missing steps run, and that a step
which throws rolls back and leaves the database at the last version that applied
in full. A mechanism whose first real use is a future release is worth proving
now rather than trusting.

Verified against fixtures rather than reasoned about. A SQLite database written
by this package and then stripped of its version opens, keeps its rows, and is
stamped. An Isar database written with the *previous* schema set — three
collections, no meta — opens under the new set with its entries intact and
still serves work.

That last check turned up an upgrade hazard worth naming: a caller who listed
DuraQ's collections by hand instead of spreading `IsarStorage.requiredSchemas`
gets `IsarError: Missing TypeSchema in Isar.open`, which names neither the
collection nor the fix. That is now translated into an error that names both.

**The status parse**, the other half of the finding, no longer throws
`ArgumentError: Invalid argument (name): No enum value with that name`. An entry
carrying a status this release has no name for reports which entry and why.

**What this unblocks.** Both decisions deferred earlier in this remediation were
waiting on exactly this. The Isar entry index is deliberately not unique, and
entry ids are unique across the storage rather than per queue; both would change
what existing databases mean, and until now there was no way to carry a field
database across such a change. There is now. Neither decision is revisited here —
they remain open, but they are no longer blocked.

### Status: M7 and M9 fixed

**M7.** Reproduced with two entries — one scheduled for tomorrow, one waiting
out a backoff. `queue.length` reported 2 while `processNext` found nothing and
`dequeue` returned null.

`count` is unchanged and still reports the backlog, because "how much is in this
queue" is a fair question and an entry due tomorrow is in it. What was missing
is the other figure, so `countReady` was added to the interface and both
backends, with `Queue.readyLength` in front of it. Each backend's query mirrors
its own retrieval predicate directly, and a test asserts the two agree by
draining the queue and counting what came out.

The interface carries a working default that filters `retrieveAll`, which is
correct for any backend and reads every entry. `implements` copies signatures
only, so a custom backend still has to declare it — that is a compile error
rather than a runtime surprise, which is the better of the two.

**M9** turned out to have a layer under it. The finding is that no library code
records a metric, so every rate reads zero; that is true, and a queue can now be
given a `QueueMetrics` and records enqueues, dequeues, completions, failures,
latencies and processing times against it. `QueueManager` takes one too, so an
application's queues report to a single collector.

The layer underneath: **the health check API was never exported**. The README
documents `HealthCheckAggregator`, `StorageHealthCheck`, `MetricsHealthCheck`
and `QueueHealthCheck`, and `lib/duraq.dart` exported none of them, so a reader
following the README got "Method not found". The existing test passed only
because it imported the `src/` path directly — a test reaching around the public
API and therefore unable to notice that the API was not there.

Both checks were reporting on queues that did not exist: `MetricsHealthCheck`
probed one named `health-check`, `QueueHealthCheck` asked for the size of one
named `default`. `QueueHealthCheck` now reads every queue the storage knows
about — or the ones it is told to watch — and reports waiting and ready counts
per queue from the storage itself, which is where M7 pays off: its optional
`maxReadyBacklog` threshold is compared against work that can be done now, so a
queue full of entries scheduled for next week does not read as falling behind.

Writing the tests turned up one design point worth recording. `getErrorRate` is
`errors / throughput`, so recording throughput only on success made the rate
exceed 1: three failures against one success read as 3.0. Throughput counts
attempts, and the rate is the share of attempts that failed.

Running the health check also samples each queue's size into the collector,
which is what makes `getCurrentQueueSize` report anything at all — nothing else
ever called `recordQueueSize`, so that metric would otherwise have stayed dead
in a fix aimed at exactly that.

The old health test asserted `details['queueSize'] == 5` after recording a size
against the queue named `default`. It encoded the defect, so it was rewritten
rather than kept.

### Status: M11 and M14 fixed

**M11.** `close()` is on `StorageInterface` and both backends implement it, so
shutdown can be written once against the interface. `dispose()` stays on both
concrete classes for callers already using it. The Isar backend still leaves the
Isar instance open, because the caller opened it and may be sharing it — that is
a property worth keeping, not an oversight.

**M14.** The default is unchanged: write-ahead logging at `synchronous = NORMAL`
is the right default and is what every release so far used. What was missing is
the ability to say otherwise, and a statement of what the default costs. Both
now exist.

The measurement had to be done carefully. `synchronous` is a property of the
*connection*, not of the file, so the obvious check — open a second connection
and read the pragma — reports that connection's own default and says nothing.
That is why `activeSynchronous` reads the setting back from the live connection,
and why a test asserts two storages on one file can run at different settings.

The first benchmark was also wrong: too few iterations on a fresh database per
mode, which produced the nonsense of `FULL` measuring faster than `OFF`. Five
interleaved rounds of 1,500 enqueues, medians:

| Setting | Single enqueues/s | vs NORMAL |
| --- | --- | --- |
| off | 15,042 | +11.5% |
| **normal** (default) | **13,496** | — |
| full | 6,913 | −48.8% |
| extra | 6,947 | −48.5% |

So durability at `full` costs about half the enqueue throughput on this machine,
and `extra` buys nothing over `full` on APFS. That is the number a caller needs
to make the trade, and it is now in the README.

### Status: M12 fixed

The Isar backend is its own package, `packages/duraq_isar`. A SQLite-only
project no longer resolves `isar`, its generated code, or its version
constraint. Dart has no optional dependencies, so a split was the only way to
get there.

The repository is now a monorepo: `packages/duraq` and `packages/duraq_isar`,
with `docs/`, `tool/` and the CI workflow at the root. `tool/verify.sh` analyses
and tests both, so the gate did not change shape.

**The test split was the real work.** Eight of the eleven Isar test files also
tested SQLite, and duplicating those suites would have left two descriptions of
one contract to drift apart. Instead the parameterized suites moved to
`packages/duraq/test/support/`, where each takes an opener and knows nothing
about which backend it is running against. `duraq` supplies the SQLite opener,
`duraq_isar` supplies the Isar one and reaches across to the same suites. That
is one description of the contract, run twice — and it gives the README's
"custom storage implementations via `StorageInterface`" something concrete
behind it. The four hand-written files that had a group per backend were simply
cut in half.

Counts are unchanged by the split: 212 tests in `duraq`, 77 in `duraq_isar`,
289 in total.

**Two things surfaced that were nothing to do with the split**, both because
moving the package re-resolved its dependencies for the first time in this work
— `pubspec.lock` is not tracked, so everything until now had been running
against versions pinned months ago.

The first: **the package does not build cleanly against the newest `sqlite3` its
own constraint allows.** `sqlite3` 3.0 renamed `Database.dispose` to `close` and
deprecated the old name, and the constraint spans `>=2.2.0 <4.0.0`, where 2.x
has only `dispose`. Neither name is clean across the range, so the fifteen call
sites carry a targeted `// ignore: deprecated_member_use` with the reason and
the condition for removing it. CI on a fresh runner would have hit this on its
first green-field resolve; a tracked lock file had been hiding it.

The second: **the Isar suites cannot run at the default test concurrency.** Isar
holds a native database per open instance and these suites open one per test;
above a low ceiling the test process is killed outright — exit 137, not a
failure — on some runs and passes on others. Measured at one kill in two runs at
the default and one in four at concurrency 4; concurrency 2 was clean across
repeated runs with recompilation forced each time, and costs about a second.
`packages/duraq_isar/dart_test.yaml` pins it, with that measurement written
down, because a suite that dies rather than failing is the worst kind of flake:
it looks like infrastructure.

### Status: a sixth flake, caught by the gate on a push

The pre-push hook refused a push to main: `lease_reclaim_test`, on the Isar
side, expected a claimed entry to stay claimed and got it handed back.

It was not a regression. The suite gave every test in the group a 200ms lease,
and the failing test asserts a claim is *held* — so it depended on less than
200ms of wall clock passing between two of its own statements. Under the load
of a push, more than 200ms passed, the lease lapsed, the entry was reclaimed,
and the second retrieval returned it. The assertion was reporting the clock,
not the queue.

Confirmed by injecting a 500ms stall between the two retrievals: with the
group's 200ms lease that reproduces the push failure exactly, and with a lease
that cannot lapse it passes. The test now asks for a five-minute lease; the
tests around it that assert a claim *expires* keep the short one, because
waiting longer than a lease is a safe direction to be wrong in. Both backends'
halves were changed, since both had the same latent assumption.

This is the sixth flake `--flake` mode or the gate has surfaced, and the fourth
of this shape: an assertion that reports how fast the machine was rather than
what the code did. Two of the six turned out to be real defects — colliding
lock ids, and the Isar suites being killed rather than failing at the default
test concurrency.

Worth stating plainly, since it is the argument for the gate: this one was
caught by the hook, on the way out, on a machine busy enough to expose it. A
green local run had passed five times in a row beforehand.

### Status: what CI found on its first real run

The gate ran on a machine that was not this one, for the first time in the
package's history. It failed, and both failures were real.

**The Isar suites died with a bus error.** `si_signo=Bus error(7),
si_code=BUS_ADRERR(2)`, a core dump, no catchable error. Isar memory-maps a file
of `maxSizeMiB`, default 512 MiB, and only the shared opener was capping it —
the six test files that open Isar directly were each mapping half a gigabyte. On
a Linux runner the temporary directory is backed by RAM, so several of those at
once exhaust it and a write into the mapping dies with SIGBUS. macOS backs
`/tmp` with disk, which is why every local run passed. Every `Isar.open` in the
tests now goes through one helper that caps the mapping at 32 MiB.

**The advertised SDK floor was false.** The advisory job builds on the oldest
SDK the pubspecs claim, and reported: `Because duraq depends on sqlite3 >=2.2.0
which requires SDK version >=3.2.0 <4.0.0, version solving failed.` The floor
had been `>=3.0.0` and nothing could ever have satisfied it — raising the
sqlite3 constraint to 2.2.0 for `updatedRows` had silently raised the real
floor too. Both pubspecs now say `>=3.2.0`, and the job builds on 3.2.

Neither of these was reachable from a developer machine. The first needed a
different operating system, the second needed somebody to actually try the
version being advertised. That is the argument for the gate running somewhere
other than where the code is written, and it paid for itself on the first push.

## Test suite and process (Q1–Q6)

| ID | Severity | Finding |
| --- | --- | --- |
| Q1 | Critical | **The published version does not pass its own tests.** On a clean checkout of this commit the concurrent processing test fails deterministically. A release went out with a red suite, so the suite is not gating anything. |
| Q2 | High | **Coverage is thinnest exactly where the risk is.** 48.7% of the library excluding generated code; the two storage backends hold nearly all the complexity and are the least covered files of any real size. |
| Q3 | High | **The isolation test cannot fail.** `transaction_test.dart:142` runs two concurrent transactions and then asserts `futures.length == 2`. It passes while isolation is broken, which is how C1 survived to release. The durability step in the same test reopens the file in the same process, which does not exercise durability either. |
| Q4 | High | **No CI and no lint configuration.** No `.github` directory, so nothing runs the suite on a push. No `analysis_options.yaml`, so the `lints` dev dependency is never applied. `dart analyze` reports 40 issues under defaults, including two deprecated `getUpdatedRows` calls on the lock path. |
| Q5 | Medium | **The untested behaviours are the ones that fail.** Nothing covers crash recovery, retry timing, lease expiry, multi-process access, duplicate identifiers, dead-letter lock release, TTL of an in-flight entry, or behaviour at any real backlog size. Every critical defect sits in that gap. |
| Q6 | Medium | **Tests lean on real databases and wall-clock waits.** `packages/duraq/test/utils/mock_storage.dart` is present but unused; timing-sensitive assertions rely on real delays. Both will turn flaky on shared CI hardware. |


### Status: Q4 fixed, Q6 partly

**Q4.** There is now one gate, `tool/verify.sh`, which runs
`dart analyze --fatal-infos --fatal-warnings` and then the suite. Three things
call it: a developer, the `pre-push` hook in `.githooks/` (installed by
`tool/install-hooks.sh`, which sets `core.hooksPath` so the hook is version
controlled rather than copied), and `.github/workflows/ci.yml`. The whole gate
takes about five seconds, which is why it is affordable on every push.

`analysis_options.yaml` finally applies the `lints` dependency that has been
declared since 1.0.0. It adds `strict-casts`, `strict-raw-types` and eight rules
chosen for the failure modes this audit found, `unawaited_futures` and
`discarded_futures` above all — a silently dropped future is the shape C1
through C4 all shared. Generated Isar code is excluded; `test/analysis_options.yaml`
turns off `only_throw_errors` and `avoid_slow_async_io`, which are about shipped
code rather than tests.

Clearing the 40 pre-existing issues took four changes, none of them behavioural:
29 raw generic types written out as `QueueEntry<dynamic>`, two unused imports
removed, two relative `../../lib` imports in `isar_storage_test.dart` changed to
package imports, and the two deprecated `getUpdatedRows()` calls replaced with
`updatedRows`. That last one moved the `sqlite3` floor from 2.1.0 to 2.2.0,
which is where the replacement landed.

`dart analyze` now reports nothing at all, for the first time in the package's
history.

The gate was checked in both directions rather than assumed: with an unused
import added it exits 1 on the analyze step, and with one deliberately broken
expectation it exits 1 on the test step. CI on the oldest supported SDK is a
separate, non-blocking job, because the `>=3.0.0` floor in pubspec has never
been built and reporting on an untested claim is not the same as gating on it.

**Q6.** `tool/verify.sh --flake N` runs the suite N times. It found a real flake
on its second run: `contention_test.dart` asserted that more than five timer
ticks land during a 300 ms contended write, and a loaded machine delivered four.
The property worth asserting is that the isolate is not held for the entire
wait, and a blocking implementation scores exactly zero on that regardless of
load, so the bar is now two. Three consecutive runs pass, including three with
six cores deliberately saturated.

A third flake, found the same way while the M1 to M3 work was in flight, was not
a timing assertion at all. Every Isar suite called
`Isar.initializeIsarCore(download: true)`, which downloads the native library
next to the running script — under `dart test` that is one temporary directory
shared by the whole run. Seven suites now use Isar, they start together, and a
suite reading the file mid-download failed with "fat file, but missing
compatible architecture", which reads like a platform mismatch and is really a
race. `test/utils/isar_test_core.dart` retries until the download settles and
memoises the result per process. It failed about one run in five before; 14
consecutive runs pass after, six of them with six cores saturated.

That is two timing assertions and one download race found this way. The
underlying finding stands: the suite still drives real databases and real
elapsed time, and `packages/duraq/test/utils/mock_storage.dart` is still barely used.

The format check is deliberately **not** in the gate. Dart 3.11 formats in the
tall style, which rewrites 35 of the 46 source files, and restyling a published
package is a decision for its owner rather than a side effect of adding CI.

Line coverage by file, 84 tests, generated code excluded:

| File | Covered | Lines |
| --- | --- | --- |
| `storage/isar_lock.dart` | 25.9% | 29 / 112 |
| `storage/isar_storage.dart` | 28.5% | 172 / 604 |
| `queue_entry.dart` | 48.5% | 32 / 66 |
| `storage/sqlite_storage.dart` | 68.5% | 150 / 219 |
| `queue.dart` | 70.3% | 26 / 37 |
| `health/health_check.dart` | 84.6% | 33 / 39 |
| `concurrent/queue_lock.dart` | 100% | 53 / 53 |
| **Library total** | **48.7%** | 618 / 1268 |

---

## What holds up — keep these decisions

- **The layering is right.** Queue, storage interface, retry policy and dead
  letter queue are cleanly separated, which is why most fixes are local.
- **The SQL is parameterised throughout.** No string interpolation of user data
  anywhere in either backend.
- **The SQLite schema is well chosen.** The composite retrieval index matches
  the query and the partial indexes are the right instinct; one just needs the
  column order that would let the planner use it.
- **The dead letter API is complete.** Retrieve, list with paging, retry, remove
  and purge, all covered by tests — the best-tested area of the package.
- **Savepoint nesting is the correct mechanism.** Only the bookkeeping that
  decides when a savepoint is nested needs replacing.
- **The recent fixes were real.** Releasing the lock when an entry is retried
  back to pending, and widening the driver constraint, both addressed genuine
  problems.

---

## Suggested order of work

1. **Serialize access to the storage object** — closes the interleaving behind
   both the transaction corruption and the phantom-empty queue, and removes the
   races underneath several lock findings. *(C1, C2, H2)*
2. **Make a claim recoverable** — honour the retry time in the candidate query,
   persist the lease on the entry, reclaim expired leases on retrieval and at
   startup. This is what makes the package durable in the sense the name
   promises. *(C3, C4, M1, M4)*
3. **Give Isar a unique entry and a real transaction** — a unique composite index
   stops duplicate delivery; scoping the body to one `writeTxn` restores
   atomicity. If neither is worth the effort, the honest alternative is to
   withdraw the backend. *(C5, C6, M12)*
4. **Take avoidable work out of the dequeue path** — move the expiry sweep to
   maintenance, replace the offset walk, let the Isar queries use the indexes the
   model already declares. *(H4, H5)*
5. **Define the lifecycle at the interface** — retention and maintenance,
   teardown, a package-level error type, and one agreed answer to storing a
   duplicate identifier. *(H6, H7, M11)*
6. **Configure for the concurrency you invite** — busy timeout and contention
   retries, lock release scoped to the owner, and a README section stating what
   is supported across processes and what is not. *(H1, H3, M14)*
7. **Put a gate in front of the next release** — CI on every push, an analyzer
   configuration that applies the lints already listed as a dependency, and a
   regression test for each defect above, starting with the one that is red
   today. *(Q1, Q4, Q5)*

---

## Method and scope

Every defect was reproduced against commit 5315698 with standalone programs
driving the public API. Query-plan and timing figures come from the same
database files the library creates. Benchmarks ran single-process on Dart
3.11.5, macOS arm64, one job per operation; treat them as relative shape, not as
absolute numbers for other hardware.

The review covers the library source, its test suite, and the README's claims.
Generated Isar code was read but not audited. No fixes were applied to the
repository.
