import CommonProcess
import CommonShell
import Foundation
import Testing

@testable import CommonShellBenchSupport

@Suite("BenchSupport helpers")
struct BenchSupportTests {
  @Test
  func buildCall_mapsNpmRun() {
    let workload = BenchSupport.BenchWorkload(kind: .echo, target: "bench", payload: "")
    let call = BenchSupport.buildCall(host: "npm-run", workload: workload)
    #expect(call != nil)
    guard let call else { return }
    #expect(
      {
        guard case .npm = call.host else { return false }
        return true
      }())
    #expect(call.executable.ref == .name("npm"))
    #expect(call.arguments.prefix(2).elementsEqual(["run", "bench"]))
  }

  @Test
  func buildCall_mapsNpmExec() {
    let workload = BenchSupport.BenchWorkload(kind: .echo, target: "echo", payload: "hi")
    let call = BenchSupport.buildCall(host: "npm-exec", workload: workload)
    #expect(call != nil)
    guard let call else { return }
    #expect(
      {
        guard case .npm = call.host else { return false }
        return true
      }())
    #expect(call.executable.ref == .name("npm"))
    #expect(call.arguments.prefix(3).elementsEqual(["exec", "--", "echo"]))
    #expect(call.arguments.last == "hi")
  }

  @Test
  func buildCall_swiftVersion_direct() {
    let workload = BenchSupport.BenchWorkload(kind: .swiftVersion, target: "swift", payload: "")
    let call = BenchSupport.buildCall(host: "direct", workload: workload)
    #expect(call?.host == .direct)
    #expect(call?.executable.ref == .name("swift"))
    #expect(call?.arguments == ["--version"])
  }

  @Test
  func render_csv_json_table() throws {
    let rows = [
      BenchRow(
        host: "direct", route: "foundation", iterations: 3, total_ms: 12.3, avg_ms: 4.1,
      )
    ]
    // CSV
    let csv = BenchSupport.render(rows: rows, format: "csv")
    #expect(csv.contains("host,route,iterations,total_ms,avg_ms"))
    // JSON (decode to avoid whitespace sensitivity across platforms)
    let json = BenchSupport.render(rows: rows, format: "json")
    let decoded = try JSONDecoder().decode([BenchRow].self, from: Data(json.utf8))
    #expect(decoded.count == 1 && decoded.first?.host == "direct")
    // Table
    let table = BenchSupport.render(rows: rows, format: "table")
    #expect(table.contains("direct"))
  }
}
