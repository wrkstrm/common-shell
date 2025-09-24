import CommonProcess
import CommonProcessRunners
import Foundation

extension CommonShell {
  /// Stream process events (stdout/stderr/completion) for a run with the current binding.
  /// - Returns: An async throwing stream of `ProcessEvent` and a cancel closure.
  public func stream(
    arguments: [String],
    environment: [String: String]? = nil,
    runnerKind: ProcessRunnerKind? = nil,
    timeout: Duration? = nil
  ) -> (events: ProcessEventStream, cancel: @Sendable () -> Void) {
    let envModel: EnvironmentModel? = environment.map { .inherit(updating: $0) }
    var invocation = makeInvocation(arguments: arguments, environment: envModel, timeout: timeout)
    invocation.runnerKind = runnerKind
    let resolved = resolveHost(invocation)
    return CommonProcessRunners.stream(invocation: resolved)
  }

  /// Stream coalesced text lines decoded from stdout and stderr.
  /// Lines from stdout and stderr are merged in arrival order.
  /// - Note: This is a convenience for simple UIs. For source-aware processing, consume `stream(arguments:)`.
  public func streamLines(
    arguments: [String],
    environment: [String: String]? = nil,
    runnerKind: ProcessRunnerKind? = nil,
    encoding: String.Encoding = .utf8,
    timeout: Duration? = nil
  ) -> (lines: AsyncThrowingStream<String, Error>, cancel: @Sendable () -> Void) {
    let (events, cancel) = stream(
      arguments: arguments,
      environment: environment,
      runnerKind: runnerKind,
      timeout: timeout
    )

    let lines = AsyncThrowingStream<String, Error> { continuation in
      Task {
        var outRemainder = ""
        var errRemainder = ""

        func yieldLines(from text: String, remainder: inout String) {
          let combined = remainder + text
          // Split preserving empty trailing component if the text ends with a newline.
          let parts = combined.split(
            omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" })
          if parts.isEmpty { return }
          // All but the last part are complete lines.
          for i in 0..<(parts.count - 1) {
            continuation.yield(String(parts[i]))
          }
          // If the last part ended with a newline, it will be empty — flush it and clear remainder.
          if let last = parts.last {
            let endsWithNewline = combined.hasSuffix("\n")
            if endsWithNewline {
              if !last.isEmpty { continuation.yield(String(last)) }
              remainder = ""
            } else {
              remainder = String(last)
            }
          }
        }

        do {
          for try await event in events {
            switch event {
            case .stdout(let data):
              let text =
                String(data: data, encoding: encoding) ?? String(decoding: data, as: UTF8.self)
              yieldLines(from: text, remainder: &outRemainder)
            case .stderr(let data):
              let text =
                String(data: data, encoding: encoding) ?? String(decoding: data, as: UTF8.self)
              yieldLines(from: text, remainder: &errRemainder)
            case .completed:
              // Flush any remaining partial lines.
              if !outRemainder.isEmpty {
                continuation.yield(outRemainder)
                outRemainder = ""
              }
              if !errRemainder.isEmpty {
                continuation.yield(errRemainder)
                errRemainder = ""
              }
              continuation.finish()
            }
          }
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }

    return (lines: lines, cancel: cancel)
  }
}
