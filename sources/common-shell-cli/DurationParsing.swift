import Foundation

/// Maximum allowed duration in seconds to prevent runaway benchmarks.
let maxDurationSeconds: Double = 60.0

/// Parses a duration from strings like `5s`, `200ms`, or raw seconds `0.3`.
/// - Parameter raw: user-provided duration string.
/// - Returns: duration in seconds, clamped to `maxDurationSeconds`.
/// - Throws: `DurationParseError.invalid` for unrecognized formats.
func parseDurationSeconds(_ raw: String) throws -> Double {
  let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  if s.hasSuffix("ms"), let v = Double(s.dropLast(2)) { return min(v / 1000.0, maxDurationSeconds) }
  if s.hasSuffix("s"), let v = Double(s.dropLast(1)) { return min(v, maxDurationSeconds) }
  if let v = Double(s) { return min(v, maxDurationSeconds) }
  throw DurationParseError.invalid
}
