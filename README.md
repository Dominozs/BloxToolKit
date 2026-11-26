# RbxToolkit

[![CI](https://github.com/Dominozs/BloxToolKit/actions/workflows/ci.yml/badge.svg)](https://github.com/Dominozs/BloxToolKit/actions/workflows/ci.yml)

A lightweight, modular, open-source Luau utility library designed to simplify Roblox game development.

RbxToolkit provides reusable developer tools and well-documented modules to help developers build maintainable Roblox experiences.

## Goals

- Reduce repetitive development work.
- Provide reusable, modular Luau utilities.
- Improve code organization and maintainability.
- Encourage open-source collaboration.
- Support developers of all experience levels.

## Modules

| Module | Description | Status |
|---|---|---|
| `Cooldown` | Key-based cooldown management | Available |
| `Signal` | Custom event/signal implementation | Available |
| `Cleaner` | Cleanup utility for connections, instances, threads and functions | Available |
| `RateLimiter` | Keyed token-bucket rate limiter | Available |
| `DataStoreHelper` | DataStore wrapper with retries and normalized results | Available |
| `Net` | Server-authoritative RemoteEvent/RemoteFunction wrapper with validation | Available |

## Installation

### Release / Download

The pre-built `.rbxm` is attached to every GitHub release (tagged `v*`):
[Latest release on GitHub](https://github.com/Dominozs/BloxToolKit/releases/latest).

To use it, download `RbxToolkit.rbxm` from the release, then drag it into the Roblox Studio Explorer under `ReplicatedStorage`. It contains one `Folder` named `RbxToolkit` with every module inside (as `ModuleScript`s), so you can `require(game.ReplicatedStorage.RbxToolkit.<Module>)`.

Alternatively, copy the files from `src/` into your project by hand (for example, under `ReplicatedStorage/RbxToolkit`) and require them:

```lua
local Cooldown = require(game.ReplicatedStorage.RbxToolkit.Cooldown)
local cooldown = Cooldown.new()

if cooldown:Use(player.UserId, 5) then
    print("Action allowed")
else
    print(("Try again in %.2f seconds"):format(
        cooldown:GetRemaining(player.UserId)
    ))
end
```

Each module is standalone - copy only what you use.

## API Reference

See [`docs/API.md`](docs/API.md) for full documentation on every module.

## Examples

- [`examples/CooldownExample.server.luau`](examples/CooldownExample.server.luau)
- [`examples/SignalExample.server.luau`](examples/SignalExample.server.luau)
- [`examples/CleanerExample.server.luau`](examples/CleanerExample.server.luau)
- [`examples/RateLimiterExample.server.luau`](examples/RateLimiterExample.server.luau)
- [`examples/DataStoreHelperExample.server.luau`](examples/DataStoreHelperExample.server.luau)
- [`examples/NetExample.server.luau`](examples/NetExample.server.luau)

## Testing

Tests run headlessly with [Lune](https://github.com/lune-org/lune) - no Studio needed:

```sh
lune run tests/run.luau
```

The spec files in `tests/` are written for [TestEZ](https://github.com/Roblox/testez) and run unmodified inside Studio too: place `tests/` under your test hierarchy and run discovery there.

## Development

Tools are pinned in `rokit.toml`. With [rokit](https://github.com/rojo-rbx/rokit) installed:

```sh
rokit install   # installs lune, selene, stylua, luau-lsp and rojo at the pinned versions
selene src tests examples
stylua --check src tests examples
lune run tests/run.luau
lune run tests/run_roblox_runtime.luau   # re-runs with a Roblox-flavoured typeof
```

For an optional local type check, download the Roblox definitions once, then:

```sh
curl -fsSL -o roblox.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.d.luau
luau-lsp analyze --definitions=roblox.d.luau src
```

CI runs lint, format check, type check and tests on every push and pull request.

## Contributing

Contributions, bug reports, and suggestions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## License

MIT. See [LICENSE](LICENSE).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
