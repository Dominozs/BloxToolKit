--!strict
--[[
	RbxToolkit - Signal
	A small, dependency-free event implementation.

	Signals are plain tables, so they cost nothing to construct and need no
	parenting. Each handler runs inside `pcall`, so one failing handler cannot
	stop the others - the same guarantee Roblox events give you.

	Example:
		local Signal = require(path.To.Signal)
		local died = Signal.new()

		local connection = died:Connect(function(who: string)
			print(who .. " died")
		end)

		died:Fire("Player1")
		connection:Disconnect()
]]

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	GetConnectionCount: (self: Signal<T...>) -> number,
	DisconnectAll: (self: Signal<T...>) -> (),
	IsDestroyed: (self: Signal<T...>) -> boolean,
	Destroy: (self: Signal<T...>) -> (),
}

type Handler = (any) -> ()
type Entry = {
	callback: Handler,
	connection: Connection,
	once: boolean,
}

local function defaultLogError(message: string)
	warn(message)
end

local function assertAlive(self: any)
	assert(not self.__destroyed, "Signal has been destroyed")
end

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({
		__entries = {},
		__destroyed = false,
		__logError = defaultLogError,
	}, Signal)

	return (self :: any) :: Signal<T...>
end

local function removeEntry(signal: any, entry: Entry)
	local entries = signal.__entries
	for index, other in entries do
		if other == entry then
			table.remove(entries, index)
			return
		end
	end
end

local function addEntry(signal: any, callback: Handler, once: boolean): Connection
	local entry: Entry = nil :: any

	local connection: Connection = {
		Connected = true,
		Disconnect = function(self: Connection)
			if not self.Connected then
				return
			end

			self.Connected = false
			removeEntry(signal, entry)
		end,
	}

	entry = {
		callback = callback,
		connection = connection,
		once = once,
	}

	table.insert(signal.__entries, entry)
	return connection
end

-- Registers a handler that runs every time the signal fires.
function Signal.Connect(self: any, callback: Handler): Connection
	assertAlive(self)
	assert(typeof(callback) == "function", "callback must be a function")

	return addEntry(self, callback, false)
end

-- Registers a handler that runs once, then disconnects itself.
function Signal.Once(self: any, callback: Handler): Connection
	assertAlive(self)
	assert(typeof(callback) == "function", "callback must be a function")

	return addEntry(self, callback, true)
end

-- Calls every connected handler with the given arguments.
function Signal.Fire(self: any, ...: any)
	assertAlive(self)
	local args = table.pack(...)
	local snapshot: { Entry } = table.clone(self.__entries)

	for _, entry in snapshot do
		if not entry.connection.Connected then
			continue
		end

		if entry.once then
			entry.connection:Disconnect()
		end

		local results = table.pack(pcall(entry.callback, table.unpack(args, 1, args.n)))
		if not results[1] then
			self.__logError(("Signal handler error: %s"):format(tostring(results[2])))
		end
	end
end

-- Yields the current coroutine until the signal fires once, then returns the
-- fired arguments. The temporary handler disconnects itself and resumes the
-- waiting coroutine directly, so no scheduler is required.
function Signal.Wait(self: any): ...any
	assertAlive(self)

	local thread = coroutine.running()
	local connection: Connection = nil :: any

	connection = self:Connect(function(...)
		connection:Disconnect()
		coroutine.resume(thread, ...)
	end)

	return coroutine.yield()
end

-- Returns how many handlers are currently connected.
function Signal.GetConnectionCount(self: any): number
	assertAlive(self)
	return #self.__entries
end

-- Disconnects every handler but keeps the signal usable.
function Signal.DisconnectAll(self: any)
	assertAlive(self)

	for _, entry in self.__entries do
		entry.connection.Connected = false
	end

	table.clear(self.__entries)
end

function Signal.IsDestroyed(self: any): boolean
	return self.__destroyed
end

-- Disconnects every handler and prevents further use.
function Signal.Destroy(self: any)
	if self.__destroyed then
		return
	end

	for _, entry in self.__entries do
		entry.connection.Connected = false
	end

	table.clear(self.__entries)
	self.__destroyed = true
end

return Signal
