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
  public let totalMilliseconds: Double
  /// Average time per iteration in milliseconds.
  public let averageMilliseconds: Double

  /// Create a new benchmark row.
  public init(
    host: String,
    route: String,
    iterations: Int,
    totalMilliseconds: Double,
    averageMilliseconds: Double
  ) {
    self.host = host
    self.route = route
    self.iterations = iterations
    self.totalMilliseconds = totalMilliseconds
    self.averageMilliseconds = averageMilliseconds
  }

  private enum CodingKeys: String, CodingKey {
    case host
    case route
    case iterations
    case totalMilliseconds = "total_ms"
    case averageMilliseconds = "avg_ms"
  }
}
