import CommonProcess
import CommonProcessExecutionKit
import Foundation
import Testing

@testable import CommonShell

#if !targetEnvironment(macCatalyst)
@Suite("Runner overrides and wrapper × runner matrix")
struct RunnerOverrideTests {
  @Test
  func autoMatchesDefaultKind_directEcho() async throws {
    let sh = CommonShell(
      executable: Executable.path("/bin/true"))
    let autoOut = try await sh.run(
      host: .direct,
      executable: Executable.path("/bin/echo"),
      arguments: ["ok"],
      runnerKind: .auto,
    )
    let expectedKind = RunnerControllerFactory.defaultKind()
    let expOut = try await sh.run(
      host: .direct,
      executable: Executable.path("/bin/echo"),
      arguments: ["ok"],
      runnerKind: expectedKind,
    )
    #expect(autoOut == expOut)
  }

  @Test
  func foundation_direct_shell_env() async throws {
    let sh = CommonShell(
      executable: Executable.path("/bin/true"))
    let d = try await sh.run(
      host: .direct,
      executable: Executable.path("/bin/echo"),
      arguments: ["fdn"],
      runnerKind: .foundation,
    )
    #expect(d.trimmingCharacters(in: .whitespacesAndNewlines) == "fdn")
    let s = try await sh.run(
      host: .shell(options: []),
      executable: Executable.path("/bin/sh"),
      arguments: ["echo fdn"],
      runnerKind: .foundation,
    )
    #expect(s.trimmingCharacters(in: .whitespacesAndNewlines) == "fdn")
    let e = try await sh.run(
      host: .env(options: []),
      executable: Executable.name("echo"),
      arguments: ["fdn"],
      runnerKind: .foundation,
    )
    #expect(e.trimmingCharacters(in: .whitespacesAndNewlines) == "fdn")
  }

  #if canImport(TSCBasic)
  @Test
  func tscbasic_direct_shell_env() async throws {
    let sh = CommonShell(
      executable: Executable.path("/bin/true"))
    let d = try await sh.run(
      host: .direct,
      executable: Executable.path("/bin/echo"),
      arguments: ["tsc"],
      runnerKind: .tscbasic,
    )
    #expect(d.trimmingCharacters(in: .whitespacesAndNewlines) == "tsc")
    let s = try await sh.run(
      host: .shell(options: []),
      executable: Executable.path("/bin/sh"),
      arguments: ["echo tsc"],
      runnerKind: .tscbasic,
    )
    #expect(s.trimmingCharacters(in: .whitespacesAndNewlines) == "tsc")
    let e = try await sh.run(
      host: .env(options: []),
      executable: Executable.name("echo"),
      arguments: ["tsc"],
      runnerKind: .tscbasic,
    )
    #expect(e.trimmingCharacters(in: .whitespacesAndNewlines) == "tsc")
  }
  #endif

  #if canImport(Subprocess)
  @Test
  func subprocess_direct_shell_env() async throws {
    let sh = CommonShell(
      executable: Executable.path("/bin/true"))
    let d = try await sh.run(
      host: .direct,
      executable: Executable.path("/bin/echo"),
      arguments: ["sub"],
      runnerKind: .subprocess,
    )
    #expect(d.trimmingCharacters(in: .whitespacesAndNewlines) == "sub")
    let s = try await sh.run(
      host: .shell(options: []),
      executable: Executable.path("/bin/sh"),
      arguments: ["echo sub"],
      runnerKind: .subprocess,
    )
    #expect(s.trimmingCharacters(in: .whitespacesAndNewlines) == "sub")
    let e = try await sh.run(
      host: .env(options: []),
      executable: Executable.name("echo"),
      arguments: ["sub"],
      runnerKind: .subprocess,
    )
    #expect(e.trimmingCharacters(in: .whitespacesAndNewlines) == "sub")
  }
  #endif
}
#else
@Suite("Runner overrides (Catalyst)")
struct RunnerOverrideTests {
  @Test
  func skippedOnCatalyst() async throws {
    // no-op
  }
}
#endif
