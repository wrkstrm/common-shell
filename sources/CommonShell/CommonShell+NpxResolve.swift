import CommonProcess
import CommonProcessExecutionKit
import Foundation

extension CommonShell {
  /// Run an arbitrary command via NPX transport.
  /// This uses `/usr/bin/env npx` with `-c` and an optional `-y` auto-yes flag.
  @discardableResult
  public func runNpxCommand(
    _ commandLine: String,
    autoYes: Bool = true,
    extraOptions: [String] = [],
  ) async throws -> String {
    if Executable.resolveAbsolute("npx") == nil {
      let warn = "[CommonShell] warn: 'npx' not found on PATH; attempting via env anyway\n"
      FileHandle.standardError.write(Data(warn.utf8))
    }
    var args: [String] = []
    if autoYes { args.append("-y") }
    args.append(contentsOf: extraOptions)
    args.append(contentsOf: ["-c", commandLine])
    return try await run(
      host: .npx(options: []),
      executable: Executable.none(),
      arguments: args,
      runnerKind: .auto,
    )
  }
}

extension CommonShell {
  static func resolveNpxCliAbsolute() -> String? {
    let fm = FileManager.default
    var candidates = [
      "/opt/homebrew/lib/node_modules/npm/bin/npx-cli.js",
      "/usr/local/lib/node_modules/npm/bin/npx-cli.js",
    ]
    let env = ProcessInfo.processInfo.environment
    if let volta = env["VOLTA_HOME"], !volta.isEmpty {
      let inv = URL(fileURLWithPath: volta).appendingPathComponent("tools/inventory/node")
      if let subs = try? fm.contentsOfDirectory(atPath: inv.path) {
        for s in subs {
          candidates.append(
            inv.appendingPathComponent(s).appendingPathComponent(
              "lib/node_modules/npm/bin/npx-cli.js",
            ).path)
        }
      }
    }
    let asdfBase: String? = env["ASDF_DATA_DIR"] ?? (env["HOME"].map { $0 + "/.asdf" })
    if let asdf = asdfBase, !asdf.isEmpty {
      let inst = URL(fileURLWithPath: asdf).appendingPathComponent("installs/nodejs")
      if let subs = try? fm.contentsOfDirectory(atPath: inst.path) {
        for s in subs {
          candidates.append(
            inst.appendingPathComponent(s).appendingPathComponent(
              "lib/node_modules/npm/bin/npx-cli.js",
            ).path)
        }
      }
    }
    if let home = env["HOME"], !home.isEmpty {
      let nvmVers = URL(fileURLWithPath: home).appendingPathComponent(".nvm/versions/node")
      if let subs = try? fm.contentsOfDirectory(atPath: nvmVers.path) {
        for s in subs {
          candidates.append(
            nvmVers.appendingPathComponent(s).appendingPathComponent(
              "lib/node_modules/npm/bin/npx-cli.js",
            ).path)
        }
      }
    }
    for c in candidates where fm.fileExists(atPath: c) {
      return c
    }
    return nil
  }
}
