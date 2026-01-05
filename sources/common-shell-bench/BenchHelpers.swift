import CommonProcess
import CommonShell
import CommonShellBenchSupport
import Foundation

// MARK: - Shared helpers

typealias RunnerKind = ProcessRunnerKind

func parseRunner(_ value: String) -> RunnerKind? {
  switch value.lowercased() {
  case "auto": .auto
  case "foundation": .foundation
  case "tscbasic": .tscbasic
  case "subprocess": .subprocess
  default: nil
  }
}

func parseRoutes(_ spec: String) -> [ShellRouteKind] {
  let tokens = spec.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
  if tokens.count == 1, tokens.first?.lowercased() == "platform" {
    return ShellRouteKind.all(using: .init())
  }
  var routes: [ShellRouteKind] = []
  for token in tokens {
    let lower = token.lowercased()
    if lower == "auto" {
      routes.append(.auto)
      continue
    }
    if lower == "native" {
      routes.append(.native)
      continue
    }
    if lower.hasPrefix("subprocess:") {
      let runnerString = String(lower.dropFirst("subprocess:".count))
      if let kind = parseRunner(runnerString) {
        routes.append(.subprocess(kind))
      }
    }
  }
  if routes.isEmpty { return ShellRouteKind.all(using: .init()) }
  return routes
}

func runnerKind(for route: ShellRouteKind) -> RunnerKind? {
  switch route {
  case .auto: .auto
  case .subprocess(let kind): kind
  case .native: nil
  }
}

func routeLabel(_ route: ShellRouteKind) -> String {
  switch route {
  case .auto: "auto"
  case .native: "native"

  case .subprocess(let kind):
    switch kind {
    case .auto: "subprocess:auto"
    case .foundation: "subprocess:foundation"
    case .tscbasic: "subprocess:tscbasic"
    case .subprocess: "subprocess"
    }
  }
}

// Fallback when Benchmark is unavailable: run without extra metrics collection.
func performMetricsIterations(
  count: Int,
  host: String,
  routeLabel: String,
  shell: CommonShell,
  call: BenchSupport.BenchCall,
  runnerKind: RunnerKind,
  recorder: BenchMetricsRecorder,
  durationSeconds: Double?,
) async throws {
  for _ in 0..<count {
    var runShell = shell
    var tags = runShell.logOptions.tags ?? [:]
    tags["host"] = host
    tags["route"] = routeLabel
    var options = runShell.logOptions
    options.tags = tags
    runShell.logOptions = options
    runShell.instrumentation = RecorderInstrumentation(tags: tags, recorder: recorder)

    if let durationSeconds, durationSeconds > 0 {
      _ = try await runShell.runForInterval(
        host: call.host,
        executable: call.executable,
        arguments: call.arguments,
        runnerKind: runnerKind,
        durationSeconds: durationSeconds,
        targetHz: nil,
      )
    } else {
      try await runShell.run(
        host: call.host,
        executable: call.executable,
        arguments: call.arguments,
        runnerKind: runnerKind,
      )
    }
    // Duration and peak memory are recorded via instrumentation callbacks.
  }
}

#if canImport(Darwin)
import Darwin.Mach

func currentResidentSizeBytes() -> UInt64 {
  var info = mach_task_basic_info()
  var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<Int32>.size)
  let result = withUnsafeMutablePointer(to: &info) {
    $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
      task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
    }
  }
  guard result == KERN_SUCCESS else { return 0 }
  return UInt64(info.resident_size)
}
#else
func currentResidentSizeBytes() -> UInt64 { 0 }
#endif

func renderPerformanceTable(_ rows: [PerformanceRow]) {
  guard !rows.isEmpty else { return }
  let baseHeaders = ["host", "route", "count", "avg_ms", "avg_hz", "min_ms", "max_ms", "peak_mb"]
  let headers: [String]
  #if canImport(Benchmark)
  let activeMetricDescriptors = BenchMetricsRecorder.metricDescriptors.filter { descriptor in
    rows.contains { $0.metrics[descriptor.key] != nil }
  }
  headers = baseHeaders + activeMetricDescriptors.map(\.header)
  #else
  headers = baseHeaders
  #endif

  var formatted: [[String]] = []
  for row in rows {
    let avg = String(format: "%.3f", row.avgNs / 1_000_000)
    let hz = String(format: "%.3f", row.avgHz)
    let min = String(format: "%.3f", row.minNs / 1_000_000)
    let max = String(format: "%.3f", row.maxNs / 1_000_000)
    let peak = String(format: "%.3f", row.peakBytes / (1024 * 1024))
    var values: [String] = [
      row.host,
      row.route,
      String(row.iterations),
      avg,
      hz,
      min,
      max,
      peak,
    ]
    #if canImport(Benchmark)
    for descriptor in activeMetricDescriptors {
      if let value = row.metrics[descriptor.key] {
        values.append(descriptor.formatter(value))
      } else {
        values.append("")
      }
    }
    #endif
    formatted.append(values)
  }
  var widths = headers.map(\.count)
  for row in formatted {
    for (index, value) in row.enumerated() {
      widths[index] = max(widths[index], value.count)
    }
  }
  func pad(_ text: String, width: Int) -> String {
    text + String(repeating: " ", count: max(0, width - text.count))
  }
  var lines: [String] = []
  lines.append(zip(headers, widths).map { pad($0.0, width: $0.1) }.joined(separator: "  "))
  lines.append(widths.map { String(repeating: "-", count: $0) }.joined(separator: "  "))
  for row in formatted {
    lines.append(zip(row, widths).map { pad($0.0, width: $0.1) }.joined(separator: "  "))
  }
  print(lines.joined(separator: "\n"))
}
