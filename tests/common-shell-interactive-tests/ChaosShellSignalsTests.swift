import Foundation
import Testing

#if canImport(Darwin)
import Darwin
#endif

// Placeholders for chaos-shell signals behavior

@Test(
  "signals: ignore-first-int delays termination until second SIGINT",
  .timeLimit(.minutes(1)),
  .serialized,
)
func placeholder_signals_ignore_first() async throws {
  #expect(
    false,
    "TODO: run with --ignore-first-int, send two SIGINTs; assert first is ignored, second exits 130",
  )
}

@Test(
  "signals: duration run exits normally without signals",
  .timeLimit(.minutes(1)),
  .serialized,
)
func placeholder_signals_duration() async throws {
  #expect(false, "TODO: run with small --duration-seconds and assert exit 0 when not interrupted")
}

@Test(
  "signals: banner suppression works with --no-banner under signals",
  .timeLimit(.minutes(1)),
  .serialized,
)
func placeholder_signals_no_banner() async throws {
  #expect(false, "TODO: verify no banner when --no-banner is present for signals subcommand")
}

@Test(
  "signals: stderr/stdout remain quiet unless signaled",
  .timeLimit(.minutes(1)),
  .serialized,
)
func placeholder_signals_quiet_output() async throws {
  #expect(false, "TODO: assert no stray output during idle signal wait")
}
