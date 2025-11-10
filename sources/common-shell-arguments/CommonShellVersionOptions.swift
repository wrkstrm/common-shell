import ArgumentParser

/// Standard version flags shared across CLI tools.
/// Extend over time as needed to surface build metadata in a consistent way.
public struct CommonShellVersionOptions: ParsableArguments {
  /// Print epoch seconds for the current build (if supported by the tool).
  @Flag(name: .customLong("version-seconds"), help: "Print epoch seconds for build (if supported)")
  public var versionSeconds: Bool = false

  public init() {}
}
