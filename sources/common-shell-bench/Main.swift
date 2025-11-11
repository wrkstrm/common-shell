import ArgumentParser
import CommonProcess
import CommonProcessExecutionKit
import CommonShell
import CommonShellBenchSupport
import Foundation
import WrkstrmLog

@main
struct CommonShellBench: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "common-shell-bench",
    abstract: "Benchmark CommonShell host × runner matrix over simple workloads",
    subcommands: [Matrix.self, Metrics.self],
    defaultSubcommand: Matrix.self,
  )
}

// MARK: - Matrix command (legacy iteration-based benchmark)

struct Matrix: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Measure host × runner combinations by fixed iterations or duration",
  )

  @Option(name: .long, help: "Comma-separated hosts: direct,shell,env,npx,npm-exec")
  var hosts: String = "direct,shell,env,npx"

  @Option(name: .long, help: "Comma-separated runners: auto,foundation,tscbasic,subprocess")
  var runners: String = "auto,foundation,tscbasic,subprocess"

  @Option(
    name: .long,
    help:
      "Comma-separated routes: platform|auto|native|subprocess:<runner> (overrides --runners when provided)",
  )
  var routesSpec: String?

  @Option(name: .long, help: "Iterations per case (avg reported)")
  var iterations: Int = 20

  @Option(name: .long, help: "Benchmark payload text passed to target")
  var payload: String = "bench"

  @Option(name: .long, help: "Duration seconds (enables duration mode)")
  var duration: Double?

  @Option(name: .long, help: "Target frequency in Hertz for duration mode")
  var hz: Double?

  @Option(name: .long, help: "Target tool to execute (name or absolute path). Default: echo")
  var target: String = "echo"

  @Option(name: .long, help: "Output format: csv|json|table (default csv)")
  var format: String = "csv"

  @Option(name: .long, help: "Output file path (omit for stdout)")
  var output: String?

  @Option(name: .long, help: "Logging exposure: summary|verbose (default summary)")
  var logExposure: String = "summary"

  @Option(name: .long, help: "Workload scenario: echo|swift-version (default echo)")
  var workload: String = "echo"

  mutating func run() async throws {
    #if !DEBUG
    Log.Inject.setBackend(.print)
    Log.globalExposureLevel = .trace
    #endif

    let hostList = hosts.split(separator: ",").map {
      String($0).trimmingCharacters(in: .whitespaces)
    }
    let runnerList = runners.split(separator: ",").map {
      String($0).trimmingCharacters(in: .whitespaces)
    }
    let isVerbose = (logExposure.lowercased() == "verbose")

    var shell = CommonShell(
      workingDirectory: FileManager.default.currentDirectoryPath,
      executable: Executable.path("/bin/true"),
    )

    let benchWorkload = BenchSupport.BenchWorkload.make(
      rawValue: workload,
      target: target,
      payload: payload,
    )

    let exposure: ProcessExposure =
      switch logExposure.lowercased() {
      case "none": .none
      case "verbose": .verbose
      default: .summary
      }
    shell.logOptions.exposure = exposure

    if isVerbose {
      let env = ProcessInfo.processInfo.environment
      let log = Log(system: "wrkstrm.common-shell.bench", category: "bench")
      log.trace("PATH=\(env["PATH"] ?? "<nil>")")
      for key in ["NVM_BIN", "VOLTA_HOME", "ASDF_DATA_DIR", "HOME"] {
        if let value = env[key] { log.trace("\(key)=\(value)") }
      }
    }

    struct Row: Codable {
      let host: String
      let route: String
      let iterations: Int
      let totalMilliseconds: Double
      let averageMilliseconds: Double
    }

    var rows: [Row] = []

    if let routesSpec {
      let routes = parseRoutes(routesSpec)
      let hostCalls: [(String, BenchSupport.BenchCall)] = hostList.compactMap { host in
        guard let call = BenchSupport.buildCall(host: host, workload: benchWorkload) else {
          FileHandle.standardError.write(
            Data("[bench] skip host=\(host) for workload=\(benchWorkload.kind.rawValue)\n".utf8))
          return nil
        }
        return (host, call)
      }
      guard !hostCalls.isEmpty else { return }

      for (host, call) in hostCalls {
        for route in routes {
          guard let kind = runnerKind(for: route) else {
            FileHandle.standardError.write(
              Data("[bench] skip native route for now (host=\(host))\n".utf8))
            continue
          }
          if let seconds = duration, seconds > 0 {
            let metrics = try await shell.runForInterval(
              host: call.host,
              executable: call.executable,
              arguments: call.arguments,
              runnerKind: kind,
              durationSeconds: seconds,
              targetHz: hz,
            )
            guard metrics.iterations > 0 else { continue }
            rows.append(
              .init(
                host: host,
                route: routeLabel(route),
                iterations: metrics.iterations,
                totalMilliseconds: metrics.totalMS,
                averageMilliseconds: metrics.averageMS
              ))
          } else {
            _ = try? await shell.run(
              host: call.host,
              executable: call.executable,
              arguments: call.arguments,
              runnerKind: kind,
            )
            var totalNs: UInt64 = 0
            var ok = 0
            for _ in 0..<max(1, iterations) {
              let start = DispatchTime.now().uptimeNanoseconds
              if await
                (try? shell.run(
                  host: call.host,
                  executable: call.executable,
                  arguments: call.arguments,
                  runnerKind: kind,
                )) != nil
              {
                ok += 1
                totalNs &+= DispatchTime.now().uptimeNanoseconds - start
              }
            }
            guard ok > 0 else { continue }
            let totalMs = Double(totalNs) / 1_000_000.0
            let avgMs = totalMs / Double(ok)
            rows.append(
              .init(
                host: host,
                route: routeLabel(route),
                iterations: ok,
                totalMilliseconds: totalMs,
                averageMilliseconds: avgMs
              ))
          }
        }
      }
    } else {
      for host in hostList {
        guard let call = BenchSupport.buildCall(host: host, workload: benchWorkload) else {
          FileHandle.standardError.write(
            Data("[bench] skip host=\(host) for workload=\(benchWorkload.kind.rawValue)\n".utf8))
          continue
        }
        for runnerToken in runnerList {
          guard let kind = parseRunner(runnerToken) else { continue }
          if let seconds = duration, seconds > 0 {
            let metrics = try await shell.runForInterval(
              host: call.host,
              executable: call.executable,
              arguments: call.arguments,
              runnerKind: kind,
              durationSeconds: seconds,
              targetHz: hz,
            )
            guard metrics.iterations > 0 else { continue }
            rows.append(
              .init(
                host: host,
                route: runnerToken,
                iterations: metrics.iterations,
                totalMilliseconds: metrics.totalMS,
                averageMilliseconds: metrics.averageMS
              )
            )
          } else {
            _ = try? await shell.run(
              host: call.host,
              executable: call.executable,
              arguments: call.arguments,
              runnerKind: kind,
            )
            var totalNs: UInt64 = 0
            var ok = 0
            for _ in 0..<max(1, iterations) {
              let start = DispatchTime.now().uptimeNanoseconds
              if await
                (try? shell.run(
                  host: call.host,
                  executable: call.executable,
                  arguments: call.arguments,
                  runnerKind: kind,
                )) != nil
              {
                ok += 1
                totalNs &+= DispatchTime.now().uptimeNanoseconds - start
              }
            }
            guard ok > 0 else { continue }
            let totalMs = Double(totalNs) / 1_000_000.0
            let avgMs = totalMs / Double(ok)
            rows.append(
              .init(
                host: host,
                route: runnerToken,
                iterations: ok,
                totalMilliseconds: totalMs,
                averageMilliseconds: avgMs
              ))
          }
        }
      }
    }

    let rendered = BenchSupport.render(
      rows: rows.map {
        BenchRow(
          host: $0.host,
          route: $0.route,
          iterations: $0.iterations,
          totalMilliseconds: $0.totalMilliseconds,
          averageMilliseconds: $0.averageMilliseconds)
      },
      format: format,
    )

    if let outputPath = output, !outputPath.isEmpty {
      try rendered.write(
        to: URL(fileURLWithPath: outputPath),
        atomically: true,
        encoding: String.Encoding.utf8,
      )
    } else {
      print(rendered)
    }
  }
}

