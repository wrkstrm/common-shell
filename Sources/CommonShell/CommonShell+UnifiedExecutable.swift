import CommonProcess
import CommonProcessExecutionKit
import Foundation

// MARK: - Unified Executable adoption helpers

extension CommonShell {
  /// Run using a unified ExecutableReference (name|path). This API is a bridge to begin adopting
  /// the new identity without touching higher‑layer wrappers.
  @discardableResult
  public func run(
    reference ref: ExecutableReference,
    defaultOptions: [String] = [],
    defaultArguments: [String] = [],
    args: [String] = [],
    options extra: [String] = [],
    runnerKind: ProcessRunnerKind? = nil,
    timeout: Duration? = nil,
  ) async throws -> String {
    let totalOptions = defaultOptions + extra
    let totalArgs = defaultArguments + args
    switch ref {
    case .name(let tool):
      let executable = Executable.name(tool)
      return try await run(
        host: .env(options: totalOptions),
        executable: executable,
        arguments: totalArgs,
        runnerKind: runnerKind,
        timeout: timeout
      )

    case .path(let p):
      let executable = Executable.path(p, options: totalOptions)
      return try await run(
        host: .direct,
        executable: executable,
        arguments: totalArgs,
        runnerKind: runnerKind,
        timeout: timeout
      )

    case .none:
      // argv-only: honor prefix defaults via Executable.none and let runner resolve first token
      let exec: Executable = .none(options: totalOptions, arguments: defaultArguments)
      return try await run(
        host: .direct,
        executable: exec,
        arguments: args,
        runnerKind: runnerKind,
        timeout: timeout
      )
    }
  }

  /// Produce a shell pre‑bound to an ExecutableReference with optional default prefixes.
  public func withExec(
    reference ref: ExecutableReference, defaultOptions: [String] = [],
    defaultArguments: [String] = [],
  ) -> CommonShell {
    var copy = self
    switch ref {
    case .name(let tool):
      var exec: Executable = .name(tool)
      exec.options = defaultOptions
      exec.arguments = defaultArguments
      copy.executable = exec
      copy.hostKind = .direct

    case .path(let path):
      var exec: Executable = .path(path)
      exec.options = defaultOptions
      exec.arguments = defaultArguments
      copy.executable = exec
      copy.hostKind = .direct

    case .none:
      copy.executable = .none(options: defaultOptions, arguments: defaultArguments)
      copy.hostKind = .direct
    }
    return copy
  }
}

// Legacy per-call executable enum removed; use ExecutableReference instead.
