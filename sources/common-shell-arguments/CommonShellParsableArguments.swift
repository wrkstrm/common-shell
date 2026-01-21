import ArgumentParser
import CommonProcess
import CommonProcessExecutionKit
import CommonShell
import Foundation
import WrkstrmFoundation
import CommonLog

/// Protocol for types that expose common shell arguments
public protocol CommonShellParsableArguments {
  var common: CommonShellArguments { get }
}

extension CommonShellParsableArguments {
  /// Configure a CommonShell based on common arguments
  public func configuredShell() throws -> CommonShell {
    let workingDirectory: String =
      common.workingDirectory?.homeExpandedString()
      ?? FileManager.default.currentDirectoryPath
    Log.verbose("Configured Working Directory: \(workingDirectory)")
    return CommonShell(
      workingDirectory: workingDirectory,
      executable: Executable.path("/usr/bin/env"),
    )
  }
}
