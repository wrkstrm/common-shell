import Foundation

/// A single measurement row produced by the benchmark harness.
public struct BenchRow: Codable, Equatable {
  /// The host used (direct|shell|env|npm|npx).
  public let host: String
  /// The route used (e.g., auto|native|subprocess:<runner>).
  public let route: String
  /// Number of iterations completed during the run.
  public let iterations: Int
  /// Total elapsed time in milliseconds.
  public let total_ms: Double
  /// Average time per iteration in milliseconds.
  public let avg_ms: Double

  /// Create a new benchmark row.
  public init(host: String, route: String, iterations: Int, total_ms: Double, avg_ms: Double) {
    self.host = host
    self.route = route
    self.iterations = iterations
    self.total_ms = total_ms
    self.avg_ms = avg_ms
  }
}
