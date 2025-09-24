import CommonProcess
import CommonProcessRunners
import Foundation

/// Route hint for CommonShell deciding how to execute a run.
/// Keeps identity (Executable) separate from backend selection.
public enum ShellRouteKind: Sendable, Hashable {
  case auto
  case native
  case subprocess(ProcessRunnerKind)
}

/// Plan describing which routes to include for enumeration (e.g., benchmarks).
public struct ShellRoutePlan: Sendable, Equatable {
  public var includeAuto: Bool
  public var includeNative: Bool
  public var runners: [ProcessRunnerKind]

  public init(
    includeAuto: Bool = true,
    includeNative: Bool = true,
    runners: [ProcessRunnerKind] = CommonProcessRunners.supportedKinds(),
  ) {
    self.includeAuto = includeAuto
    self.includeNative = includeNative
    self.runners = runners
  }
}

extension ShellRouteKind {
  /// Expand the plan into concrete route kinds.
  public static func all(using plan: ShellRoutePlan) -> [ShellRouteKind] {
    var out: [ShellRouteKind] = []
    if plan.includeAuto { out.append(.auto) }
    if plan.includeNative { out.append(.native) }
    out += plan.runners.map { .subprocess($0) }
    return out
  }
}
