# Shell + ExecutableReference Quickstart

Getting productive with CommonShell using the unified ExecutableReference/Executable identity.

## Overview

CommonShell is a lightweight adapter on top of CommonProcess. Prefer using the
unified `ExecutableReference` and `Executable` (from `CommonProcessRunners`) to
express what you want to run and keep wrapper policy at the shell layer.

```swift
import CommonShell
import CommonProcessRunners

// A neutral base configured to use /usr/bin/env by default
let shell = CommonShell(executable: Executable.path("/usr/bin/env"))
```

## One‑shot runs with `run(reference:)`

Run a PATH tool with extra flags:

```swift
let out = try await shell.run(
  reference: .name("echo"),
  defaultOptions: ["-n"],
  args: ["hello"]
)
// -> "hello"
```

Run a direct path:

```swift
let out = try await shell.run(
  reference: .path("/bin/pwd"),
  args: []
)
```

Supply default arguments (prefix subcommands):

```swift
let gitStatus = try await shell.run(
  reference: .name("git"),
  defaultArguments: ["status"],
  args: ["--porcelain"]
)
```

## Pre‑binding with `withExec(reference:)`

Create a shell pre‑bound to a tool by name (env) or path (direct) with optional
default options/arguments.

```swift
var base = shell

// Name: binds to /usr/bin/env and prefixes the tool
let git = base.withExec(reference: .name("git"))
print(try await git.run(args: ["status"]))

// Path: binds directly
let directEcho = base.withExec(reference: .path("/bin/echo"))
print(try await directEcho.run(args: ["ok"]))
```

## Hosts when you need them

`run(reference:)` and `withExec(reference:)` pick appropriate transports under
the hood. If you need explicit host control (shell/env/npm/npx), use the
host-aware helpers:

```swift
// Shell host convenience with override identity
print(try await shell.run(host: .shell(options: []), identity: .path("/bin/sh"), args: ["echo via shell"]))

// Env host with explicit options via the low-level API
print(try await shell.run(
  host: .env(options: ["-n"]),
  executable: Executable.name("echo"),
  arguments: ["ok"]
))
```

## Duration benchmarks

Assess wrapper or route overhead by running as many iterations as possible
within a fixed time budget:

```swift
let res = try await shell.runForInterval(
  host: .env(options: []),
  executable: Executable.name("echo"),
  arguments: ["bench"],
  runnerKind: .auto,
  durationSeconds: 0.25
)
print(res.iterations, res.averageMS)
```

## CLI: CommandInvocation JSON + flags

Use the `common-shell-cli` to execute a codable `CommandInvocation` from JSON. The CLI accepts:

- ``--runner-kind`` to choose `auto|subprocess|foundation|tscbasic`
- ``--instrumentation-key`` to select an instrumentation sink (e.g., `noop`)
- ``--log-level`` to control exposure (`none|summary|verbose`)

Example payload:

```json
{ "executable": { "ref": { "name": "echo" } }, "args": ["hello"] }
```

Run it:

```
swift run --package-path code/mono/apple/spm/universal/common/domain/system/common-shell common-shell-cli \
  --runner-kind auto --instrumentation-key noop < /path/to/invocation.json
```

## Design philosophy (L0–L4)

- Level 0 — process: CommonProcess identity/invocation/runners.
- Level 1 — shell: CommonShell convenience and logging.
- Levels above: CommonCLI adapters (L2), typed options (L3), and native implementations (L4).

See docs/reference/architecture/domains/common-shell-cli.md for the full rationale and guidance on choosing levels.

### Type safety and autonomy

- Strongly typed options (in CommonCLI and shared spec modules) constrain
  command surfaces so automated agents generate only valid invocations.
- Validations catch conflicts/missing fields before a subprocess is spawned.
- Structured, typed invocations are easier to log and audit, enabling policy
  gates for unattended operation.
