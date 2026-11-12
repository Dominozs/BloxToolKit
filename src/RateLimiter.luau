--!strict
--[[
	RbxToolkit - RateLimiter
	A token-bucket rate limiter, keyed so one instance can serve many callers.

	Buckets refill lazily: no timers, no loops, no per-key bookkeeping beyond the
	bucket itself. Refill is computed from `os.clock()` when a key is accessed.

	Example:
		local RateLimiter = require(path.To.RateLimiter)
		local limiter = RateLimiter.new(5, 10) -- 5 per second, bursts of 10

		if limiter:Consume(player.UserId) then
			handleRequest(player)
		else
			warn(("retry in %.2fs"):format(limiter:GetRetryTime(player.UserId)))
		end
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = {
	Consume: (self: RateLimiter, key: any, cost: number?) -> boolean,
	Peek: (self: RateLimiter, key: any) -> number,
	GetRetryTime: (self: RateLimiter, key: any, cost: number?) -> number,
	Reset: (self: RateLimiter, key: any) -> (),
	Clear: (self: RateLimiter) -> (),
	IsDestroyed: (self: RateLimiter) -> boolean,
	Destroy: (self: RateLimiter) -> (),
}

type Bucket = {
	tokens: number,
	updatedAt: number,
}

local function assertAlive(self: any)
	assert(not self.__destroyed, "RateLimiter has been destroyed")
end

-- `ratePerSecond` is the sustained refill rate. `burstSize` is the bucket
-- capacity and defaults to the refill rate, or 1 when the rate is below 1.
-- `clock` is an optional monotonic time source (seconds); tests pass a fake one.
function RateLimiter.new(ratePerSecond: number, burstSize: number?, clock: (() -> number)?): RateLimiter
	assert(typeof(ratePerSecond) == "number" and ratePerSecond > 0, "ratePerSecond must be a positive number")

	local burst = burstSize or math.max(1, ratePerSecond)
	assert(typeof(burst) == "number" and burst > 0, "burstSize must be a positive number")
	assert(clock == nil or typeof(clock) == "function", "clock must be a function")

	return (
		setmetatable({
			__rate = ratePerSecond,
			__burst = burst,
			__buckets = {} :: { [any]: Bucket },
			__clock = clock or os.clock,
			__destroyed = false,
		}, RateLimiter) :: any
	) :: RateLimiter
end

local function refill(self: any, key: any): Bucket
	local now = self.__clock()
	local bucket = self.__buckets[key]

	if bucket == nil then
		bucket = {
			tokens = self.__burst,
			updatedAt = now,
		}
		self.__buckets[key] = bucket
		return bucket
	end

	local elapsed = now - bucket.updatedAt
	if elapsed > 0 then
		bucket.tokens = math.min(self.__burst, bucket.tokens + elapsed * self.__rate)
		bucket.updatedAt = now
	end

	return bucket
end

-- Spends `cost` tokens (default 1). Returns whether the spend succeeded.
function RateLimiter:Consume(key: any, cost: number?): boolean
	assertAlive(self)
	assert(key ~= nil, "key cannot be nil")

	local amount = cost or 1
	assert(typeof(amount) == "number" and amount > 0, "cost must be a positive number")

	local bucket = refill(self, key)
	if bucket.tokens < amount then
		return false
	end

	bucket.tokens -= amount
	return true
end

-- Returns how many tokens are available right now.
function RateLimiter:Peek(key: any): number
	assertAlive(self)
	assert(key ~= nil, "key cannot be nil")

	return refill(self, key).tokens
end

-- Returns how long until `cost` tokens (default 1) are available. Returns 0 when ready.
function RateLimiter:GetRetryTime(key: any, cost: number?): number
	assertAlive(self)
	assert(key ~= nil, "key cannot be nil")

	local amount = cost or 1
	assert(typeof(amount) == "number" and amount > 0, "cost must be a positive number")

	if amount > self.__burst then
		return math.huge
	end

	local bucket = refill(self, key)
	if bucket.tokens >= amount then
		return 0
	end

	return (amount - bucket.tokens) / self.__rate
end

-- Refills one key back to a full bucket.
function RateLimiter:Reset(key: any)
	assertAlive(self)
	assert(key ~= nil, "key cannot be nil")

	self.__buckets[key] = nil
end

-- Drops every key's bucket.
function RateLimiter:Clear()
	assertAlive(self)
	table.clear(self.__buckets)
end

function RateLimiter:IsDestroyed(): boolean
	return self.__destroyed
end

-- Clears every bucket and prevents further use.
function RateLimiter:Destroy()
	if self.__destroyed then
		return
	end

	table.clear(self.__buckets)
	self.__destroyed = true
end

return RateLimiter
