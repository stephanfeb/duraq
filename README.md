# DuraQ

A durable queuing system implemented in Dart.

This repository holds two packages:

| Package | What it is |
| --- | --- |
| [`packages/duraq`](packages/duraq) | The queue: queues, retry policies, dead letters, maintenance, health checks, and the **SQLite** storage backend. |
| [`packages/duraq_isar`](packages/duraq_isar) | The **Isar** storage backend, as a separate package so a SQLite-only project does not resolve `isar` and its generated code. |

Start with [the duraq README](packages/duraq/README.md).

## Working on it

One command checks everything that has to hold, across both packages:

```bash
tool/verify.sh            # analyze with --fatal-infos, then both test suites
tool/verify.sh --flake 5  # run the suites repeatedly, to hunt timing flakes
tool/install-hooks.sh     # run the gate before every push
```

The storage contract is described once, in `packages/duraq/test/support/`, and
run against both backends: `duraq`'s tests supply the SQLite opener and
`duraq_isar`'s supply the Isar one, so neither backend can quietly drift from
the other.

## Audit

`docs/audit/` holds the durability audit this codebase was remediated against,
with every finding, its status, and the decisions worth not relitigating.
