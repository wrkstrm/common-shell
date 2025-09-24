import CommonProcess
import CommonProcessRunners
import CommonShellBenchSupport
import Foundation
import Testing

@testable import CommonShell

#if !targetEnvironment(macCatalyst)
@Suite("runForInterval with Executable")
struct RunForIntervalExecTests {
  @Test
  func nameEcho_runsMultipleIterations() async throws {
    let sh = CommonShell(
      executable: Executable.path("/bin/true"))
    let result = try await sh.runForInterval(
      host: .env(options: []),
      executable: Executable.name("echo"),
      arguments: ["ok"],
      durationSeconds: 0.05,
    )
    #expect(result.iterations >= 1)
    #expect(result.totalMS >= 0)
  }

  @Test
  func pathEcho_runsMultipleIterations() async throws {
    let sh = CommonShell(
      executable: Executable.path("/bin/true"))
    let result = try await sh.runForInterval(
      host: .direct,
      executable: Executable.path("/bin/echo"),
      arguments: ["ok"],
      durationSeconds: 0.05,
    )
    #expect(result.iterations >= 1)
    #expect(result.averageMS >= 0)
  }
}
#else
@Suite("runForInterval with Executable (Catalyst)")
struct RunForIntervalExecTests {
  @Test func skippedOnCatalyst() async throws { /* no-op */  }
}
#endif
