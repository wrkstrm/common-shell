# What’s New (API simplification)

A quick note on the simplified CommonShell API.

## Highlights

- One entry for wrapper selection per call: `run(host:identity:args:)`.
- Prefer `ExecutableReference` (`.name`, `.path`, `.none`) for identity.
- Keep wrapper policy explicit via `ExecutionHostKind` (`.direct`, `.shell`, `.env`, `.npx`, `.npm`).

## Examples

```swift
import CommonShell
import CommonProcessExecutionKit

let sh = CommonShell(executable: .path("/usr/bin/env"))

// Direct by path (override just for this call)
let a = try await sh.run(host: .direct, identity: .path("/bin/echo"), args: ["hello"])

// Shell via /bin/sh -c
let b = try await sh.run(host: .shell(options: []), identity: .path("/bin/sh"), args: ["echo hi"])

// Env via /usr/bin/env <name>
let c = try await sh.run(host: .env(options: []), identity: .name("echo"), args: ["ok"])
```

## Notes

- The previous helpers (`runShell`, `runEnv`, `runDirect`, `runRaw`) were removed in favor of a single, clearer API.
- Low‑level variants remain for advanced control:
  - ``run(host:executable:arguments:environment:runnerKind:)``
  - ``run(reference: ...)`` and `withExec(reference: ...)`.
