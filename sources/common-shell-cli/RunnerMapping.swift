import CommonProcess
import CommonProcessExecutionKit

/// Maps a runner string to a ProcessRunnerKind.
func mapRunner(_ s: String) -> ProcessRunnerKind? {
  switch s.lowercased() {
  case "auto": .auto
  case "subprocess": .subprocess
  case "foundation": .foundation
  case "tscbasic": .tscbasic
  default: .auto
  }
}
