--!strict
--[[
	RbxToolkit - DataStoreHelper
	Wraps a DataStore so call sites stop repeating the same retry boilerplate.

	Every method returns `success, result, err` instead of throwing. Retries use
	exponential backoff with jitter, so a large rollback or a throttled call does
	not turn into a tight retry loop.

	`GetAsync` failures caused by a missing key are not retried: retrying a key
	that was never written only adds latency.

	Example:
		local DataStoreHelper = require(path.To.DataStoreHelper)
		local coins = DataStoreHelper.new(DataStoreService:GetDataStore("Coins"))

		local ok, value, err = coins:Get(player.UserId)
		if not ok then
			warn(("could not load coins: %s"):format(err))
			return
		end

		coins:Increment(player.UserId, 10)
]]

local DataStoreHelper = {}
DataStoreHelper.__index = DataStoreHelper

export type Options = {
	attempts: number?,
	baseDelay: number?,
	maxDelay: number?,
	jitter: number?,
	logger: ((message: string) -> ())?,
	wait: ((seconds: number) -> ())?,
	isRetryable: ((err: string) -> boolean)?,
}

export type DataStoreHelper = {
	Get: (self: DataStoreHelper, key: string, default: any?) -> (boolean, any?, string?),
	GetExisting: (self: DataStoreHelper, key: string, default: any) -> (boolean, any, string?),
	GetOrDefault: (self: DataStoreHelper, key: string, default: any) -> any,
	Set: (self: DataStoreHelper, key: string, value: any) -> (boolean, nil, string?),
	Update: (self: DataStoreHelper, key: string, transform: (any) -> any) -> (boolean, any?, string?),
	Remove: (self: DataStoreHelper, key: string) -> (boolean, nil, string?),
	Increment: (self: DataStoreHelper, key: string, delta: number) -> (boolean, number?, string?),
	IsDestroyed: (self: DataStoreHelper) -> boolean,
	Destroy: (self: DataStoreHelper) -> (),
}

local DEFAULT_ATTEMPTS = 4
local DEFAULT_BASE_DELAY = 0.5
local DEFAULT_MAX_DELAY = 8
local DEFAULT_JITTER = 0.25

-- A missing key means `GetAsync` threw; retrying it cannot succeed. Patterns are
-- matched case-insensitively and kept specific: a broad "not found" substring
-- would misclassify unrelated errors as non-retryable.
local NOT_RETRYABLE_PATTERNS = {
	"key not found",
	"was not found",
	"does not exist",
	"has not been set",
	"invalid key",
	"not a valid key",
}

local function defaultLogger(message: string)
	warn(message)
end

local function defaultWait(seconds: number)
	if task and task.wait then
		return task.wait(seconds)
	end

	return seconds
end

local function defaultIsRetryable(err: string): boolean
	local lower = string.lower(err)
	for _, pattern in NOT_RETRYABLE_PATTERNS do
		if string.find(lower, pattern, 1, true) then
			return false
		end
	end

	return true
end

local function assertAlive(self: any)
	assert(not self.__destroyed, "DataStoreHelper has been destroyed")
end

function DataStoreHelper.new(store: any, options: Options?): DataStoreHelper
	-- Roblox DataStores are Instances, so `typeof(store)` is "Instance"; a plain
	-- table is accepted for tests and alternative backends with the same methods.
	local kind = typeof(store)
	assert(kind == "Instance" or kind == "table", "store must be a DataStore instance")

	for _, method in { "GetAsync", "SetAsync", "UpdateAsync", "RemoveAsync", "IncrementAsync" } do
		assert(typeof(store[method]) == "function", ("store is missing %s"):format(method))
	end

	local config: Options = options or {}
	local attempts = config.attempts or DEFAULT_ATTEMPTS
	local baseDelay = config.baseDelay or DEFAULT_BASE_DELAY
	local maxDelay = config.maxDelay or DEFAULT_MAX_DELAY
	local jitter = config.jitter or DEFAULT_JITTER

	assert(typeof(attempts) == "number" and attempts >= 1, "attempts must be at least 1")
	assert(typeof(baseDelay) == "number" and baseDelay >= 0, "baseDelay cannot be negative")
	assert(typeof(maxDelay) == "number" and maxDelay >= 0, "maxDelay cannot be negative")
	assert(typeof(jitter) == "number" and jitter >= 0, "jitter cannot be negative")

	return (
		setmetatable({
			__store = store,
			__attempts = attempts,
			__baseDelay = baseDelay,
			__maxDelay = maxDelay,
			__jitter = jitter,
			__logger = config.logger or defaultLogger,
			__wait = config.wait or defaultWait,
			__isRetryable = config.isRetryable or defaultIsRetryable,
			__destroyed = false,
		}, DataStoreHelper) :: any
	) :: DataStoreHelper
