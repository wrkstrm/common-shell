import CommonProcess
import CommonProcessRunners
import Foundation
import Testing

@testable import CommonShell

#if !targetEnvironment(macCatalyst)
@Test
func nonZeroExitThrowsProcessError() async throws {
  let sh = CommonShell(
    workingDirectory: FileManager.default.currentDirectoryPath,
    executable: Executable.path("/bin/sh"),
  )
  await #expect(throws: ProcessError.self) {
    _ = try await sh.run(["-c", "exit 7"])
  }
}

@Test
@MainActor
func launchReturnsOutputUtf8Output() async throws {
  let sh = CommonShell(
    workingDirectory: FileManager.default.currentDirectoryPath,
    executable: Executable.path("/bin/echo"),
  )
  let out = try await sh.launch(options: ["abc"])
  #expect(out.utf8Output() == "abc\n")
}

@Test
func workingDirectoryAffectsPwd() async throws {
  let tmp = try FileManager.default.url(
    for: .itemReplacementDirectory,
    in: .userDomainMask,
    appropriateFor: URL(fileURLWithPath: NSTemporaryDirectory()),
    create: true,
  )
  defer { try? FileManager.default.removeItem(at: tmp) }

  var sh = CommonShell(
    workingDirectory: tmp.path,
    executable: Executable.path("/bin/pwd"),
  )
  let out = try await sh.run([])
  let printed = out.trimmingCharacters(in: .whitespacesAndNewlines)
  let privatePrefixed = "/private" + tmp.path
  #expect(printed == tmp.path || printed == privatePrefixed)
}

final class SpyInstr: ProcessInstrumentation {
  nonisolated(unsafe) var started = false
  nonisolated(unsafe) var finished = false
  nonisolated(unsafe) var stdoutPreview: String?
  nonisolated(unsafe) var stderrPreview: String?
  func willStart(
    command _: String, arguments _: [String], workingDirectory _: String, runnerName _: String,
    requestId _: String, startUptimeNs _: UInt64,
  ) { started = true }
  func didFinish(
    command _: String, arguments _: [String], workingDirectory _: String, runnerName _: String,
    requestId _: String, status _: ProcessExitStatus, processIdentifier _: String?,
    startUptimeNs _: UInt64, endUptimeNs _: UInt64, stdoutPreview: String?, stderrPreview: String?,
  ) {
    finished = true
    self.stdoutPreview = stdoutPreview
    self.stderrPreview = stderrPreview
  }
}

@Test
func reprintCommandAndInstrumentationPreview() async throws {
  var sh = CommonShell(
    workingDirectory: FileManager.default.currentDirectoryPath,
    executable: Executable.path("/bin/echo"),
  )
  sh.logOptions.exposure = .summary
  sh.logOptions.maxStdoutBytes = 4
  sh.logOptions.maxStderrBytes = 4
  let spy = SpyInstr()
  sh.instrumentation = spy

  let out = try await sh.run(["abcdef"])
  #expect(out.contains("abcdef"))
  #expect(spy.started)
  #expect(spy.finished)
  #expect(spy.stdoutPreview == String("abcdef\n".prefix(4)))
}

@Test
func lineTruncationHeadTailPreview() async throws {
  var sh = CommonShell(
    workingDirectory: FileManager.default.currentDirectoryPath,
    executable: Executable.path("/bin/echo"),
  )
  sh.logOptions.exposure = .summary
  sh.logOptions.maxStdoutLines = 3
  sh.logOptions.showHeadTail = true
  sh.logOptions.headLines = 1
  sh.logOptions.tailLines = 1
  let spy = SpyInstr()
  sh.instrumentation = spy
  let payload = ["-e", "a\nb\nc\nd\ne"]
  _ = try await sh.run(payload)
  #expect(spy.stdoutPreview?.contains("a\n") == true)
  #expect(
    spy.stdoutPreview?.contains("\ne\n") == true || spy.stdoutPreview?.hasSuffix("\ne") == true)
}

@Test
func errorTextPropagationFromStderr() async throws {
  let sh = CommonShell(
    workingDirectory: FileManager.default.currentDirectoryPath,
    executable: Executable.path("/bin/sh"),
  )
  do {
    _ = try await sh.run(["-c", "printf error-text 1>&2; exit 9"])
    Issue.record("Expected error not thrown")
  } catch let err as ProcessError {
    #expect(err.status == 9)
    #expect(err.error.contains("error-text"))
  }
}

@Test
func perfEchoLoopUnderOneSecond() async throws {
  let sh = CommonShell(
    workingDirectory: FileManager.default.currentDirectoryPath,
    executable: Executable.path("/bin/echo"),
  )
  let iterations = 10
  let t0 = DispatchTime.now().uptimeNanoseconds
  for _ in 0..<iterations {
    _ = try await sh.run(["perf"])
  }
  let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000.0
  #expect(elapsedMs < 1000.0)
}

@Test
func runShellEcho() async throws {
  let sh = CommonShell(executable: Executable.path("/bin/true"))
  let out = try await sh.run(
    host: .shell(options: []),
    identity: .path("/bin/sh"),
    args: ["echo shell-ok"],
  )
  #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "shell-ok")
}

@Test
func runEnvEcho() async throws {
  let sh = CommonShell(
    executable: Executable.path("/usr/bin/env"))
  let out = try await sh.run(
    host: .env(options: []),
    identity: .name("echo"),
    args: ["env-ok"],
  )
  #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "env-ok")
}

@Test
func runRawDirectToken() async throws {
  let sh = CommonShell(executable: Executable.path("/bin/true"))
  let out = try await sh.run(host: .direct, identity: .path("/bin/pwd"))
  let printed = out.trimmingCharacters(in: .whitespacesAndNewlines)
  let cwd = FileManager.default.currentDirectoryPath
  #expect(printed == cwd || printed == "/private" + cwd)
}

@Test
func runRawDirect() async throws {
  let sh = CommonShell(executable: Executable.path("/bin/true"))
  let out = try await sh.run(host: .direct, identity: .path("/bin/pwd"))
  let printed = out.trimmingCharacters(in: .whitespacesAndNewlines)
  let cwd = FileManager.default.currentDirectoryPath
  #expect(printed == cwd || printed == "/private" + cwd)
}

@Test
func runWrapperMatrixBasics() async throws {
  let sh = CommonShell(executable: Executable.path("/bin/true"))
  // direct
  do {
    let out = try await sh.run(
      host: .direct,
      executable: Executable.path("/bin/echo"),
      arguments: ["d-ok"],
    )
    #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "d-ok")
  }
  // shell
  do {
    let out = try await sh.run(
      host: .shell(options: []),
      executable: Executable.path("/bin/sh"),
      arguments: ["echo s-ok"],
    )
    #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "s-ok")
  }
  // env
  do {
    let out = try await sh.run(
      host: .env(options: []),
      executable: Executable.name("echo"),
      arguments: ["e-ok"],
    )
    #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "e-ok")
  }
}
#else
@Test
func catalystSkipped() async throws { /* no-op: process spawning unavailable */  }
#endif
