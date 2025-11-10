import Foundation
import Testing

// Placeholders for REPL overlay (history, completion, registry)

@Test(
  "repl: line editor supports history and completion",
  .timeLimit(.minutes(2)),
)
func placeholder_repl_history_completion() async throws {
  #expect(false, "TODO: simulate a session with up/down and tab completion via a test shim")
}

@Test(
  "repl: Ctrl-C cancels running command and returns to prompt",
  .timeLimit(.minutes(2)),
)
func placeholder_repl_ctrlc_behavior() async throws {
  #expect(false, "TODO: forward SIGINT to child; REPL stays alive and shows prompt")
}

@Test(
  "repl: registry provides discoverable commands and help",
  .timeLimit(.minutes(1)),
)
func placeholder_repl_registry_help() async throws {
  #expect(false, "TODO: assert command listing/help content from registry")
}

@Test(
  "repl: prompt shows current context (cwd)",
  .timeLimit(.minutes(1)),
)
func placeholder_repl_prompt_context() async throws {
  #expect(false, "TODO: display cwd in prompt and update after cd-like command")
}
