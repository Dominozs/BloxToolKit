# RbxToolkit

A lightweight, modular, open-source Luau utility library designed to simplify Roblox game development.

RbxToolkit provides reusable developer tools and well-documented modules to help developers build maintainable Roblox experiences.

## Goals

- Reduce repetitive development work.
- Provide reusable, modular Luau utilities.
- Improve code organization and maintainability.
- Encourage open-source collaboration.
- Support developers of all experience levels.

## Current status

This repository is an early MVP. The first module is `Cooldown`.

## Modules

| Module | Description | Status |
|---|---|---|
| `Cooldown` | Key-based cooldown management | Available |
| `Signal` | Custom event/signal implementation | Planned |
| `Cleaner` | Cleanup utility for connections and instances | Planned |
| `RateLimiter` | Request rate-limiting helper | Planned |
| `DataStoreHelper` | DataStore retry and error-handling helpers | Planned |

## Installation

Copy `src/Cooldown.luau` into your Roblox project (for example, under `ReplicatedStorage/RbxToolkit`) and require it:

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

## Cooldown API

- `Cooldown.new()` — Creates a cooldown manager.
- `:Use(key, duration)` — Returns `true` and starts a cooldown if ready; otherwise returns `false`.
- `:IsReady(key)` — Returns whether the key is ready.
- `:GetRemaining(key)` — Returns remaining seconds, or `0` if ready.
- `:Reset(key)` — Removes one key's cooldown.
- `:Clear()` — Removes all cooldowns.
- `:Destroy()` — Clears and destroys the manager. Further calls raise an error.

`key` can be a string, number, or another table key. `duration` must be a non-negative number.

## Example

See [`examples/CooldownExample.server.luau`](examples/CooldownExample.server.luau).

## Testing

The test file in `tests/Cooldown.spec.luau` is written for TestEZ-style test discovery. Add it to your TestEZ test hierarchy to run it.

## Roadmap

- [ ] Add Signal module
- [ ] Add Cleaner module
- [ ] Add RateLimiter module
- [ ] Add automated tests in CI
- [ ] Publish expanded API documentation

## Contributing

Contributions, bug reports, and suggestions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## License

MIT. See [LICENSE](LICENSE).
