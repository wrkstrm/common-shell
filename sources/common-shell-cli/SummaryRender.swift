import Foundation

/// Renders a compact summary line for duration-based benchmarks.
func renderSummary(iterations: Int, totalMS: Double, averageMS: Double) -> String {
  "iterations=\(iterations) total_ms=\(String(format: "%.1f", totalMS)) avg_ms=\(String(format: "%.1f", averageMS))"
}
