import CommonProcess
import CommonProcessRunners
import Foundation

/// Minimal CommonShell adapter built directly on CommonProcess.
/// Notes:
/// - No shims or typealiases; use CommonProcess types directly.
/// - Single initializer shape per policy.
public struct CommonShell: @unchecked Sendable, Codable {
  public var executable: Executable
  public var workingDirectory: String
  // Unified logging options
  public var logOptions: ProcessLogOptions = .init()
  public var hostKind: ExecutionHostKind?
  public var instrumentation: ProcessInstrumentation?

  // Required initializer (only one supported per policy)
  public init(
    workingDirectory: String = FileManager.default.currentDirectoryPath,
    executable: Executable = .none(),
    hostKind: ExecutionHostKind? = .shell(options: []),
    instrumentation: ProcessInstrumentation? = nil,
  ) {
    self.executable = executable
    self.workingDirectory = workingDirectory
    logOptions = .init()
    self.hostKind = hostKind
    self.instrumentation = instrumentation
  }

  // Legacy initializer taking CommonProcessExecutable has been removed.

  // Codable conformance: encode minimal, portable fields. Instrumentation is runtime-only.
  private enum CodingKeys: String, CodingKey {
    case executable, workingDirectory, logOptions, hostKind
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let exec = try c.decode(Executable.self, forKey: .executable)
    let wd =
      try c.decodeIfPresent(String.self, forKey: .workingDirectory)
      ?? FileManager.default.currentDirectoryPath
    self.init(workingDirectory: wd, executable: exec)
    if let opts = try c.decodeIfPresent(ProcessLogOptions.self, forKey: .logOptions) {
      logOptions = opts
    }
    if let host = try c.decodeIfPresent(ExecutionHostKind.self, forKey: .hostKind) {
      hostKind = host
    }
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(executable, forKey: .executable)
    try c.encode(workingDirectory, forKey: .workingDirectory)
    try c.encode(logOptions, forKey: .logOptions)
    try c.encodeIfPresent(hostKind, forKey: .hostKind)
  }

  @discardableResult
  public func run(arguments: [String], timeout: Duration? = nil) async throws -> String {
    try await execute(arguments: arguments, runnerKind: .auto, timeout: timeout)
  }

  /// Back-compat shim to enable calling with unlabeled array.
  @discardableResult
  public func run(_ arguments: [String], timeout: Duration? = nil) async throws -> String {
    try await run(arguments: arguments, timeout: timeout)
  }
}
