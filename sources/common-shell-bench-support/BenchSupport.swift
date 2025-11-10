import CommonProcess
import CommonShell
import Foundation

/// Utilities for constructing and rendering CommonShell benchmark scenarios.
public enum BenchSupport {
  public struct BenchWorkload {
    public enum Kind: String {
      case echo
      case swiftVersion = "swift-version"
    }

    public let kind: Kind
    public let target: String
    public let payload: String

    public init(kind: Kind, target: String, payload: String) {
      self.kind = kind
      self.target = target
      self.payload = payload
    }

    public static func make(rawValue: String?, target: String, payload: String) -> BenchWorkload {
      let normalized = rawValue?.lowercased() ?? Kind.echo.rawValue
      let kind = Kind(rawValue: normalized) ?? .echo
      return BenchWorkload(kind: kind, target: target, payload: payload)
    }
  }

  /// Explicit tuple representing a host invocation for benchmarking.
  public typealias BenchCall = (
    host: ExecutionHostKind,
    executable: Executable,
    arguments: [String]
  )
  /// Build a call tuple for a given host/workload combination.
  /// - Parameters:
  ///   - host: one of: direct|shell|env|npm-run|npm-exec|npx (fallback env)
  ///   - workload: workload definition controlling target/payload mapping
  /// - Returns: `(host:executable:arguments:)` suitable for `CommonShell.run(host:executable:arguments:)`.
  public static func buildCall(host: String, workload: BenchWorkload) -> BenchCall? {
    switch workload.kind {
    case .echo:
      buildEchoCall(host: host, target: workload.target, payload: workload.payload)

    case .swiftVersion:
      buildSwiftVersionCall(host: host)
    }
  }

  private static func buildEchoCall(host: String, target: String, payload: String) -> BenchCall {
    switch host {
    case "direct":
      let exe = target.contains("/") ? target : (target == "echo" ? "/bin/echo" : target)
      let executable = exe.contains("/") ? Executable.path(exe) : Executable.name(exe)
      return (host: .direct, executable: executable, arguments: payload.isEmpty ? [] : [payload])

    case "shell":
      let command = payload.isEmpty ? target : "\(target) \(payload)"
      return (
        host: .shell(options: []),
        executable: Executable.path("/bin/sh"),
        arguments: [command],
      )

    case "env":
      let executable = target.contains("/") ? Executable.path(target) : Executable.name(target)
      return (
        host: .env(options: []), executable: executable,
        arguments: payload.isEmpty ? [] : [payload],
      )

    case "npm-run":
      // npm run <script> [-- payload]
      var args = ["run", target]
      if !payload.isEmpty { args += ["--", payload] }
      return (host: .npm(options: []), executable: Executable.name("npm"), arguments: args)

    case "npm-exec":
      // npm exec -- <tool> <payload>
      var argv = ["exec", "--", target]
      if !payload.isEmpty { argv.append(payload) }
      return (host: .npm(options: []), executable: Executable.name("npm"), arguments: argv)

    case "npx":
      // npx -y -c "<target> <payload>"
      let components = payload.isEmpty ? [target] : [target, payload]
      let command = components.joined(separator: " ").trimmingCharacters(in: .whitespaces)
      let args: [String] = ["-y", "-c", command]
      return (host: .npx(options: []), executable: Executable.none(), arguments: args)

    default:
      let executable = target.contains("/") ? Executable.path(target) : Executable.name(target)
      return (
        host: .env(options: []), executable: executable,
        arguments: payload.isEmpty ? [] : [payload],
      )
    }
  }

  private static func buildSwiftVersionCall(host: String) -> BenchCall? {
    switch host {
    case "direct":
      (host: .direct, executable: Executable.name("swift"), arguments: ["--version"])

    case "shell":
      (
        host: .shell(options: []), executable: Executable.path("/bin/sh"),
        arguments: ["swift --version"]
      )

    case "env":
      (
        host: .env(options: []), executable: Executable.name("swift"), arguments: ["--version"]
      )

    case "npm-exec":
      (
        host: .npm(options: []),
        executable: Executable.name("npm"),
        arguments: ["exec", "--", "swift", "--version"]
      )

    case "npx":
      (
        host: .npx(options: []), executable: Executable.none(),
        arguments: ["-y", "-c", "swift --version"]
      )

    case "npm-run":
      nil

    default:
      (
        host: .env(options: []), executable: Executable.name("swift"), arguments: ["--version"]
      )
    }
  }

  /// Render benchmark rows to the requested format (json|table|csv).
  /// - Parameters:
  ///   - rows: collection of measurements
  ///   - format: output format; defaults to csv when unknown
  /// - Returns: a formatted string
  public static func render(rows: [BenchRow], format: String) -> String {
    let fmt = format.lowercased()
    switch fmt {
    case "json":
      let enc = JSONEncoder()
      enc.outputFormatting = [.prettyPrinted, .sortedKeys]
      return String(data: (try? enc.encode(rows)) ?? Data("[]".utf8), encoding: .utf8) ?? "[]"

    case "table":
      let headers = ["host", "route", "iterations", "total_ms", "avg_ms"]
      var widths = headers.map(\.count)
      let values: [[String]] = rows.map { r in
        [
          r.host, r.route, String(r.iterations), String(format: "%.1f", r.total_ms),
          String(format: "%.3f", r.avg_ms),
        ]
      }
      for v in values {
        for (i, s) in v.enumerated() {
          widths[i] = max(widths[i], s.count)
        }
      }
      func pad(_ s: String, _ w: Int, right: Bool = false) -> String {
        let n = max(0, w - s.count)
        return right ? String(repeating: " ", count: n) + s : s + String(repeating: " ", count: n)
      }
      var lines: [String] = []
      lines.append(zip(headers, widths).map { pad($0.0, $0.1) }.joined(separator: "  "))
      lines.append(widths.map { String(repeating: "-", count: $0) }.joined(separator: "  "))
      for v in values {
        lines.append(zip(v, widths).map { pad($0.0, $0.1, right: true) }.joined(separator: "  "))
      }
      return lines.joined(separator: "\n") + "\n"

    default:
      var csv = "host,route,iterations,total_ms,avg_ms\n"
      for r in rows {
        let t = String(format: "%.1f", r.total_ms)
        let a = String(format: "%.3f", r.avg_ms)
        csv += "\(r.host),\(r.route),\(r.iterations),\(t),\(a)\n"
      }
      return csv
    }
  }
}
