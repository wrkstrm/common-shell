import CommonProcess
import CommonProcessExecutionKit
import Foundation
import Testing

@testable import CommonShell

#if !targetEnvironment(macCatalyst)
@Test
func echo() async throws {
  let sh = CommonShell(
    workingDirectory: FileManager.default.currentDirectoryPath,
    executable: Executable.path("/bin/echo"),
  )
  let out = try await sh.run(["hello"])
  #expect(out.contains("hello"))
}
#endif  // !targetEnvironment(macCatalyst)

#if os(macOS) || os(Linux)
@Test("timeout triggers ProcessError")
func timeoutSleep() async throws {
  let shell = CommonShell(
    workingDirectory: FileManager.default.currentDirectoryPath,
    executable: Executable.path("/bin/sh")
  )
  do {
    _ = try await shell.run(["-c", "sleep 5"], timeout: .seconds(1))
    Issue.record("expected timeout to throw")
  } catch let error as ProcessError {
    #expect(error.timedOut)
    #expect(error.timeout != nil)
  } catch {
    throw error
  }
}
#endif