// MARK: - Metrics command (per-run statistics)

struct Metrics: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Collect average/min/max duration and peak memory per host × route",
  )

  @Option(name: .long, help: "Comma-separated hosts: direct,shell,env,npx,npm-exec")
  var hosts: String = "direct,shell,env,npx"

  @Option(name: .long, help: "Comma-separated runners: auto,foundation,tscbasic,subprocess")
  var runners: String = "auto,foundation,tscbasic,subprocess"

  @Option(
    name: .long,
    help:
      "Comma-separated routes: platform|auto|native|subprocess:<runner> (overrides --runners when provided)",
  )
  var routesSpec: String?

  @Option(name: .long, help: "Iterations per host × route (default 5)")
  var iterations: Int = 5

  @Option(name: .long, help: "Duration seconds per host × route sample (optional)")
  var duration: Double?

  @Option(name: .long, help: "Target tool to execute (default echo)")
  var target: String = "echo"

  @Option(name: .long, help: "Benchmark payload text passed to target")
  var payload: String = "bench"

  @Option(name: .long, help: "Workload scenario: echo|swift-version (default echo)")
  var workload: String = "echo"

  @Option(name: .long, help: "Logging exposure: summary|verbose (default summary)")
  var logExposure: String = "summary"

  mutating func run() async throws {
    #if !DEBUG
    Log.Inject.setBackend(.print)
    Log.globalExposureLevel = .trace
    #endif

    let hostList = hosts.split(separator: ",").map {
      String($0).trimmingCharacters(in: .whitespaces)
    }
    let runnerList = runners.split(separator: ",").map {
      String($0).trimmingCharacters(in: .whitespaces)
    }
    let durationSeconds: Double? = {
      guard let value = duration, value > 0 else { return nil }
      return value
    }()

    var shell = CommonShell(
      workingDirectory: FileManager.default.currentDirectoryPath,
      executable: Executable.path("/bin/true"),
    )

    let benchWorkload = BenchSupport.BenchWorkload.make(
      rawValue: workload,
      target: target,
      payload: payload,
    )

    shell.logOptions.exposure =
      switch logExposure.lowercased() {
      case "none": .none
      case "verbose": .verbose
      default: .summary
      }

    let hostCalls: [(String, BenchSupport.BenchCall)] = hostList.compactMap { host in
      guard let call = BenchSupport.buildCall(host: host, workload: benchWorkload) else {
        FileHandle.standardError.write(
          Data("[bench] skip host=\(host) for workload=\(benchWorkload.kind.rawValue)\n".utf8))
        return nil
      }
      return (host, call)
    }

    guard !hostCalls.isEmpty else { return }

    let sampleCount = max(iterations, 1)
    let recorder = BenchMetricsRecorder()
    ProcessMetrics.configure(recorder: recorder)
    defer { ProcessMetrics.reset() }

    // Benchmark module removed; running in reduced mode without extra metrics.

    if let routesSpec {
      let routes = parseRoutes(routesSpec)
      for (host, call) in hostCalls {
        for route in routes {
          guard let kind = runnerKind(for: route) else { continue }
          try await performMetricsIterations(
            count: sampleCount,
            host: host,
            routeLabel: routeLabel(route),
            shell: shell,
            call: call,
            runnerKind: kind,
            recorder: recorder,
            durationSeconds: durationSeconds,
          )
        }
      }
    } else {
      for (host, call) in hostCalls {
        for runnerToken in runnerList {
          guard let kind = parseRunner(runnerToken) else { continue }
          try await performMetricsIterations(
            count: sampleCount,
            host: host,
            routeLabel: runnerToken,
            shell: shell,
            call: call,
            runnerKind: kind,
            recorder: recorder,
            durationSeconds: durationSeconds,
          )
        }
      }
    }

    renderPerformanceTable(recorder.snapshot())
  }
}

