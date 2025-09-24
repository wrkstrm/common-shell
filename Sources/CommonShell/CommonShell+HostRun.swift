import CommonProcess
import CommonProcessRunners
import Foundation
import WrkstrmLog

extension CommonShell {
  /// Run using an explicit execution host and executable identity.
  @discardableResult
  public func run(
    host: ExecutionHostKind,
    executable: Executable,
    arguments: [String] = [],
    runnerKind: ProcessRunnerKind? = nil,
  ) async throws -> String {
    try await run(
      host: host,
      executable: executable,
      arguments: arguments,
      environment: nil,
      runnerKind: runnerKind,
    )
  }

  /// Run using an explicit execution host, propagating custom environment values.
  @discardableResult
  public func run(
    host: ExecutionHostKind,
    executable: Executable,
    arguments: [String] = [],
    environment: [String: String]? = nil,
    runnerKind: ProcessRunnerKind? = nil,
    timeout: Duration? = nil,
  ) async throws -> String {
    var shell = self
    shell.hostKind = host
    shell.executable = executable
    let envModel: EnvironmentModel? = environment.map { EnvironmentModel.inherit(updating: $0) }
    if let environment, !environment.isEmpty {
      Log(
        system: "common-shell",
        category: "environment",
        maxExposureLevel: .trace,
        options: [.prod]
      ).trace("forwarding env keys=\(environment.keys.sorted()) host=\(host)")
    }
    return try await shell.execute(
      arguments: arguments,
      runnerKind: runnerKind ?? .auto,
      environment: envModel,
      timeout: timeout,
    )
  }

  func execute(
    arguments: [String],
    runnerKind: ProcessRunnerKind,
    environment: EnvironmentModel? = nil,
    timeout: Duration? = nil,
  ) async throws -> String {
    var invocation = makeInvocation(
      arguments: arguments, environment: environment, timeout: timeout)
    invocation.runnerKind = runnerKind
    let resolved = resolveHost(invocation)
    let runner = CommonProcessRunners.make(kind: runnerKind).makeRunner(for: resolved)
    let output = try await runner.runWithTimeout(invocation: resolved)
    switch output.exitStatus {
    case .exited(code: 0):
      return output.utf8Output()

    case .exited(let code):
      throw ProcessError(status: code, error: String(decoding: output.stderr, as: UTF8.self))

    case .signalled(let signal):
      throw ProcessError(status: signal, error: String(decoding: output.stderr, as: UTF8.self))
    }
  }

  func makeInvocation(
    arguments: [String],
    environment: EnvironmentModel?,
    timeout: Duration?,
  ) -> Invocation {
    var options = makeProcessOptions()
    if let hostKind {
      var tags = options.tags ?? [:]
      tags["executionHost"] = hostKind.label
      options.tags = tags
    }
    return Invocation(
      executable: executable,
      args: arguments,
      env: environment,
      workingDirectory: workingDirectory,
      logOptions: options,
      instrumentationKeys: [],
      hostKind: hostKind,
      instrumentation: instrumentation,
      requestId: UUID().uuidString,
      runnerKind: nil,
      timeout: timeout
    )
  }

  func resolveHost(_ invocation: Invocation) -> Invocation {
    guard let hostKind = invocation.hostKind else { return invocation }
    let host = hostKind.makeHost()
    return host.resolve(invocation: invocation)
  }
}
