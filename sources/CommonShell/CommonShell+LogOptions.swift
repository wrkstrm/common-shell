import CommonProcess

extension CommonShell {
  @inline(__always)
  func makeProcessOptions() -> ProcessLogOptions {
    let exposure: ProcessExposure =
      switch logOptions.exposure {
      case .none: .none
      case .summary: .summary
      case .verbose: .verbose
      }
    return ProcessLogOptions(
      exposure: exposure,
      maxStdoutBytes: logOptions.maxStdoutBytes,
      maxStderrBytes: logOptions.maxStderrBytes,
      maxStdoutLines: logOptions.maxStdoutLines,
      maxStderrLines: logOptions.maxStderrLines,
      showHeadTail: logOptions.showHeadTail,
      headLines: logOptions.headLines,
      tailLines: logOptions.tailLines,
      capturePid: true,
    )
  }
}
