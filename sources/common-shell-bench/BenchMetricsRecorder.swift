import CommonProcess
import Foundation
import WrkstrmLog

struct PerformanceRow {
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

final class BenchMetricsRecorder: ProcessMetricsRecorder, @unchecked Sendable {
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
          "[bench] metric \(descriptor.key)=\(value) host=\(key.host) route=\(key.route)")
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

struct RecorderInstrumentation: ProcessInstrumentation {
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
