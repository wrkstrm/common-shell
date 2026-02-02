import CommonProcess
import Foundation

extension CommonShell {
  /// Convenience for creating a shell bound to the GitHub CLI.
  public static func gitHubCLI(
    workingDirectory: String = FileManager.default.currentDirectoryPath,
    hostKind: ExecutionHostKind? = .env(options: [])
  ) -> CommonShell {
    CommonShell(workingDirectory: workingDirectory, executable: .name("gh"), hostKind: hostKind)
  }
}
