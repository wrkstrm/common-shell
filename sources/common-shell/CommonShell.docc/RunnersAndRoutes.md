# Runners & Routes Quickstart

Choosing how processes are executed and exploring route planning.

## Runner Kinds

CommonProcess provides multiple runner backends (availability depends on platform/build):

- ``.subprocess`` — uses the swift-subprocess library when available
- ``.tscbasic`` — uses Swift Tools Support Core (TSCBasic.Process)
- ``.foundation`` — uses Foundation.Process
- ``.auto`` — selects the best available for the current platform

Pick explicitly on any CommonShell `run`/`runForInterval` via `runnerKind:`:

```swift
import CommonProcessExecutionKit
import CommonShell

let sh = CommonShell(executable: Executable.path("/usr/bin/env"))
let out = try await sh.run(
  host: .env(options: []),
  executable: Executable.name("echo"),
  arguments: ["hi"],
  runnerKind: .foundation
)
```

CLI flags:

- ``--runner-kind`` to request a backend (falls back when unsupported)

## Execution Hosts

Execution hosts determine how CommonShell wraps the underlying command before invoking the runner:

- ``.direct`` — run the target executable as-is.
- ``.shell(options:)`` — wrap with `/bin/sh -c` (options forwarded before `-c`).
- ``.env(options:)`` — prefix `/usr/bin/env` and insert the tool token.
- ``.npm(options:)`` — execute via `/usr/bin/env npm`.
- ``.npx(options:)`` — resolve Node/npm npx CLI (falls back to `/usr/bin/env npx`).

Hosts compose with runner routes. Bench helpers enumerate host × route combinations for matrix runs.

## Route Planning

Some tools and hosts benefit from exploring multiple execution routes and comparing
performance. CommonShell exposes a route model and bench helpers:

- ``ShellRouteKind`` — enumerates `auto`, `native` (reserved), and `subprocess(kind)`
- ``BenchRoutes.routes(using:)`` — recommended platform routes
- ``BenchRoutes.cross(hosts:routes:)`` — compose a matrix of host × route

The `common-shell-bench` executable accepts `--routes-spec` to override runners at the CLI:

```bash
common-shell-bench \
  --hosts direct,shell,env \
  --routes-spec platform \
  --payload bench --duration 0.25 --format table
```

Use the `metrics` subcommand when you need latency plus throughput snapshots. Combine
`--duration` with the new `avg_hz` column to see iterations-per-second for each host × route:

```bash
common-shell-bench metrics \
  --hosts direct,shell \
  --runners auto \
  --duration 1 \
  --iterations 1
```

`--routes-spec` values:

- ``platform`` — expand to the best routes for this platform
- ``auto`` — just auto
- ``native`` — reserved (future native adapter)
- ``subprocess:<runner>[,…]`` — one or more of `foundation,tscbasic,subprocess`

## Duration Benchmarking

Use `runForInterval` to measure host overhead or compare routes:

```swift
let res = try await sh.runForInterval(
  host: .env(options: []),
  executable: Executable.name("echo"),
  arguments: ["bench"],
  runnerKind: .auto,
  durationSeconds: 0.25
)
print("iterations=\(res.iterations) avg_ms=\(String(format: "%.3f", res.averageMS))")
```

See also: `common-shell-bench --help` for more options, including CSV/JSON output formats.
