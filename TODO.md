# TODO — CommonShell improvements

### Typed host options
<!-- id:common-shell-typed-host-options owner:platform-tooling priority:P2 labels:common-shell,api,status:planned epic:exec-layer estimate:4x7.5m -->
- Replace raw `[String]` options for `.shell/.env/.npm/.npx` with typed enums/option sets.
- Add documentation and examples; migrate internal call sites.

### Timeout & cancellation
<!-- id:common-shell-timeout-cancel owner:platform-tooling priority:P1 labels:common-shell,api,status:in-progress epic:exec-layer estimate:3x7.5m -->
- Add `timeout:` parameter to run APIs; guarantee cooperative cancellation semantics.
- Surface `timedOut/cancelled` flags in structured results where appropriate.
