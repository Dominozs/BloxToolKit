# API Reference

## Cooldown

A key-based cooldown manager using `os.clock()` for elapsed-time measurement.

### `Cooldown.new()`

Creates and returns a new cooldown manager.

### `manager:Use(key, duration) -> boolean`

Starts a cooldown if `key` is ready.

- `key`: non-nil table key, commonly a UserId or action name.
- `duration`: non-negative duration in seconds.
- Returns `true` when started, or `false` when a cooldown is already active.

### `manager:IsReady(key) -> boolean`

Returns `true` if no cooldown is active for the key. Expired entries are cleaned lazily when checked.

### `manager:GetRemaining(key) -> number`

Returns the remaining duration in seconds. Returns `0` when ready.

### `manager:Reset(key)`

Removes the cooldown for one key.

### `manager:Clear()`

Removes all cooldown entries.

### `manager:Destroy()`

Clears the manager and marks it as destroyed. Calling other methods after destruction raises an error.
