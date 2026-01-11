# CommonShellPerf

Opt‑in perf helpers for CommonShell that delegate to WrkstrmPerformance. The helpers now live inside
the CommonShell package as a separate library product so callers can link them without pulling the
extra dependency into the core target.

## Add Dependency

In a package that already depends on `CommonShell`:

```swift
// Package.swift
.package(name: "CommonShell", path: "../common-shell"),

// Target dependencies
.product(name: "CommonShellPerf", package: "CommonShell"),
```

## Usage

```swift
import CommonShell
import CommonShellPerf
import CommonProcess

let shell = CommonShell(executable: .path("/usr/bin/env"))

// Duration mode
let a = try await shell.perfForInterval(
  host: .env(options: []), executable: .name("echo"), arguments: ["bench"],
  durationSeconds: 0.25, targetHz: 144
)
print(a.iterations, a.averageMS)

// Fixed iterations
let b = try await shell.perfIterations(
  host: .direct, executable: .path("/bin/echo"), arguments: ["bench"], iterations: 100
)
print(b.iterations, b.totalMS)
```
