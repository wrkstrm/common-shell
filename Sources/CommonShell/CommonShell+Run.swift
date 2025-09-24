import CommonProcess
import Foundation

extension CommonShell {
  /// Run with a one-off host override, optionally supplying an executable identity.
  /// - Parameters:
  ///   - host: Execution host to use for this run (e.g., `.direct`, `.shell(options:)`, `.env(options:)`).
  ///   - identity: Optional executable identity to use just for this call; if nil, uses the shell's bound executable.
  ///   - args: Arguments to pass to the invocation. Note: for `.shell`, provide a single string command line in `args`.
  ///   - includeDefaultOptions: When `identity` is nil and host is `.direct`, controls whether to include the bound executable's default options.
  @discardableResult
  public func run(
    host overrideHost: ExecutionHostKind,
    identity: ExecutableReference? = nil,
    args: [String] = [],
    includeDefaultOptions: Bool = true,
    timeout: Duration? = nil,
  ) async throws -> String {
    var exec = executable
    if let ref = identity {
      switch ref {
      case .name(let n): exec = .name(n)
      case .path(let p): exec = .path(p)
      case .none: exec = .none()
      }
      if includeDefaultOptions { exec.options = executable.options }
    } else if !includeDefaultOptions {
      exec.options = []
    }
    return try await run(
      host: overrideHost,
      executable: exec,
      arguments: args,
      runnerKind: nil,
      timeout: timeout
    )
  }
}
