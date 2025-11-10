import Foundation

/// Maximum allowed duration in seconds to prevent runaway benchmarks.
let MaxDurationSeconds: Double = 60.0

/// Parses a duration from strings like `5s`, `200ms`, or raw seconds `0.3`.
/// - Parameter raw: user-provided duration string.
/// - Returns: duration in seconds, clamped to `MaxDurationSeconds`.
/// - Throws: `DurationParseError.invalid` for unrecognized formats.
func parseDurationSeconds(_ raw: String) throws -> Double {
  let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  if s.hasSuffix("ms"), let v = Double(s.dropLast(2)) { return min(v / 1000.0, MaxDurationSeconds) }
  if s.hasSuffix("s"), let v = Double(s.dropLast(1)) { return min(v, MaxDurationSeconds) }
  if let v = Double(s) { return min(v, MaxDurationSeconds) }
  throw DurationParseError.invalid
}