end

-- Runs `operation` with retries. Returns `success, result, err`.
function DataStoreHelper:_retry(operation: () -> any): (boolean, any?, string?)
	assertAlive(self)

	local lastError = "unknown error"

	for attempt = 1, self.__attempts do
		local ok, result = pcall(operation)
		if ok then
			return true, result, nil
		end

		lastError = tostring(result)

		if attempt == self.__attempts or not self.__isRetryable(lastError) then
			break
		end

		local delay = math.min(self.__maxDelay, self.__baseDelay * 2 ^ (attempt - 1))
		delay = delay * (1 + math.random() * self.__jitter)
		self.__wait(delay)
	end

	self.__logger(("DataStore operation failed: %s"):format(lastError))
	return false, nil, lastError
end

-- Reads a key. On failure, returns `default` as the result when one is given.
function DataStoreHelper:Get(key: string, default: any?): (boolean, any?, string?)
	assertAlive(self)
	assert(typeof(key) == "string" and key ~= "", "key must be a non-empty string")

	local ok, result, err = self:_retry(function()
		return self.__store:GetAsync(key)
	end)

	if not ok and default ~= nil then
		return false, default, err
	end

	return ok, result, err
end

-- Reads a key, treating "key does not exist" as a normal outcome rather than a
-- failure: returns `true, default` in that case, so callers do not have to
-- distinguish a first-time player from a DataStore outage.
--
-- Only misses are normalised. Real errors (budget, network, throttling) still
-- return `false, default, err` after retries.
function DataStoreHelper:GetExisting(key: string, default: any): (boolean, any, string?)
	assertAlive(self)
	assert(typeof(key) == "string" and key ~= "", "key must be a non-empty string")

	local ok, result, err = self:_retry(function()
		return self.__store:GetAsync(key)
	end)

	if ok then
		if result == nil then
			return true, default, nil
		end

		return true, result, nil
	end

	if not self.__isRetryable(err or "") then
		return true, default, nil
	end

	return false, default, err
end

-- Reads a key and always returns a value, falling back to `default`.
function DataStoreHelper:GetOrDefault(key: string, default: any): any
	local ok, result = self:Get(key, default)
	if not ok then
		return default
	end

	return result
end

-- Writes a key, overwriting whatever was there.
function DataStoreHelper:Set(key: string, value: any): (boolean, nil, string?)
	assertAlive(self)
	assert(typeof(key) == "string" and key ~= "", "key must be a non-empty string")

	local ok, _, err = self:_retry(function()
		return self.__store:SetAsync(key, value)
	end)

	return ok, nil, err
end

-- Atomically replaces a key with the result of `transform`.
function DataStoreHelper:Update(key: string, transform: (any) -> any): (boolean, any?, string?)
	assertAlive(self)
	assert(typeof(key) == "string" and key ~= "", "key must be a non-empty string")
	assert(typeof(transform) == "function", "transform must be a function")

	return self:_retry(function()
		return self.__store:UpdateAsync(key, transform)
	end)
end

-- Deletes a key.
function DataStoreHelper:Remove(key: string): (boolean, nil, string?)
	assertAlive(self)
	assert(typeof(key) == "string" and key ~= "", "key must be a non-empty string")

	local ok, _, err = self:_retry(function()
		return self.__store:RemoveAsync(key)
	end)

	return ok, nil, err
end

-- Adds `delta` to a numeric key and returns the new value.
function DataStoreHelper:Increment(key: string, delta: number): (boolean, number?, string?)
	assertAlive(self)
	assert(typeof(key) == "string" and key ~= "", "key must be a non-empty string")
	assert(typeof(delta) == "number", "delta must be a number")

	local ok, result, err = self:_retry(function()
		return self.__store:IncrementAsync(key, delta)
	end)

	return ok, result, err
end

function DataStoreHelper:IsDestroyed(): boolean
	return self.__destroyed
end

-- Prevents further use.
function DataStoreHelper:Destroy()
	self.__destroyed = true
end

return DataStoreHelper
