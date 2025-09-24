import ArgumentParser
import CommonProcess
import CommonProcessRunners
import Foundation

/// Decode any supported shell spec representation.
func decodeAnySpec(from data: Data) throws -> DecodedSpec {
  let decoder = JSONDecoder()
  if let spec = try? decoder.decode(ShellSpec.self, from: data) {
    return try mapNewSpec(spec)
  }
  if let env = try? decoder.decode(NewInvocationEnvelope.self, from: data), let spec = env.spec {
    return try mapNewSpec(spec)
  }
  // Support Invocation JSON directly: map to a host based on executable metadata.
  if let inv = try? decoder.decode(Invocation.self, from: data) {
    let host = inv.hostKind ?? defaultHost(for: inv.executable)
    return DecodedSpec(
      host: host,
      executable: inv.executable,
      args: inv.args,
      cwd: inv.workingDirectory,
      runner: inv.runnerKind,
      env: (inv.env?.asDictionary()) ?? [:],
      maxStdoutBytes: inv.logOptions.maxStdoutBytes,
      maxStderrBytes: inv.logOptions.maxStderrBytes,
      exposure: inv.logOptions.exposure,
    )
  }
  // Legacy formats are no longer supported.
  throw ValidationError("Unrecognized spec format")
}

/// Map a ShellSpec into a normalized DecodedSpec for execution.
func mapNewSpec(_ spec: ShellSpec) throws -> DecodedSpec {
  let call: (host: ExecutionHostKind, executable: Executable, arguments: [String]) = {
    switch spec.wrapper {
    case .direct:
      guard let exe = spec.executable ?? spec.name else {
        fatalError("direct requires executable")
      }
      let executable =
        exe.contains("/")
        ? Executable.path(exe, options: spec.options)
        : Executable.name(exe, options: spec.options)
      return (host: .direct, executable: executable, arguments: [])

    case .shell:
      guard let cmd = spec.command else { fatalError("shell requires command") }
      return (
        host: .shell(options: spec.options),
        executable: Executable.path("/bin/sh"),
        arguments: [cmd],
      )

    case .env:
      let tool = spec.name ?? spec.executable ?? (spec.args.first ?? "")
      if tool.isEmpty { fatalError("env requires name or executable") }
      let executable = tool.contains("/") ? Executable.path(tool) : Executable.name(tool)
      return (host: .env(options: spec.options), executable: executable, arguments: [])

    case .npx:
      return (host: .npx(options: spec.options), executable: Executable.none(), arguments: [])

    case .npm:
      return (
        host: .npm(options: spec.options),
        executable: Executable.name("npm"),
        arguments: [],
      )
    }
  }()

  let args = call.arguments + spec.args

  return DecodedSpec(
    host: call.host,
    executable: call.executable,
    args: args,
    cwd: spec.cwd,
    runner: spec.runner.flatMap { mapRunner($0.rawValue) },
    env: spec.env ?? [:],
    maxStdoutBytes: spec.maxStdoutBytes,
    maxStderrBytes: spec.maxStderrBytes,
    exposure: nil,
  )
}

private func defaultHost(for executable: Executable) -> ExecutionHostKind {
  switch executable.ref {
  case .name:
    .env(options: [])

  case .path, .none:
    .direct
  }
}
