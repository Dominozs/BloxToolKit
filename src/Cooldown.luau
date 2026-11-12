--!strict
--[[
    RbxToolkit - Cooldown
    A small key-based cooldown manager.

    Example:
        local Cooldown = require(path.To.Cooldown)
        local cooldown = Cooldown.new()

        if cooldown:Use(player.UserId, 5) then
            print("Allowed")
        end
]]

local Cooldown = {}
Cooldown.__index = Cooldown

export type CooldownManager = typeof(setmetatable(
	{} :: {
		_expiresAt: { [any]: number },
		_clock: () -> number,
		_destroyed: boolean,
	},
	Cooldown
))

local function assertAlive(self: CooldownManager)
	assert(not self._destroyed, "Cooldown manager has been destroyed")
end

-- `clock` is an optional monotonic time source (seconds). Defaults to `os.clock`,
-- which is monotonic in Roblox. Tests pass a fake clock to avoid waiting.
function Cooldown.new(clock: (() -> number)?): CooldownManager
	assert(clock == nil or typeof(clock) == "function", "clock must be a function")

	local self = {
		_expiresAt = {},
		_clock = clock or os.clock,
		_destroyed = false,
	}

	return setmetatable(self, Cooldown) :: any
end

-- Starts a cooldown when the key is ready.
-- Returns true if the cooldown started, otherwise false.
function Cooldown:Use(key: any, duration: number): boolean
	assertAlive(self)
	assert(key ~= nil, "key cannot be nil")
	assert(typeof(duration) == "number" and duration >= 0, "duration must be a non-negative number")

	if not self:IsReady(key) then
		return false
	end

	self._expiresAt[key] = self._clock() + duration
	return true
end

-- Returns true when the key has no active cooldown.
function Cooldown:IsReady(key: any): boolean
	assertAlive(self)
	assert(key ~= nil, "key cannot be nil")

	local expiresAt = self._expiresAt[key]
	if expiresAt == nil then
		return true
	end

	if self._clock() >= expiresAt then
		self._expiresAt[key] = nil
		return true
	end

	return false
end

-- Returns the remaining cooldown time in seconds.
function Cooldown:GetRemaining(key: any): number
	assertAlive(self)
	assert(key ~= nil, "key cannot be nil")

	local expiresAt = self._expiresAt[key]
	if expiresAt == nil then
		return 0
	end

	local remaining = expiresAt - self._clock()
	if remaining <= 0 then
		self._expiresAt[key] = nil
		return 0
	end

	return remaining
end

-- Removes the cooldown associated with one key.
function Cooldown:Reset(key: any)
	assertAlive(self)
	assert(key ~= nil, "key cannot be nil")
	self._expiresAt[key] = nil
end

-- Removes every active cooldown.
function Cooldown:Clear()
	assertAlive(self)
	table.clear(self._expiresAt)
end

-- Clears the manager and prevents further use.
function Cooldown:Destroy()
	if self._destroyed then
		return
	end

	table.clear(self._expiresAt)
	self._destroyed = true
end

return Cooldown
