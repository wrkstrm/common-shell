# `CommonShellArguments`

Shared ArgumentParser helpers for CLIs that use CommonShell.

## Overview

- ``CommonShellArguments``: `--working-directory`, `--outputs[]`, `--verbose`
- ``CommonShellParsableArguments``: protocol providing `configuredShell()`
- Install/uninstall helpers: `Install` and `Uninstall`

## Usage

```swift
import ArgumentParser
import CommonShellArguments

struct MyCLI: AsyncParsableCommand, CommonShellParsableArguments {
  @OptionGroup var common: CommonShellArguments

  mutating func run() throws {
    let shell = try configuredShell()
    let out = try await shell.run(
      host: .shell(options: []),
      identity: .path("/bin/sh"),
      args: ["echo hello"]
    )  // via shell wrapper
    print(out)
  }
}
```
