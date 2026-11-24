# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `Net` — server-authoritative `RemoteEvent`/`RemoteFunction` wrapper with optional `validate`/`onReject` hooks, `(ok, result, err)` return convention for invokes, and connection tracking on `Destroy`.
- `Signal:Wait()` — yields the current coroutine until the signal fires once, without requiring a scheduler.
- `DataStoreHelper:GetExisting(key, default)` — treats a missing key as a normal outcome (`true, default, nil`) instead of a failure.
- `tests/run_roblox_runtime.luau` — second test runner that executes modules with a Roblox-flavoured `typeof`, so engine-specific branches are covered headlessly.
- Release workflow (`.github/workflows/release.yml`) building `RbxToolkit.rbxm` on `v*` tags via `build.project.json`.
- `rojo` pinned in `rokit.toml`.

### Changed

- `DataStoreHelper` retryability now matches a fixed list of missing-key phrases, so unrelated errors are not misclassified as non-retryable.

### Fixed

- `Cleaner` now recognises `RBXScriptConnection` (previously `typeof(item) == "Instance"` never matched a connection, so cleaning one raised instead of disconnecting).
- `DataStoreHelper.new` now accepts a real `DataStore` instance (`typeof` is `"Instance"`, not `"table"`); the constructor previously asserted on every real store.

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
