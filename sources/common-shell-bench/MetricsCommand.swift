import ArgumentParser
import CommonProcess
import CommonProcessExecutionKit
import CommonShell
import CommonShellBenchSupport
import Foundation
import CommonLog

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
