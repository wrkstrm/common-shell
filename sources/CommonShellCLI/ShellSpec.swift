import Foundation

/// Minimal, JSON-decodable shell spec used by the CLI.
struct ShellSpec: Decodable {
  /// Wrapper to apply when executing the spec.
  enum Wrapper: String, Decodable { case direct, shell, env, npx, npm }
  /// Runner to use when executing.
  enum Runner: String, Decodable { case auto, subprocess, foundation, tscbasic }

  /// Wrapper selection.
  var wrapper: Wrapper
  /// Executable path (for .direct) or optional path when used with .env.
  var executable: String?
  /// Tool name to resolve via PATH (for .env).
  var name: String?
  /// Command line for .shell wrapper.
  var command: String?
  /// Options to prepend.
  var options: [String] = []
  /// Arguments for invocation.
  var args: [String] = []
  /// Working directory.
  var cwd: String?
  /// Optional explicit runner selection.
  var runner: Runner? = .auto
  /// Environment overrides for the invocation.
  var env: [String: String]?
  /// Optional stdout byte cap for previews.
  var maxStdoutBytes: Int?
  /// Optional stderr byte cap for previews.
  var maxStderrBytes: Int?
}

/// Envelope for specifying API version and nested spec.
struct NewInvocationEnvelope: Decodable {
  /// Optional API version.
  var api: Int?
  /// Nested shell spec.
  var spec: ShellSpec?
}
