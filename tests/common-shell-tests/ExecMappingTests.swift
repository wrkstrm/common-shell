import CommonProcess
import CommonProcessExecutionKit
import CommonShellBenchSupport
import Foundation
import Testing

@testable import CommonShell

#if !targetEnvironment(macCatalyst)
@Suite("Exec mapping and helpers")
struct ExecMappingTests {
  @Test
  func runExecByName_usesEnvEcho() async throws {
    let sh = CommonShell(
      executable: Executable.path("/bin/true"))
    let out = try await sh.run(reference: .name("echo"), args: ["hello"])
    #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
  }

  @Test
  func runExecByPath_usesDirectEcho() async throws {
    let sh = CommonShell(
      executable: Executable.path("/bin/true"))
    let out = try await sh.run(reference: .path("/bin/echo"), args: ["world"])
    #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "world")
  }

  @Test
  func withExec_bindsShellForNameAndPath() async throws {
    let base = CommonShell(
      executable: Executable.path("/bin/true"))
    // name(tool) binds to /usr/bin/env and prefixes tool into options
    let envBound = base.withExec(reference: .name("echo"), defaultOptions: ["-n"])
    #expect(
      {
        guard case .name(let n) = envBound.executable.ref else { return false }
        return n == "echo"
      }())
    #expect(envBound.hostKind == .direct)
    // path binds directly
    let directBound = base.withExec(reference: .path("/bin/echo"))
    #expect(
      {
        guard case .path(let p) = directBound.executable.ref else { return false }
        return p == "/bin/echo"
      }())
    #expect(directBound.hostKind == .direct)
  }

  @Test
  func runForInterval_withExec_reportsIterations() async throws {
    let sh = CommonShell(
      executable: Executable.path("/bin/true"))
    let result = try await sh.runForInterval(
      host: .direct,
      executable: Executable.path("/bin/echo"),
      arguments: ["x"],
      durationSeconds: 0.05,
    )
    #expect(result.iterations >= 1)
    #expect(result.totalMS >= 0)
  }
}
#else
@Suite("Exec mapping and helpers (Catalyst)")
struct ExecMappingTests {
  @Test
  func skippedOnCatalyst() async throws {
    // no-op
  }
}
#endif
