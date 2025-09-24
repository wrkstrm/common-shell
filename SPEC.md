# CommonShell API Spec (v0.1 – planning)

## Goal

- Establish a small, stable execution layer used by CLIs and tools, replacing CommonShell without shims.
- Live at `code/mono/apple/spm/universal/common/domain/system/common-shell`.
- Match existing call‑site constructor shapes so compile errors drive missing behavior, not mismatched signatures.

## Package Layout

- Package: common (parent) – multi‑target SPM package
  - Target `CommonProcess`: process abstraction (protocols + minimal types)
  - Target `CommonShell`: shell adapter built on CommonProcess

## CommonProcess (target)

- `enum ExecutableReference` (name|path)
- `struct Executable`
  - `ref: ExecutableReference` (identity)
  - `options: [String]`, `arguments: [String]` (prepend defaults)
- `struct Invocation` (Codable)
  - `executable: Executable`
  - `args: [String]` (call‑site)
  - `workingDirectory: String?`, `env: EnvironmentModel?`
  - `logOptions: ProcessLogOptions`, `requestId`, `instrumentationKey`, `runnerKind`
- `struct ProcessOutput` (from CommonProcessRunners)
  - `exitStatus: ProcessExitStatus` (enum: `.exited(code:Int)`, `.signalled(signal:Int)`)
  - `stdout: Data`, `stderr: Data`
  - `processIdentifier: String?`
  - `func utf8Output() -> String` (lossy OK)
- `struct ProcessError: Error, CustomStringConvertible` (from CommonProcessRunners)
  - `status: Int?`, `error: String`

## CommonShell (target)

- `struct CommonShell`
  - Properties
    - `executable: Executable`
    - `workingDirectory: String`
    - `logOptions: ProcessLogOptions` (exposure + preview caps)
    - `instrumentation: ProcessInstrumentation?` (optional hooks)
  - Initializer
    - `init(workingDirectory: String = ..., executable: Executable)`
  - Execution
    - `@discardableResult func run(_ arguments: [String]) async throws -> String`
    - `@discardableResult func run(arguments: [String]) async throws -> String`
    - `func launch(options: [String]) async throws -> ProcessOutput` (buffered)
  - ExecutableReference helpers
    - `run(reference:defaultOptions:defaultArguments:args:options:runnerKind:)` — compose and run with name|path
    - `withExec(reference:defaultOptions:defaultArguments:)` — pre-bind for repeated calls

## Instrumentation & Logging

- Use `ProcessInstrumentation` for hooks around execution.
  - `willStart(command: String, arguments: [String], workingDirectory: String, runnerName: String, requestId: String, startUptimeNs: UInt64)`
- `didFinish(command: String, arguments: [String], workingDirectory: String, runnerName: String, requestId: String, status: ProcessExitStatus, processIdentifier: String?, startUptimeNs: UInt64, endUptimeNs: UInt64, stdoutPreview: String?, stderrPreview: String?)`
- CommonShell forwards to `Invocation.instrumentation` (injected from `instrumentationKey`) and includes monotonic timestamps.
- Runners emit WrkstrmLog entries:
  - DEBUG: structured start block
  - INFO: one‑line summary (status, duration, cwd, cmd)
  - DEBUG (verbose): truncated output block according to log options caps

## Behavior & Semantics

- Command argv (effective): `executable.options + executable.arguments + invocation.args`.
- Working directory applies per run; defaults to `currentDirectoryPath`.
- Logging: `logOptions.exposure` controls echoing and preview bytes.
- Errors: non‑zero exit throws `ProcessError(status, stderrText)`.

## Compatibility & Migration Notes

- Imports: `import CommonShell` (no CommonShell imports; no shims).
- Types at call sites:
  - `var shell: CommonShell` (was `CommonShell` or generic `Shell`).
  - Result types referencing `CommonShell.Output` migrate to `CommonShell.Output`.
- Functions:
  - `run(_:)`/`run(arguments:)` return stdout `String` and throw on failure.
- `launch(options:)` returns buffered `ProcessOutput` with `utf8Output()` helper.
  - Runner selection (lower-level): `let out = try await CommonProcessRunners.make(kind: .auto).makeRunner(for: invocation).run()`.
- Migration:
  - Use `Executable.name(_:)` / `Executable.path(_:)` for identity.
  - Construct `Invocation(executable: Executable, args: ...)` and let runners resolve.

### Wrappers and PATH resolution

- Wrappers transform identity (name/path) into a finalized invocation using unified `Executable`:
  - `direct(path)`: set `Executable.path(path)`, prepend `options`, append call‑site args.
  - `shell(commandLine)`: use `Executable.path("/bin/sh")` with default `arguments = ["-c"]`; pass `commandLine` as a call‑site argument.
  - `env(name)`: use `Executable.path("/usr/bin/env")` with default `arguments = [name]`; pass call‑site args.
- Direct name support (ergonomic): when a direct executable string lacks `/`, CommonShell will
  attempt to resolve it on PATH (using `resolveAbsolute(_:)`). If resolution fails, a clear error
  is thrown. Prefer `.env(name:)` for PATH‑based invocation when portability matters.
- Wrapper sugar matches tau‑dev‑cli patterns (`shell.xcodebuild`, `shell.simctl`, `shell.openTool`).

### Examples

```swift
import CommonShell
import CommonProcessRunners

let sh = CommonShell(executable: Executable.path("/usr/bin/env"))

// PATH tool
print(try await sh.run(reference: .name("echo"), args: ["hi"]))

// Pre-bound by name (maps to env <tool> …)
let git = sh.withExec(reference: .name("git"))
print(try await git.run(args: ["status"]))

// Pre-bound by path (direct execution)
let pwd = sh.withExec(reference: .path("/bin/pwd"))
print(try await pwd.run(args: []))
```

## Out of Scope (v0.1)

- Streaming/PTY, interactive input, line‑by‑line coalescing.
- Global registries, environment mutation, or policy.

## Implementation Notes (source reference only)

- Use the existing CommonShell codebase as a reference to port minimal process‑running logic into `CommonProcess`/`CommonShell`. Do not depend on or re‑export CommonShell.
- Implement the smallest surface required by current call sites (blocking run + buffered output). Extend incrementally for streaming/interactive later.

## Validation

- Start by satisfying:
  - cli‑kit wrappers (Npm, XcodeBuild), tau‑dev‑cli usage, SystemScheduler calls.
  - clia commands (ExtractSDEF/Notify) compile with `import CommonShell`.
- Use compile errors to fill any missing initializers/aliases (without changing argument shapes).

## Versioning

- Tag v0.1 once all migrated targets compile; subsequent minors add streaming and richer error types.

## Deprecations

- Legacy per-call executable enum (`CommonShell.Executable { .name, .path }`)
  - Deprecated: during the ExecutableReference adoption.
  - Removed: replaced by `ExecutableReference` and helpers:
    - `run(exec: ...)` → `run(reference: ...)`
    - `withExec(_:)` → `withExec(reference:)`

- Legacy CommonProcessExecutable identity
  - Deprecated: during Executable adoption in CommonProcess.
  - Removed: use `Executable` directly (`.name(_:)` or `.path(_:)`).
