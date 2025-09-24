import CommonProcess
import CommonProcessRunners
import Foundation

/// Normalized representation of a CommonShell invocation decoded from JSON.
struct DecodedSpec: Equatable {
  /// Execution host to use (direct|shell|env|npm|npx).
  var host: ExecutionHostKind
  /// Executable identity (name|path|argv-only).
  var executable: Executable
  /// Arguments for the invocation.
  var args: [String]
  /// Working directory to use (nil defaults to current directory).
  var cwd: String?
  /// Optional explicit runner selection.
  var runner: ProcessRunnerKind?
  /// Environment key/value pairs to apply.
  var env: [String: String]
  /// Optional stdout byte cap for previews.
  var maxStdoutBytes: Int?
  /// Optional stderr byte cap for previews.
  var maxStderrBytes: Int?
  /// Optional exposure level override.
  var exposure: ProcessExposure?
}
