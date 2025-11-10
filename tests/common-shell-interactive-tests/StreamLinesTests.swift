import Foundation
import Testing

@testable import CommonShell

#if !targetEnvironment(macCatalyst)
@Test
func streamLinesEchoSmoke() async throws {
  let sh = CommonShell(
    workingDirectory: FileManager.default.currentDirectoryPath,
    executable: .path("/bin/echo")
  )
  let (lines, _) = sh.streamLines(arguments: ["stream-ok"])
  var collected: [String] = []
  for try await line in lines {
    collected.append(line)
  }
  #expect(collected.contains("stream-ok"))
}
#else
@Test
func catalystSkippedStream() async throws {
  // streaming not available on Catalyst
}
#endif
