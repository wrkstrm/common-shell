# CommonShell – Process Execution Wrapper

| GitHub Actions | Status |
| -------------- | ------ |
| Workflows | [![Test: CommonShellTests][tests-core-badge]](https://github.com/wrkstrm/common-shell/actions/workflows/common-shell-tests-commonshell-tests.yml) [![Test: CommonShellCLITests][tests-cli-badge]](https://github.com/wrkstrm/common-shell/actions/workflows/common-shell-tests-commonshell-cli-tests.yml) [![Test: CommonShellInteractiveTests][tests-interactive-badge]](https://github.com/wrkstrm/common-shell/actions/workflows/common-shell-tests-commonshell-interactive-tests.yml) [![Test: CommonShellBenchTests][tests-bench-badge]](https://github.com/wrkstrm/common-shell/actions/workflows/common-shell-tests-commonshell-bench-tests.yml) [![Swift Format — common-shell][format-badge]](https://github.com/wrkstrm/common-shell/actions/workflows/common-shell-swift-format.yml) [![DocC — common-shell][docc-badge]](https://github.com/wrkstrm/common-shell/actions/workflows/common-shell-docc.yml) |

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

CommonShell is a thin, typed shell adapter that builds on CommonProcess (>= 0.2.0)
to plan and execute commands consistently across hosts and runners.

## Quickstart

Add to your Package.swift dependencies:

```swift
.package(url: "https://github.com/wrkstrm/common-shell.git", from: "0.1.0")
```

Then import and run a command:

```swift
import CommonShell

var shell = CommonShell(executable: .name("git"))
shell.hostKind = .env(options: [])
let out = try await shell.run(arguments: ["status"])  // throws on non-zero exit
print(out)
```

```
               ┌──────────────────▶ │  CommandSpec │  What to run (ExecutableRef)
               │
CommonShell ──▶├──────────────────▶ │  Execution Host    │  How to wrap the tool
               │
CommonProcess ─├──────────────────▶ │  Runner (route)    │  How to execute
               │
Instrumentation├──────────────────▶ │  Telemetry         │  Logging/metrics exposure
```

- `ExecutableReference` stays the source-of-truth for identity: `.name("git")`, `.path("/usr/bin/git")`, `.none` (argv-only).
- Hosts describe how to wrap the executable before dispatching to CommonProcess:
  - `.direct`
  - `.shell(options:)`
  - `.env(options:)`
  - `.npm(options:)`
  - `.npx(options:)`
- Runners (`ProcessRunnerKind`) handle the actual execution surface (Subprocess/Foundation/TSCBasic/Native).
- Instrumentation and metrics tag invocations automatically (host kind propagates via `ProcessLogOptions.tags`).

## CommandSpec-first Model

```swift
public struct CommandSpec: Codable, Sendable {
  public var executable: Executable
  public var args: [String]
  public var env: EnvironmentModel?
  public var workingDirectory: String?
  public var logOptions: ProcessLogOptions = .init()
  public var requestId: String = UUID().uuidString
  public var instrumentationKeys: [InstrumentationKey] = []
  public var hostKind: ExecutionHostKind? = nil
  public var runnerKind: ProcessRunnerKind? = nil
  public var timeout: Duration? = nil
  public var instrumentation: ProcessInstrumentation? = nil  // runtime-only
}
```

- `.name("git")` selects PATH lookup → typically `hostKind = .env`.
- `.path("/usr/bin/git")` → `hostKind = .direct`.
- Wrapper helpers (e.g. `CommonShell.runShell`, `runEnv`, `runDirect`, `runNpxCommand`) set `hostKind` for you.

### Instrumentation

- Built-in keys: `.noop`, `.metrics` (via `ProcessMetricsRecorder`).
- `ProcessLogOptions.tags["executionHost"]` records the host label automatically.

## Running Commands

```swift
var shell = CommonShell(executable: .name("git"))
shell.hostKind = .env(options: [])
let status = try await shell.execute(arguments: ["status"], runnerKind: .auto)
```

Convenience wrappers:

- `runDirect` – sets `hostKind = .direct`
- `runShell` – sets `hostKind = .shell(options:)`
- `runEnv` – sets `hostKind = .env(options:)`
- `runNpxCommand` – resolves node/npm CLI and sets `hostKind = .npx(options:)`
- `runForInterval` – benchmarks a host × runner combination

All `run` APIs accept an optional `timeout:` parameter (`Duration`). When supplied, CommonShell cooperatively cancels the underlying runner once the timeout elapses and throws a `ProcessError` with `timedOut = true`.

Low-level entry point:

- `run(host:executable:arguments:runnerKind:)` — explicitly supply the host transform and executable identity.

## Route Planning & Benchmarking

- `ShellRouteKind` still enumerates runners (`.auto`, `.native`, `.subprocess(kind)`).
- Bench helpers (`BenchRoutes`, `BenchSupport`) now operate over `(host: ExecutionHostKind, executable: Executable, arguments: [String]) × [ShellRouteKind]`.
- CSV/JSON/Table outputs include both host label (`wrapper`) and runner route (`route`).

## Relationship to CommonProcess

- Hosts produce new `CommandSpec` instances with transformed `Executable`+args.
- CommonProcess runners execute any invocation regardless of host choice.
- Instrumentation/hardware metrics are shared across hosts and routes.

## Docs

- API guides live under `Sources/CommonShell/Documentation.docc/`.
- Comparison for CLI authors: `CommonShell-Comparison-TuistCommand.md` (when to use CommonShell vs Tuist Command).

## License

MIT — see `LICENSE`.

## Platforms

- macOS 14+, iOS 17+, Mac Catalyst 17+

## Dependencies

- CommonProcess (>= 0.2.0)
- WrkstrmLog/WrkstrmFoundation (>= 2.0.0)
- wrkstrm-performance (>= 0.1.0)

## CI

- Linux CI: build + test via swift‑ci
- Format lint and DocC workflows mirror CommonProcess

## Contributing

Use CommonProcess/CommonShell runners; avoid `Foundation.Process` at call sites.
See CONTRIBUTING.md for guidelines.

## Security

Report via GitHub Security Advisories (see SECURITY.md).

## Changelog

See CHANGELOG.md.

[tests-core-badge]: https://github.com/wrkstrm/common-shell/actions/workflows/common-shell-tests-commonshell-tests.yml/badge.svg
[tests-cli-badge]: https://github.com/wrkstrm/common-shell/actions/workflows/common-shell-tests-commonshell-cli-tests.yml/badge.svg
[tests-interactive-badge]: https://github.com/wrkstrm/common-shell/actions/workflows/common-shell-tests-commonshell-interactive-tests.yml/badge.svg
[tests-bench-badge]: https://github.com/wrkstrm/common-shell/actions/workflows/common-shell-tests-commonshell-bench-tests.yml/badge.svg
[format-badge]: https://github.com/wrkstrm/common-shell/actions/workflows/common-shell-swift-format.yml/badge.svg
[docc-badge]: https://github.com/wrkstrm/common-shell/actions/workflows/common-shell-docc.yml/badge.svg
