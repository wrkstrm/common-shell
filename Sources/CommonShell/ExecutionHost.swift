import CommonProcess
import Foundation

protocol ExecutionHost: Sendable {
  var kind: ExecutionHostKind { get }
  func resolve(invocation: CommandInvocation) -> CommandInvocation
}

extension ExecutionHostKind {
  func makeHost() -> any ExecutionHost {
    switch self {
    case .direct:
      DirectHost()

    case .shell(let options):
      ShellHost(options: options)

    case .env(let options):
      EnvHost(options: options)

    case .npx(let options):
      NpxHost(options: options)

    case .npm(let options):
      NpmHost(options: options)
    }
  }
}

private struct DirectHost: ExecutionHost {
  let kind: ExecutionHostKind = .direct
  func resolve(invocation: CommandInvocation) -> CommandInvocation {
    var out = invocation
    out.hostKind = nil
    return out
  }
}

private struct ShellHost: ExecutionHost {
  let options: [String]
  var kind: ExecutionHostKind { .shell(options: options) }

  func resolve(invocation: CommandInvocation) -> CommandInvocation {
    var exec = invocation.executable
    exec.options = options
    if exec.arguments.isEmpty { exec.arguments = ["-c"] }
    var out = invocation
    out.executable = exec
    out.hostKind = nil
    return out
  }
}

private struct EnvHost: ExecutionHost {
  let options: [String]
  var kind: ExecutionHostKind { .env(options: options) }

  func resolve(invocation: CommandInvocation) -> CommandInvocation {
    let target = invocation.executable
    let token: String =
      switch target.ref {
      case .name(let n):
        n

      case .path(let p):
        p

      case .none:
        invocation.args.first ?? ""
      }
    let prefixArgs = target.options + target.arguments
    var exec = Executable.path("/usr/bin/env")
    exec.options = options
    exec.arguments = [token]
    var out = invocation
    out.executable = exec
    out.args = prefixArgs + invocation.args
    out.hostKind = nil
    return out
  }
}

private struct NpmHost: ExecutionHost {
  let options: [String]
  var kind: ExecutionHostKind { .npm(options: options) }

  func resolve(invocation: CommandInvocation) -> CommandInvocation {
    var exec = Executable.path("/usr/bin/env")
    exec.options = options
    exec.arguments = ["npm"]
    var out = invocation
    out.executable = exec
    out.hostKind = nil
    return out
  }
}

private struct NpxHost: ExecutionHost {
  let options: [String]
  var kind: ExecutionHostKind { .npx(options: options) }

  func resolve(invocation: CommandInvocation) -> CommandInvocation {
    if let nodeAbs = Executable.resolveAbsolute("node"),
      let npxCli = CommonShell.resolveNpxCliAbsolute()
    {
      var exec = Executable.path(nodeAbs)
      exec.options = options
      exec.arguments = [npxCli]
      var out = invocation
      out.executable = exec
      out.hostKind = nil
      return out
    }
    if let npxAbs = Executable.resolveAbsolute("npx") {
      var exec = Executable.path(npxAbs)
      exec.options = options
      var out = invocation
      out.executable = exec
      out.hostKind = nil
      return out
    }
    var exec = Executable.path("/usr/bin/env")
    exec.options = options
    exec.arguments = ["npx"]
    var out = invocation
    out.executable = exec
    out.hostKind = nil
    return out
  }
}

extension ExecutionHostKind {
  var label: String {
    switch self {
    case .direct: "direct"
    case .shell: "shell"
    case .env: "env"
    case .npx: "npx"
    case .npm: "npm"
    }
  }
}
