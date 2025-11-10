import CommonProcess
import CommonShell
import CommonShellBenchSupport
import WrkstrmPerformance

extension CommonShell {
  /// Perf duration using WrkstrmPerformance delegates.
  public func perfForInterval(
    host: ExecutionHostKind,
    executable: Executable,
    arguments: [String] = [],
    environment: [String: String]? = nil,
    runnerKind: ProcessRunnerKind? = nil,
    durationSeconds: Double,
    targetHz: Double? = nil,
  ) async throws -> ShellBenchmarkResult {
    let kind = runnerKind ?? .auto
    let metrics = try await PerfRunner.duration(seconds: durationSeconds, targetHz: targetHz) {
      _ = try await run(
        host: host,
        executable: executable,
        arguments: arguments,
        environment: environment,
        runnerKind: kind,
      )
    }
    return ShellBenchmarkResult(
      iterations: metrics.iterations,
      totalMS: metrics.totalMS,
      averageMS: metrics.averageMS
    )
  }

  /// Perf iterations using WrkstrmPerformance delegates.
  public func perfIterations(
    host: ExecutionHostKind,
    executable: Executable,
    arguments: [String] = [],
    environment: [String: String]? = nil,
    runnerKind: ProcessRunnerKind? = nil,
    iterations: Int,
    targetHz: Double? = nil,
  ) async throws -> ShellBenchmarkResult {
    let kind = runnerKind ?? .auto
    let metrics = try await PerfRunner.iterations(iterations, targetHz: targetHz) {
      _ = try await run(
        host: host,
        executable: executable,
        arguments: arguments,
        environment: environment,
        runnerKind: kind,
      )
    }
    return ShellBenchmarkResult(
      iterations: metrics.iterations,
      totalMS: metrics.totalMS,
      averageMS: metrics.averageMS
    )
  }
}
