# Contributing to CommonShell

Thanks for your interest in contributing!

## Development Setup

- Swift toolchain: 6.1
- Platforms: Linux (CI) and macOS (local).
- Build: `swift build -c release`
- Test: `swift test --parallel`

## Coding Guidelines

- Prefer explicit, long-form flags and option names.
- No `Foundation.Process` at call sites; use CommonProcess/CommonShell runners.
- Run `swift format` using the repository configuration when present.
- Keep identifiers descriptive; avoid one-letter variable names.

## Dependencies

- Core: CommonProcess (from 0.2.0)
- Support: WrkstrmLog, WrkstrmFoundation, WrkstrmPerformance
- Argument parsing: Apple Swift Argument Parser

## Opening Issues and PRs

- Include a concise summary and reproduction steps for bugs.
- For features, describe the use case and acceptance criteria.
- Keep PRs focused with clear rationale and tests where applicable.

## License and Conduct

By contributing, you agree that your contributions will be licensed under the
MIT License (see `LICENSE`) and that you will abide by the `CODE_OF_CONDUCT.md`.