// MARK: - Shared helpers

typealias RunnerKind = ProcessRunnerKind

private struct PerformanceRow {
  let host: String
  let route: String
  let iterations: Int
  let avgNs: Double
  let minNs: Double
  let maxNs: Double
  let peakBytes: Double
  let avgHz: Double
  let metrics: [String: Double]
}

private final class BenchMetricsRecorder: ProcessMetricsRecorder, @unchecked Sendable {
  private struct Key: Hashable {
    let host: String
    let route: String
  }
  private struct Record {
    var count: Int
    var totalNs: UInt64
    var minNs: UInt64
    var maxNs: UInt64
    var peakBytes: UInt64
    var metrics: [String: MetricAggregate]
  }

  private struct MetricAggregate {
    var total: Double = 0
    var min: Double = .infinity
    var max: Double = 0
    var count: Int = 0

    mutating func add(_ value: Double) {
      total += value
      min = Swift.min(min, value)
      max = Swift.max(max, value)
      count += 1
    }

    var average: Double {
      count > 0 ? total / Double(count) : 0
    }
  }

  fileprivate struct MetricDescriptor: Sendable {
    let key: String
    let header: String
    let formatter: @Sendable (Double) -> String
  }

  private static let metricDescriptorList: [MetricDescriptor] = [
    MetricDescriptor(
      key: "cpu_user_ms", header: "cpu_user_ms", formatter: { String(format: "%.3f", $0) }),
    MetricDescriptor(
      key: "cpu_system_ms", header: "cpu_system_ms", formatter: { String(format: "%.3f", $0) }),
    MetricDescriptor(
      key: "cpu_total_ms", header: "cpu_total_ms", formatter: { String(format: "%.3f", $0) }),
    MetricDescriptor(
      key: "resident_delta_mb", header: "resident_delta_mb",
      formatter: { String(format: "%.3f", $0) }),
    MetricDescriptor(
      key: "virtual_mb", header: "virtual_mb", formatter: { String(format: "%.3f", $0) }),
    MetricDescriptor(key: "phys_mb", header: "phys_mb", formatter: { String(format: "%.3f", $0) }),
    MetricDescriptor(
      key: "syscalls", header: "syscalls", formatter: { String(format: "%.0f", $0) }),
    MetricDescriptor(key: "ctx_sw", header: "ctx_sw", formatter: { String(format: "%.0f", $0) }),
    MetricDescriptor(key: "threads", header: "threads", formatter: { String(format: "%.1f", $0) }),
    MetricDescriptor(
      key: "threads_run", header: "threads_run", formatter: { String(format: "%.1f", $0) }),
    MetricDescriptor(
      key: "instructions", header: "instructions", formatter: { String(format: "%.0f", $0) }),
  ]

