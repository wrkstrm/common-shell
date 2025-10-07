import CommonProcess
import CommonProcessRunners
import Foundation

extension CommonShell {
  /// Buffered launch returning `ProcessOutput`.
  public func launch(options extra: [String]) async throws -> ProcessOutput {
    let opts = makeProcessOptions()
    let inv = CommandInvocation(
      executable: executable,
      args: extra,
      env: nil,
      workingDirectory: workingDirectory,
      logOptions: opts,
      instrumentation: instrumentation,
    )
    let runnerFactory = CommonProcessRunners.make(kind: .auto)
    let runner = runnerFactory.makeRunner(for: inv)
    return try await runner.run()
  }
}
