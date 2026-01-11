# CLI Authors: CommonShell vs Tuist Command

This guide helps CLI authors choose between using Tuist’s `Command` directly or
wrapping process execution with `CommonShell` (built on `CommonProcess`).

## TL;DR

- Prefer `CommonShell` in Wrkstrm CLIs. It encodes project policies: typed
  invocations (`Invocation`), runner selection, environment/host wrappers, timeouts,
  logging/instrumentation, and NDJSON/preview discipline.
- Use Tuist `Command` only for external projects that need a single, minimal
  `Process` wrapper and do not require codable invocations or runner abstraction.

## Surface Comparison

- Tuist Command
  - `Command.run([String], environment: [String:String], workingDirectory: Path.AbsolutePath?) -> AsyncThrowingStream<CommandEvent, Error>`
  - Streams stdout/stderr chunks; exit errors thrown on non‑zero.
  - Executable resolution by `which`/`where`.

- CommonShell (Wrkstrm)
  - `CommonShell` wraps an `Invocation` (codable) + convenience host helpers (`runEnv`, `runShell`, `runNpxCommand`).
  - Uses `CommonProcessRunners` with backends (Subprocess preferred; Foundation/TSC fallback).
  - Buffered or streaming modes; explicit `.completed` event on streaming; structured previews/logging/metrics.
  - Timeouts, tags, requestId, and instrumentation are first‑class options.

## Typical Flows

```swift
import CommonShell

// Bind to a known tool using name or absolute path
var shell = CommonShell(executable: .name("git"))

// Buffered run (returns ProcessOutput)
let out = try await shell.run(["status"], timeout: .seconds(5))
print(out.utf8Output())

// Streaming run (consume events)
let (events, cancel) = try shell.stream(["log", "--oneline"])
for try await e in events { /* .stdout/.stderr/.completed */  }

// Host wrappers (env/shell/npx/npm) set Invocation.hostKind appropriately
let envOut = try await shell.runEnv(["PATH"])  // runs env PATH
```

## When to Choose Which

- Choose `CommonShell` when you need:
  - Typed, codable invocation for auditability.
  - Deterministic logging/preview capture and NDJSON discipline.
  - Timeouts and cancellation policy exposed explicitly.
  - Pluggable backends (Subprocess where available) and cross‑platform runners.
  - Host wrappers (env/shell/npx/npm) and option builders.

- Choose Tuist `Command` when you need:
  - Minimal, Process‑only streaming for a small external utility.
  - No need for codable invocations, metrics, or runner abstraction.

## Migration Sketch (Command → CommonShell)

```swift
// Before (Tuist Command)
let stream = Command.run(arguments: ["swift", "--version"])  // iterate events

// After (CommonShell)
var sh = CommonShell(executable: .name("swift"))
let out = try await sh.run(["--version"], timeout: .seconds(5))
print(out.utf8Output())
```

## Policy Reminders (Wrkstrm)

- Don’t use `Foundation.Process` directly in CLIs — use `CommonShell`/`CommonProcess`.
- Prefer `Executable.name("tool")` over PATH‑searching at runtime; avoid `which` shellouts when identity is known.
- Keep outputs human‑grade and machine‑friendly: pretty/sorted JSON for files; NDJSON with one line per record.
