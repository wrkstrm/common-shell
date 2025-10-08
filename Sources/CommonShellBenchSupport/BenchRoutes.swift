import CommonProcess
import CommonProcessExecutionKit
import CommonShell
import Foundation

public enum BenchRoutes: Sendable {
  /// Produce the platform‑aware route list based on the given plan.
  public static func routes(using plan: ShellRoutePlan = .init()) -> [ShellRouteKind] {
    ShellRouteKind.all(using: plan)
  }

  /// Cross-product of hosts × routes for matrix benchmarks.
  public static func cross(
    hosts: [ExecutionHostKind],
    routes: [ShellRouteKind],
  ) -> [(ExecutionHostKind, ShellRouteKind)] {
    var pairs: [(ExecutionHostKind, ShellRouteKind)] = []
    for host in hosts {
      for route in routes {
        pairs.append((host, route))
      }
    }
    return pairs
  }
}
