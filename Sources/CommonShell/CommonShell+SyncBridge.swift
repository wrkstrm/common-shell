import CommonProcess
import CommonProcessExecutionKit
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
    return try await inv.run()
  }
}
