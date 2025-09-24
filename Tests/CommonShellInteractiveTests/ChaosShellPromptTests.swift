import Foundation
import Testing

// Placeholders covering chaos-shell prompt behaviors

@Test(
  "prompt reprompts on invalid input, then accepts yes",
  .timeLimit(.minutes(1)),
  .serialized,
)
func placeholder_prompt_reprompt_then_yes() async throws {
  #expect(false, "TODO: feed invalid input then 'y' and assert exit 0 + reprompt count")
}

@Test(
  "prompt respects --exact-match for case-sensitive inputs",
  .timeLimit(.minutes(1)),
  .serialized,
)
func placeholder_prompt_exact_match() async throws {
  #expect(false, "TODO: with --exact-match, 'Y' should not match 'y' unless included")
}

@Test(
  "prompt supports custom --accept-yes/--accept-no lists",
  .timeLimit(.minutes(1)),
  .serialized,
)
func placeholder_prompt_custom_lists() async throws {
  #expect(false, "TODO: supply custom accept lists and verify matching + exit codes")
}

@Test(
  "prompt: EOF exits 1 without accepting input",
  .timeLimit(.minutes(1)),
  .serialized,
)
func placeholder_prompt_eof() async throws {
  #expect(false, "TODO: close stdin and assert exit 1 with no output")
}

@Test(
  "prompt: --exit-status-on-no applies to negative responses",
  .timeLimit(.minutes(1)),
  .serialized,
)
func placeholder_prompt_exit_status_on_no() async throws {
  #expect(false, "TODO: pass --exit-status-on-no 42; send 'n' and assert exit 42")
}
