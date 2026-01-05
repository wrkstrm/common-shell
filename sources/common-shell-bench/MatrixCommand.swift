import ArgumentParser
import CommonProcess
import CommonProcessExecutionKit
import CommonShell
import CommonShellBenchSupport
import Foundation
import WrkstrmLog

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