  private static let metricDescriptorLookup: [String: MetricDescriptor] =
    Dictionary(uniqueKeysWithValues: metricDescriptorList.map { ($0.key, $0) })

  static var metricDescriptors: [MetricDescriptor] { metricDescriptorList }

  private let queue = DispatchQueue(
    label: "wrkstrm.common-shell.bench.metrics",
    attributes: .concurrent,
  )
  private var storage: [Key: Record] = [:]
  private static let debugLog = Log(system: "wrkstrm.common-shell.bench", category: "metrics")

  func recordStart(
    command _: String,
    arguments _: [String],
    runnerName _: String,
    requestId _: String,
    tags _: [String: String],
    startUptimeNs _: UInt64,
  ) {}

  func recordCompletion(
    command _: String,
    arguments _: [String],
    runnerName _: String,
    requestId _: String,
    tags: [String: String],
    status _: ProcessExitStatus,
    processIdentifier _: String?,
    startUptimeNs: UInt64,
    endUptimeNs: UInt64,
    stdoutPreview _: String?,
    stderrPreview _: String?,
  ) {
    let duration = endUptimeNs &- startUptimeNs
    let residentBytes = currentResidentSizeBytes()
    let key = Key(host: tags["host"] ?? "unknown", route: tags["route"] ?? "unknown")
    queue.async(flags: .barrier) {
      var record =
        self.storage[key]
        ?? Record(
          count: 0,
          totalNs: 0,
          minNs: duration,
          maxNs: duration,
          peakBytes: residentBytes,
          metrics: [:],
        )
      record.count += 1
      record.totalNs &+= duration
      record.minNs = min(record.minNs, duration)
      record.maxNs = max(record.maxNs, duration)
      record.peakBytes = max(record.peakBytes, residentBytes)
      self.storage[key] = record
    }
  }

