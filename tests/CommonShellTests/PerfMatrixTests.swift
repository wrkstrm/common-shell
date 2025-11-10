import CommonProcess
import CommonShellBenchSupport
import Foundation
import Testing

@testable import CommonShell

#if !targetEnvironment(macCatalyst)
@Suite("Perf matrix (duration mode) — egregious thresholds only")
struct PerfMatrixTests {
  @Test
  func perfFoundation_direct_short() async throws {
    let sh = CommonShell(
      executable: Executable.path("/bin/true"))
    let res = try await sh.runForInterval(
      host: .direct,
      executable: Executable.path("/bin/echo"),
      arguments: ["ok"],
      runnerKind: .foundation,
      durationSeconds: 0.15,
      targetHz: nil,
    )
    #expect(res.iterations > 0)
    #expect(res.averageMS < 1000.0)
  }

  @Test
  func perfFoundation_shell_short() async throws {
    let sh = CommonShell(
      executable: Executable.path("/bin/true"))
    let res = try await sh.runForInterval(
      host: .shell(options: []),
      executable: Executable.path("/bin/sh"),
      arguments: ["echo ok"],
      runnerKind: .foundation,
      durationSeconds: 0.15,
      targetHz: nil,
    )
    #expect(res.iterations > 0)
    #expect(res.averageMS < 1000.0)
  }

  @Test
  func perfFoundation_env_short() async throws {
    let sh = CommonShell(
      executable: Executable.path("/bin/true"))
    let res = try await sh.runForInterval(
      host: .env(options: []),
      executable: Executable.name("echo"),
      arguments: ["ok"],
      runnerKind: .foundation,
      durationSeconds: 0.15,
      targetHz: nil,
    )
    #expect(res.iterations > 0)
    #expect(res.averageMS < 1000.0)
  }

  #if canImport(TSCBasic)
  @Test
  func perfTSCBasic_direct_short() async throws {
    let sh = CommonShell(
      executable: Executable.path("/bin/true"))
    let res = try await sh.runForInterval(
      host: .direct,
      executable: Executable.path("/bin/echo"),
      arguments: ["tsc"],
      runnerKind: .tscbasic,
      durationSeconds: 0.15,
      targetHz: nil,
    )
    #expect(res.iterations > 0)
    #expect(res.averageMS < 1000.0)
  }
  #endif

  #if canImport(Subprocess)
  @Test
  func perfSubprocess_direct_short() async throws {
    let sh = CommonShell(
      executable: Executable.path("/bin/true"))
    let res = try await sh.runForInterval(
      host: .direct,
      executable: Executable.path("/bin/echo"),
      arguments: ["sub"],
      runnerKind: .subprocess,
      durationSeconds: 0.15,
      targetHz: nil,
    )
    #expect(res.iterations > 0)
    #expect(res.averageMS < 1000.0)
  }
  #endif
}
#else
@Suite("Perf matrix (Catalyst)")
struct PerfMatrixTests {
  @Test func skippedOnCatalyst() async throws { /* no-op */  }
}
#endif
