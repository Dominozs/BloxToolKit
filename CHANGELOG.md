# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.1.0]

### Added

- `Cooldown` — key-based cooldown manager with an optional injectable clock.
- `Signal` — dependency-free event implementation with error isolation.
- `Cleaner` — mixed cleanup utility for functions, threads, instances and tables.
- `RateLimiter` — keyed token-bucket rate limiter with lazy refill.
- `DataStoreHelper` — DataStore wrapper returning `success, result, err` with exponential-backoff retries.
- Headless test runner (`lune run tests/run.luau`) and TestEZ-compatible specs.
- CI workflow: lint, format check, type check and tests.
- Toolchain pinned through `rokit.toml`.

### Changed

- `Cooldown.new(clock?)` accepts an optional clock for deterministic tests.
- `Cleaner.new(options?)` accepts `onError`; `Clean()` now reports item failures through it instead of throwing, so `Clean()` is safe to call from event handlers.

### Fixed

- Fixed the TestEZ link in the README.
