import Foundation
import Testing

// Placeholders for Interactive Runner: preview + policy behaviors

@Test(
  "policy: deny destructive by default (e.g., rm -rf /)",
  .timeLimit(.minutes(1)),
)
func placeholder_policy_default_deny() async throws {
  #expect(
    false, "TODO: simulate policy evaluation denying destructive commands, assert structured error",
  )
}

@Test(
  "policy: allow-list overrules deny when configured",
  .timeLimit(.minutes(1)),
)
func placeholder_policy_allow_overrides() async throws {
  #expect(false, "TODO: configure allow for specific path, verify decision")
}

@Test(
  "policy: wrapper selection defaults to .direct; shell opt-in",
  .timeLimit(.minutes(1)),
)
func placeholder_policy_wrapper_default() async throws {
  #expect(false, "TODO: verify preview shows wrapper=.direct unless --shell provided")
}

@Test(
  "preview: shows exec/args/cwd/env delta/timeout",
  .timeLimit(.minutes(1)),
)
func placeholder_preview_renders_all_fields() async throws {
  #expect(false, "TODO: assert preview includes all expected sections and redactions")
}

@Test(
  "preview: customizable prompt callback and default [y/N]",
  .timeLimit(.minutes(1)),
)
func placeholder_preview_confirm_flow() async throws {
  #expect(false, "TODO: simulate confirm=yes/no and verify run or cancellation path")
}