  func recordMetrics(
    tags: [String: String],
    metrics: [String: Double],
  ) {
    guard !metrics.isEmpty else { return }
    let key = Key(host: tags["host"] ?? "unknown", route: tags["route"] ?? "unknown")
    var summaries: [(String, Double)] = []
    summaries.reserveCapacity(metrics.count)

    for (metricKey, value) in metrics {
      guard let descriptor = BenchMetricsRecorder.metricDescriptorLookup[metricKey] else {
        continue
      }
      if ProcessInfo.processInfo.environment["COMMON_SHELL_DEBUG_METRICS"] != nil {
        BenchMetricsRecorder.debugLog.trace(
          "[bench] metric \(descriptor.key)=\(value)",
          metadata: [
            "metric": .string(descriptor.key),
            "value": .stringConvertible(value),
            "host": .string(key.host),
            "route": .string(key.route),
          ])
      }
      summaries.append((descriptor.key, value))
    }

    guard !summaries.isEmpty else { return }

    let metricsSummary = summaries
    queue.async(flags: .barrier) {
      var record =
        self.storage[key]
        ?? Record(
          count: 0,
          totalNs: 0,
          minNs: .max,
          maxNs: 0,
          peakBytes: 0,
          metrics: [:],
        )

      for (metricKey, value) in metricsSummary {
        var aggregate = record.metrics[metricKey] ?? MetricAggregate()
        aggregate.add(value)
        record.metrics[metricKey] = aggregate
      }

      self.storage[key] = record
    }
  }

  func snapshot() -> [PerformanceRow] {
    queue.sync {
      storage.map { key, record in
        let avgNs = Double(record.totalNs) / Double(max(record.count, 1))
        let totalSeconds = Double(record.totalNs) / 1_000_000_000.0
        let avgHz =
          (record.count > 0 && totalSeconds > 0)
          ? Double(record.count) / totalSeconds
          : 0
        #if canImport(Benchmark)
        var metricValues: [String: Double] = [:]
        for descriptor in BenchMetricsRecorder.metricDescriptors {
          if let aggregate = record.metrics[descriptor.key] {
            metricValues[descriptor.key] = aggregate.average
          }
        }
        #else
        let metricValues: [String: Double] = [:]
        #endif
        return PerformanceRow(
          host: key.host,
          route: key.route,
          iterations: record.count,
          avgNs: avgNs,
          minNs: Double(record.minNs),
          maxNs: Double(record.maxNs),
          peakBytes: Double(record.peakBytes),
          avgHz: avgHz,
          metrics: metricValues,
        )
      }.sorted { ($0.host, $0.route) < ($1.host, $1.route) }
    }
  }
}

private struct RecorderInstrumentation: ProcessInstrumentation {
  let tags: [String: String]
  let recorder: BenchMetricsRecorder

  func willStart(
    command: String,
    arguments: [String],
    workingDirectory _: String,
    runnerName: String,
    requestId: String,
    startUptimeNs: UInt64,
  ) {
    recorder.recordStart(
      command: command,
      arguments: arguments,
      runnerName: runnerName,
      requestId: requestId,
      tags: tags,
      startUptimeNs: startUptimeNs,
    )
  }

  func didFinish(
    command: String,
    arguments: [String],
    workingDirectory _: String,
    runnerName: String,
    requestId: String,
    status: ProcessExitStatus,
    processIdentifier: String?,
    startUptimeNs: UInt64,
    endUptimeNs: UInt64,
    stdoutPreview: String?,
    stderrPreview: String?,
  ) {
    recorder.recordCompletion(
      command: command,
      arguments: arguments,
      runnerName: runnerName,
      requestId: requestId,
      tags: tags,
      status: status,
      processIdentifier: processIdentifier,
      startUptimeNs: startUptimeNs,
      endUptimeNs: endUptimeNs,
      stdoutPreview: stdoutPreview,
      stderrPreview: stderrPreview,
    )
  }
}

private func parseRunner(_ value: String) -> RunnerKind? {
  switch value.lowercased() {
  case "auto": .auto
  case "foundation": .foundation
  case "tscbasic": .tscbasic
  case "subprocess": .subprocess
  default: nil
  }
}

private func parseRoutes(_ spec: String) -> [ShellRouteKind] {
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

private func runnerKind(for route: ShellRouteKind) -> RunnerKind? {
  switch route {
  case .auto: .auto
  case .subprocess(let kind): kind
  case .native: nil
  }
}

private func routeLabel(_ route: ShellRouteKind) -> String {
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
private func performMetricsIterations(
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

private func currentResidentSizeBytes() -> UInt64 {
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
private func currentResidentSizeBytes() -> UInt64 { 0 }
#endif

private func renderPerformanceTable(_ rows: [PerformanceRow]) {
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
