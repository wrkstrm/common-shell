import ArgumentParser
import Foundation

/// Common CLI arguments used across tools that execute subprocesses.
public struct CommonShellArguments: ParsableArguments {
  @Option(name: .shortAndLong, help: "The working directory to run the command in.")
  public var workingDirectory: String?

  @Option(name: .shortAndLong, parsing: .singleValue, help: "The output directory.")
  public var outputs: [String] = []

  @Flag(name: .shortAndLong, help: "Enables verbose logging.")
  public var verbose = false

  public init() {}
}
