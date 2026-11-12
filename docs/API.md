# API Reference

All modules are standalone and follow the same conventions:

- Constructors are `Module.new()`; methods are called with `:`.
- Managers that hold state expose `IsDestroyed()` and `Destroy()`. Methods on a destroyed manager raise an error.
- Validation happens eagerly: bad arguments raise immediately with a descriptive message.

## Cooldown

A key-based cooldown manager using a monotonic clock for elapsed-time measurement.

### `Cooldown.new(clock?)`

Creates and returns a new cooldown manager.

- `clock`: optional function returning monotonic seconds. Defaults to `os.clock()`. Pass a fake clock in tests to avoid waiting.

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

### `manager:Sweep() -> number`

Drops entries whose cooldown has already expired. Entries are otherwise only removed when checked, so keys that are never checked again stay in the table. Call this periodically when keys come and go (for example every few minutes). Returns how many entries were dropped.

### `manager:GetCount() -> number`

Returns how many keys currently hold an entry, expired or not.

### `manager:Destroy()`

Clears the manager and marks it as destroyed. Calling other methods after destruction raises an error.

## Signal

A dependency-free event implementation. Handlers are plain functions called through `pcall`, so a failing handler cannot stop the others - the error is reported through `warn` instead.

### `Signal.new()`

Creates and returns a new signal.

### `signal:Connect(callback) -> connection`

Registers a handler that runs every time the signal fires. Returns a connection object with:

- `connection.Connected` - boolean.
- `connection:Disconnect()` - detaches the handler. Calling it twice is a no-op.

### `signal:Once(callback) -> connection`

Registers a handler that disconnects itself right before it first runs.

### `signal:Fire(...)`

Calls every connected handler with the given arguments, in the order they connected. Details:

- Handlers disconnected earlier in the same `Fire` are skipped.
- Handlers connected during the same `Fire` are not called until the next one.
- Nested `Fire` calls are allowed.
- A failing handler is reported through `warn`; the remaining handlers still run.

### `signal:GetConnectionCount() -> number`

Returns how many handlers are currently connected.

### `signal:DisconnectAll()`

Detaches every handler. The signal stays usable.

### `signal:IsDestroyed() -> boolean`

Returns whether the signal has been destroyed.

### `signal:Destroy()`

Disconnects everything and marks the signal destroyed. `Connect`, `Once` and `Fire` raise afterwards.

Note: there is intentionally no `Wait()` - use `Connect` with your own coroutine if you need to yield.

## Cleaner

A single place to release everything a piece of code created. Items are cleaned in reverse order of addition (last added, first cleaned), which keeps teardown order natural.

Supported items:

| Item | Cleaned by |
|---|---|
| function | called |
| thread | `coroutine.close` |
| Instance | `:Destroy()` |
| table with `Disconnect` | `:Disconnect()` |
| table with `Destroy` | `:Destroy()` |

### `Cleaner.new(options?)`

Creates and returns a new cleaner.

`options.onError` (optional) receives one message per failing item during `Clean()`. It defaults to `warn`, because `Clean()` is usually called from a Roblox event handler where a thrown error would be silently swallowed. Pass a function that raises if you want failures to propagate.

### `cleaner:Add(item)`

Adds one item. Items can be added at any time.

### `cleaner:AddMany(items)`

Adds several items from a table.

### `cleaner:Remove(item) -> boolean`

Removes an item without cleaning it. Returns whether it was found.

### `cleaner:Clean()`

Cleans every item in reverse order and empties the cleaner. The cleaner stays usable. If an item fails, remaining items are still cleaned and the failure is reported through `onError` instead of stopping the caller.

### `cleaner:GetCount() -> number`

Returns how many items are waiting to be cleaned.

### `cleaner:IsDestroyed() -> boolean`

Returns whether the cleaner has been destroyed.

### `cleaner:Destroy()`

Cleans everything and marks the cleaner destroyed. `Add` raises afterwards.

## RateLimiter

A keyed token-bucket rate limiter. One instance serves many callers (one key per player, per endpoint, per anything). Buckets refill lazily from the clock - no timers, no loops.

### `RateLimiter.new(ratePerSecond, burstSize?, clock?)`

Creates and returns a new rate limiter.

- `ratePerSecond`: sustained refill rate. Must be positive.
- `burstSize`: bucket capacity. Defaults to `ratePerSecond`, or `1` when the rate is below `1`.
- `clock`: optional function returning monotonic seconds; defaults to `os.clock()`. Pass a fake clock in tests.

### `limiter:Consume(key, cost?) -> boolean`

Spends `cost` tokens (default `1`) from the key's bucket, refilling it first. Returns whether the spend succeeded.

### `limiter:Peek(key) -> number`

Returns how many tokens are available right now.

### `limiter:GetRetryTime(key, cost?) -> number`

Returns how many seconds until `cost` tokens (default `1`) become available. Returns `0` when ready and `math.huge` when `cost` exceeds the burst size.

### `limiter:Reset(key)`

Refills one key's bucket to full.

### `limiter:Clear()`

Drops every key's bucket.

### `limiter:Sweep() -> number`

Drops buckets that are full, bounding memory when keys come and go. A full bucket is exactly what a fresh key starts with, so sweeping it cannot change behaviour. Call this periodically when keys are short-lived. Returns how many buckets were dropped.

### `limiter:GetCount() -> number`

Returns how many keys currently hold a bucket.

### `limiter:IsDestroyed() -> boolean`

Returns whether the limiter has been destroyed.

### `limiter:Destroy()`

Clears every bucket and marks the limiter destroyed.

## DataStoreHelper

Wraps a DataStore so call sites stop repeating retry boilerplate. Every method returns `success, result, err` instead of throwing, and retries use exponential backoff with jitter.

### `DataStoreHelper.new(store, options?)`

Creates a wrapper around a Roblox `DataStore` (or anything duck-typed to it).

`options` (all optional):

| Option | Default | Meaning |
|---|---|---|
| `attempts` | `4` | Total tries, including the first. Minimum 1. |
| `baseDelay` | `0.5` | First backoff, in seconds. |
| `maxDelay` | `8` | Backoff ceiling, in seconds. |
| `jitter` | `0.25` | Fraction of random delay added on top. |
| `logger` | `warn` | Called with the final failure message. |
| `wait` | `task.wait` | Sleep function between retries. |
| `isRetryable` | built-in | `(err) -> boolean`; see below. |

The default retryability rule never retries errors mentioning "not found", "does not exist", "not been set" or "invalid key" (case-insensitive) - retrying a missing key only adds latency. Everything else is retried until attempts run out.

### `helper:Get(key, default?) -> (boolean, any?, string?)`

Reads a key. On failure with a `default` provided, returns `false, default, err`.

### `helper:GetOrDefault(key, default) -> any`

Reads a key and always returns a value, falling back to `default`.

### `helper:Set(key, value) -> (boolean, nil, string?)`

Writes a key, overwriting whatever was there.

### `helper:Update(key, transform) -> (boolean, any?, string?)`

Atomically replaces the key with the result of `transform(currentValue)`.

### `helper:Remove(key) -> (boolean, nil, string?)`

Deletes a key.

### `helper:Increment(key, delta) -> (boolean, number?, string?)`

Adds `delta` to a numeric key and returns the new value.

### `helper:IsDestroyed() -> boolean`

Returns whether the helper has been destroyed.

### `helper:Destroy()`

Marks the helper destroyed. Other methods raise afterwards.

Note: the wrapper does not manage DataStore budgets. Retries wait between attempts, which naturally reduces budget pressure, but heavy call sites should still batch reads.
