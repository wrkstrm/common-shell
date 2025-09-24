import CommonProcess
import CommonProcessRunners
import CommonShell
import Foundation

public struct ShellBenchmarkResult: Sendable, Equatable {
  public var iterations: Int
  public var totalMS: Double
  public var averageMS: Double

  public init(iterations: Int, totalMS: Double, averageMS: Double) {
    self.iterations = iterations
    self.totalMS = totalMS
    self.averageMS = averageMS
  }
}

extension CommonShell {
  /// Run as many iterations as possible within a duration budget and report iterations and timing.
  public func runForInterval(
    host: ExecutionHostKind,
    executable: Executable,
    arguments: [String] = [],
    environment: [String: String]? = nil,
    runnerKind: ProcessRunnerKind? = nil,
    durationSeconds: Double,
    targetHz: Double? = nil
  ) async throws -> ShellBenchmarkResult {
    let kind = runnerKind ?? .auto
    let start = DispatchTime.now().uptimeNanoseconds
    let budgetNs = UInt64(max(0.0, durationSeconds) * 1_000_000_000.0)
    let periodNs: UInt64? =
      targetHz.map { hz in hz > 0 ? UInt64((1.0 / hz) * 1_000_000_000.0) : 0 }
    var iterations = 0
    while true {
      let now = DispatchTime.now().uptimeNanoseconds
      if now &- start >= budgetNs { break }
      _ = try await run(
        host: host,
        executable: executable,
        arguments: arguments,
        environment: environment,
        runnerKind: kind,
      )
      iterations &+= 1
      if let periodNs, periodNs > 0 {
        let iterNow = DispatchTime.now().uptimeNanoseconds
        let elapsed = iterNow &- now
        if elapsed < periodNs { try? await Task.sleep(nanoseconds: periodNs - elapsed) }
      }
    }
    let end = DispatchTime.now().uptimeNanoseconds
    let totalMs = Double(end &- start) / 1_000_000.0
    let avgMs = iterations > 0 ? totalMs / Double(iterations) : totalMs
    return ShellBenchmarkResult(iterations: iterations, totalMS: totalMs, averageMS: avgMs)
  }

  /// Run a fixed number of iterations and report total/average timing.
  public func runIterations(
    host: ExecutionHostKind,
    executable: Executable,
    arguments: [String] = [],
    environment: [String: String]? = nil,
    runnerKind: ProcessRunnerKind? = nil,
    iterations: Int,
    targetHz: Double? = nil
  ) async throws -> ShellBenchmarkResult {
    let kind = runnerKind ?? .auto
    let count = max(iterations, 0)
    guard count > 0 else { return ShellBenchmarkResult(iterations: 0, totalMS: 0, averageMS: 0) }
    let periodNs: UInt64? =
      targetHz.map { hz in hz > 0 ? UInt64((1.0 / hz) * 1_000_000_000.0) : 0 }
    let start = DispatchTime.now().uptimeNanoseconds
    for _ in 0..<count {
      _ = try await run(
        host: host,
        executable: executable,
        arguments: arguments,
        environment: environment,
        runnerKind: kind,
      )
      if let periodNs, periodNs > 0 { try? await Task.sleep(nanoseconds: periodNs) }
    }
    let end = DispatchTime.now().uptimeNanoseconds
    let totalMs = Double(end &- start) / 1_000_000.0
    let avgMs = totalMs / Double(count)
    return ShellBenchmarkResult(iterations: count, totalMS: totalMs, averageMS: avgMs)
  }
}

/// Convenience overload preserving the historical free-function call style.
public func runForInterval(
  shell: CommonShell,
  host: ExecutionHostKind? = nil,
  executable: Executable? = nil,
  arguments: [String] = [],
  environment: [String: String]? = nil,
  runnerKind: ProcessRunnerKind? = nil,
  durationSeconds: Double,
  targetHz: Double? = nil
) async throws -> ShellBenchmarkResult {
  let resolvedExec = executable ?? shell.executable
  let resolvedHost = host ?? shell.hostKind ?? .direct
  return try await shell.runForInterval(
    host: resolvedHost,
    executable: resolvedExec,
    arguments: arguments,
    environment: environment,
    runnerKind: runnerKind,
    durationSeconds: durationSeconds,
    targetHz: targetHz
  )
}

/// Convenience overload for fixed-iteration benchmarking using the historical call style.
public func runIterations(
  shell: CommonShell,
  host: ExecutionHostKind? = nil,
  executable: Executable? = nil,
  arguments: [String] = [],
  environment: [String: String]? = nil,
  runnerKind: ProcessRunnerKind? = nil,
  iterations: Int,
  targetHz: Double? = nil
) async throws -> ShellBenchmarkResult {
  let resolvedExec = executable ?? shell.executable
  let resolvedHost = host ?? shell.hostKind ?? .direct
  return try await shell.runIterations(
    host: resolvedHost,
    executable: resolvedExec,
    arguments: arguments,
    environment: environment,
    runnerKind: runnerKind,
    iterations: iterations,
    targetHz: targetHz
  )
}
