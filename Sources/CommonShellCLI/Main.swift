import ArgumentParser
import CommonProcess
import CommonProcessRunners
import CommonShell
import CommonShellBenchSupport
import Foundation

/// CLI entry point for executing CommonShell specs from JSON.
@main
struct CommonShellMain: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "common-shell",
    abstract: "Run a CommonShell spec from JSON; supports duration benchmarking",
  )

  @Option(
    name: .customLong("file"),
    help: "Path to JSON spec (reads stdin when omitted)",
  )
  var filePath: String?

  @Option(
    name: .customLong("for"),
    help: "Duration like 5s, 200ms, or seconds (e.g., 0.3)",
  )
  var durationSpec: String?

  @Option(
    name: .customLong("hz"),
    help: "Target frequency in Hertz for duration loops",
  )
  var targetFrequencyHz: Double?

  @Option(
    name: .customLong("log-level"),
    help: "Log level: none|summary|verbose (controls command echo)",
  )
  var logLevel: String?

  @Flag(name: .customLong("version"), help: "Print version and exit")
  var printVersionOnly: Bool = false

  @Option(
    name: .customLong("instrumentation-key"),
    help: "Optional instrumentation key (e.g., noop)",
  )
  var instrumentationKey: String?

  @Option(
    name: .customLong("runner-kind"),
    help: "Preferred runner: auto|subprocess|foundation|tscbasic",
  )
  var preferredRunnerKind: String?

  /// Entry point: reads the spec, configures a shell, and executes.
  mutating func run() async throws {
    if printVersionOnly {
      print("common-shell 1.0.0")
      return
    }

    let inputData = try readInputData(filePath: filePath)
    let decoded = try decodeAnySpec(from: inputData)

    // Base shell
    var shell = CommonShell(
      workingDirectory: decoded.cwd ?? FileManager.default.currentDirectoryPath,
      executable: Executable.path("/usr/bin/env"),
    )
    // Apply instrumentation if requested
    if let k = instrumentationKey, !k.isEmpty {
      let key = InstrumentationKey(rawValue: k) ?? .noop
      shell.instrumentation = InstrumentationFactory.make(key)
    }
    if let lvl = logLevel?.lowercased() {
      switch lvl {
      case "verbose", "debug": shell.logOptions.exposure = .verbose
      case "summary", "info": shell.logOptions.exposure = .summary
      default: shell.logOptions.exposure = .none
      }
    } else if let e = decoded.exposure {
      shell.logOptions.exposure = e
    }
    if let pb = decoded.maxStdoutBytes { shell.logOptions.maxStdoutBytes = pb }
    if let eb = decoded.maxStderrBytes { shell.logOptions.maxStderrBytes = eb }

    // Resolve preferred runner (CLI flag overrides JSON)
    func parseRunnerKind(_ raw: String) -> ProcessRunnerKind? {
      switch raw.lowercased() {
      case "auto": .auto
      case "subprocess": .subprocess
      case "foundation": .foundation
      case "tscbasic": .tscbasic
      default: nil
      }
    }
    let cliRunner: ProcessRunnerKind? = preferredRunnerKind.flatMap(parseRunnerKind)

    let envOverrides = decoded.env.isEmpty ? nil : decoded.env

    if let durationSpec {
      let seconds = try parseDurationSeconds(durationSpec)
      let metrics = try await shell.runForInterval(
        host: decoded.host,
        executable: decoded.executable,
        arguments: decoded.args,
        environment: envOverrides,
        runnerKind: cliRunner ?? decoded.runner,
        durationSeconds: seconds,
        targetHz: targetFrequencyHz,
      )
      print(
        renderSummary(
          iterations: metrics.iterations,
          totalMS: metrics.totalMS,
          averageMS: metrics.averageMS,
        ),
      )
    } else {
      let output = try await shell.run(
        host: decoded.host,
        executable: decoded.executable,
        arguments: decoded.args,
        environment: envOverrides,
        runnerKind: cliRunner ?? decoded.runner,
      )
      fputs(output, stdout)
    }
  }
}

// MARK: - IO helpers

/// Reads input from a file path or stdin when omitted.
private func readInputData(filePath: String?) throws -> Data {
  guard let path = filePath else {
    return FileHandle.standardInput.readDataToEndOfFile()
  }
  guard let contents = FileManager.default.contents(atPath: path) else {
    throw ValidationError("Failed to read file: \(path)")
  }
  return contents
}
