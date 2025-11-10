import Foundation
import Testing

@testable import CommonShell

#if canImport(Darwin)
import Darwin
#endif

// Helper: locate package root by walking up to a directory containing Package.swift and Sources
private func locatePackageRoot(
  start: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
) -> URL {
  var dir = start
  let fm = FileManager.default
  var attempts = 0
  while attempts < 10 {
    let pkg = dir.appendingPathComponent("Package.swift").path
    let src = dir.appendingPathComponent("Sources").path
    if fm.fileExists(atPath: pkg), fm.fileExists(atPath: src) {
      return dir
    }
    let parent = dir.deletingLastPathComponent()
    if parent.path == dir.path { break }
    dir = parent
    attempts += 1
  }
  return start
}

// Helper: find chaos-shell binary in .build
private func findChaosShellBinary(packageRoot: URL) -> URL? {
  let fm = FileManager.default
  let build = packageRoot.appendingPathComponent(".build", isDirectory: true)
  // Common locations
  let candidates = [
    build.appendingPathComponent("debug/chaos-shell", isDirectory: false),
    build.appendingPathComponent("Debug/chaos-shell", isDirectory: false),
  ]
  for c in candidates where fm.isExecutableFile(atPath: c.path) {
    return c
  }
  // Fallback: search recursively for a file named 'chaos-shell'
  if let e = fm.enumerator(
    at: build, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles],
  ) {
    for case let url as URL in e {
      if url.lastPathComponent == "chaos-shell", fm.isExecutableFile(atPath: url.path) {
        return url
      }
    }
  }
  return nil
}

// Helper: build chaos-shell if not present
@discardableResult
private func ensureChaosShellBuilt(packageRoot: URL) throws -> URL {
  if let url = findChaosShellBinary(packageRoot: packageRoot) { return url }
  // Build the product
  let proc = Process()
  proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
  proc.arguments = [
    "swift", "build", "-c", "debug", "--product", "chaos-shell", "--package-path", packageRoot.path,
  ]
  let pipe = Pipe()
  proc.standardOutput = pipe
  proc.standardError = pipe
  try proc.run()
  proc.waitUntilExit()
  // Attempt to find again
  if let url = findChaosShellBinary(packageRoot: packageRoot) { return url }
  // Emit captured output on failure for diagnosis
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  let out = String(data: data, encoding: .utf8) ?? ""
  struct BuildError: Error, CustomStringConvertible { let description: String }
  throw BuildError(description: "Failed to build chaos-shell. Output: \n\(out)")
}

// Helper: run a process, optionally supplying stdin, and capture results
private struct ProcResult {
  let code: Int32
  let out: String
  let err: String
  let pid: pid_t
}

private func run(_ url: URL, args: [String], stdin: String? = nil, timeout: TimeInterval = 10)
  throws -> ProcResult
{
  let proc = Process()
  proc.executableURL = url
  proc.arguments = args
  let outPipe = Pipe()
  proc.standardOutput = outPipe
  let errPipe = Pipe()
  proc.standardError = errPipe
  let inPipe = Pipe()
  proc.standardInput = inPipe
  try proc.run()
  if let s = stdin {
    inPipe.fileHandleForWriting.write(Data(s.utf8))
    inPipe.fileHandleForWriting.closeFile()
  }
  // Minimal timeout: poll for exit up to the timeout
  let start = Date()
  while proc.isRunning, Date().timeIntervalSince(start) < timeout {
    usleep(20000)
  }
  if proc.isRunning { proc.terminate() }
  proc.waitUntilExit()
  let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
  let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
  return ProcResult(code: proc.terminationStatus, out: out, err: err, pid: proc.processIdentifier)
}

@Test(
  "chaos-shell prompt: inputs and exits",
  .timeLimit(.minutes(1)),
  .serialized,
  arguments: [("N\n", Int32(1)), ("y\n", Int32(0))],
)
func chaosShellPrompt(input: String, expected: Int32) throws {
  let root = locatePackageRoot()
  let bin = try ensureChaosShellBuilt(packageRoot: root)
  let res = try run(
    bin, args: ["--no-banner", "prompt", "--message", "Continue? [y/N] "], stdin: input,
  )
  #expect(res.code == expected)
}

@Test(
  "chaos-shell echo: response limits",
  .timeLimit(.minutes(1)),
  .serialized,
  arguments: [1, 5, 10],
)
func chaosShellEcho_Limits(limit: Int) throws {
  let root = locatePackageRoot()
  let bin = try ensureChaosShellBuilt(packageRoot: root)
  let res = try run(bin, args: ["--no-banner", "echo", "--response-limit", String(limit)])
  let outLines = res.out.split(separator: "\n").filter { !$0.isEmpty }
  #expect(outLines.count == limit)
  #expect(outLines.first?.hasPrefix("OUT 00001") == true)
  let last = String(format: "%05d", limit)
  #expect(outLines.last?.hasPrefix("OUT \(last)") == true)
}

#if canImport(Darwin)
@Test(
  "chaos-shell signals: single SIGINT exits 130 (macOS)",
  .timeLimit(.minutes(1)),
  .serialized,
)
func chaosShellSignals_Int() throws {
  let root = locatePackageRoot()
  let bin = try ensureChaosShellBuilt(packageRoot: root)
  // Start process with a long duration; then send SIGINT
  let proc = Process()
  proc.executableURL = bin
  proc.arguments = ["--no-banner", "signals", "--duration-seconds", "30"]
  let outPipe = Pipe()
  proc.standardOutput = outPipe
  let errPipe = Pipe()
  proc.standardError = errPipe
  try proc.run()
  // Allow it to start the run loop
  usleep(150_000)
  kill(proc.processIdentifier, SIGINT)
  proc.waitUntilExit()
  #expect(proc.terminationStatus == 130)
}
#endif
