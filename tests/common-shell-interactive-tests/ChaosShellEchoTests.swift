import Foundation
import Testing

// Placeholders covering chaos-shell echo behaviors

@Test(
  "echo: jitter + seed yields deterministic cadence",
  .timeLimit(.minutes(1)),
  .serialized,
)
func placeholder_echo_jitter_seed() async throws {
  #expect(
    false, "TODO: run with --sleep-seconds and --jitter-seconds + --seed, assert timestamps order",
  )
}

@Test(
  "echo: stderr mixing via --stderr-every",
  .timeLimit(.minutes(1)),
  .serialized,
)
func placeholder_echo_stderr_mixing() async throws {
  #expect(false, "TODO: assert stderr receives every Nth line and stdout remains intact")
}

@Test(
  "echo: bytes-per-line produces exact payload sizes",
  .timeLimit(.minutes(1)),
  .serialized,
)
func placeholder_echo_bytes_per_line() async throws {
  #expect(false, "TODO: measure output line lengths (sans prefix) across several sizes")
}

@Test(
  "echo: random early-exit obeys probability bounds and seed",
  .timeLimit(.minutes(1)),
  .serialized,
)
func placeholder_echo_random_early_exit() async throws {
  #expect(
    false,
    "TODO: use --random-early-exit --exit-probability with --seed; assert <= limit and stable with same seed",
  )
}

@Test(
  "echo: non-zero --exit-status is propagated",
  .timeLimit(.minutes(1)),
  .serialized,
)
func placeholder_echo_exit_status() async throws {
  #expect(false, "TODO: set --exit-status 7 and assert process exit code 7")
}
