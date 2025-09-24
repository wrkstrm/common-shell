import Foundation
import Testing

// Placeholders for Interactive Runner: NDJSON/summary schemas

@Test(
  "ndjson: event order start → stdout/stderr → exit",
  .timeLimit(.minutes(1)),
)
func placeholder_ndjson_event_order() async throws {
  #expect(false, "TODO: capture NDJSON and verify canonical ordering and types")
}

@Test(
  "ndjson: error event emitted on spawn failure",
  .timeLimit(.minutes(1)),
)
func placeholder_ndjson_error_event() async throws {
  #expect(false, "TODO: try spawning a non-existent command; assert ErrorEvent shape")
}

@Test(
  "summary: includes durations, sizes, lines, policyDecision",
  .timeLimit(.minutes(1)),
)
func placeholder_summary_fields() async throws {
  #expect(false, "TODO: parse summary JSON and assert required fields present")
}

@Test(
  "summary: cancelled vs timedOut flags are mutually exclusive",
  .timeLimit(.minutes(1)),
)
func placeholder_summary_flags_exclusive() async throws {
  #expect(false, "TODO: assert exactly one of cancelled/timedOut is true in respective scenarios")
}
