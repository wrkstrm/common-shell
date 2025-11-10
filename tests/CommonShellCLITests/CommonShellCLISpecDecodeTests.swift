import CommonProcess
import CommonShell
import Testing

@testable import CommonShellCLI

@Suite("CommonShellCLI decode/mapping")
struct CommonShellCLISpecDecodeTests {
  @Test("Decodes new spec: direct with env and bytes caps")
  func decodeNewSpecDirect() throws {
    let json = """
      {
        "wrapper": "direct",
        "executable": "/bin/echo",
        "options": ["hello"],
        "args": ["world"],
        "cwd": "/tmp",
        "runner": "foundation",
        "env": {"FOO":"BAR"},
        "maxStdoutBytes": 128,
        "maxStderrBytes": 64
      }
      """.data(using: .utf8)!
    let spec = try decodeAnySpec(from: json)
    #expect(spec.host == .direct)
    #expect(spec.executable.ref == .path("/bin/echo"))
    #expect(spec.executable.options == ["hello"])
    #expect(spec.args == ["world"])
    #expect(spec.cwd == "/tmp")
    #expect(spec.runner == .some(.foundation))
    #expect(spec.env["FOO"] == "BAR")
    #expect(spec.maxStdoutBytes == 128)
    #expect(spec.maxStderrBytes == 64)
  }

  // Legacy formats removed: no decoding tests for ExecutableInvocation/CommonShellInvocationRequest

  @Test("Decodes env wrapper with options")
  func decodeEnvWrapper() throws {
    let json = """
      {
        "wrapper": "env",
        "name": "swift",
        "options": ["-S"],
        "args": ["--version"]
      }
      """.data(using: .utf8)!
    let spec = try decodeAnySpec(from: json)
    #expect(
      {
        guard case .env(options: let opts) = spec.host else { return false }
        return opts == ["-S"]
      }())
    #expect(spec.executable.ref == .name("swift"))
    #expect(spec.args == ["--version"])
  }

  @Test("renderSummary formats numbers with one decimal place")
  func testRenderSummary() {
    let s = renderSummary(iterations: 5, totalMS: 12.345, averageMS: 2.5)
    #expect(s.contains("iterations=5"))
    #expect(s.contains("total_ms=12.3"))
    #expect(s.contains("avg_ms=2.5"))
  }
}
