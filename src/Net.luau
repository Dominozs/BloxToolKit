--!strict
--[[
	RbxToolkit - Net
	A server-authoritative wrapper around a RemoteEvent or RemoteFunction.

	`Net` collects the pieces every remote ends up repeating: validating client
	calls before they reach game logic, turning a rejected call into a drop
	instead of a silent success, funnelling returned errors into
	`(ok, result, err)` instead of throwing, and tracking its own connections so
	`Destroy` can release them all at once.

	The wrapper is deliberately dependency-free so it can be copied on its own.
	Callers that want throttling can validate through `RateLimiter`, which
	returns `false` when a key is over budget - exactly the signal `validate`
	wants:

		local limiter = RateLimiter.new(10, 20)
		net:OnServerEvent(handler, {
			validate = function(player)
				return limiter:Consume(player.UserId)
			end,
		})

	Example:
		local Net = require(path.To.Net)
		local net = Net.new(ReplicatedStorage.Remotes.DoAction)

		net:OnServerEvent(function(player, payload)
			applyAction(player, payload)
		end, {
			validate = function(player, payload)
				return typeof(payload) == "table" and payload.action ~= nil
			end,
			onReject = function(player)
				warn(player.Name .. " sent an invalid payload")
			end,
		})
]]

local Net = {}
Net.__index = Net

export type Options = {
	validate: ((player: any, ...any) -> boolean)?,
	onReject: ((player: any, ...any) -> ())?,
}

export type Net = {
	OnServerEvent: (self: Net, handler: (player: any, ...any) -> any, options: Options?) -> any,
	FireServer: (self: Net, ...any) -> (),
	InvokeServer: (self: Net, ...any) -> (boolean, any?, string?),
	FireClient: (self: Net, player: any, ...any) -> (),
	FireAllClients: (self: Net, ...any) -> (),
	InvokeClient: (self: Net, player: any, ...any) -> (boolean, any?, string?),
	IsDestroyed: (self: Net) -> boolean,
	Destroy: (self: Net) -> (),
}

local function assertAlive(self: any)
	assert(not self.__destroyed, "Net has been destroyed")
end

-- A member access on an Instance yields the method function or nil, so the same
-- probe works for real remotes and for duck-typed tables in tests.
local function hasMethod(remote: any, name: string): boolean
	return typeof(remote[name]) == "function"
end

-- RemoteEvent and RemoteFunction expose disjoint method sets, so the presence of
-- a cast method tells us which side of the pair we were handed.
local function isEventRemote(remote: any): boolean
	return hasMethod(remote, "FireServer") or hasMethod(remote, "FireClient") or hasMethod(remote, "FireAllClients")
end

local function isFunctionRemote(remote: any): boolean
	return hasMethod(remote, "InvokeServer") or hasMethod(remote, "InvokeClient")
end

-- Wraps `handler` so the validation hook runs first. Returns `nil` for a
-- rejected call, which drops RemoteEvent handlers and returns `nil` from a
-- RemoteFunction handler.
local function wrapHandler(handler: (player: any, ...any) -> any, options: Options?): (any, ...any) -> any
	local config: Options = options or {}
	assert(config.validate == nil or typeof(config.validate) == "function", "validate must be a function")
	assert(config.onReject == nil or typeof(config.onReject) == "function", "onReject must be a function")

	local validate = config.validate
	local onReject = config.onReject

	return function(player: any, ...)
		if validate ~= nil and not validate(player, ...) then
			if onReject ~= nil then
				onReject(player, ...)
			end

			return nil
		end

		return handler(player, ...)
	end
end

-- `remote` is a RemoteEvent or RemoteFunction instance, or a table exposing the
-- same methods for headless tests.
function Net.new(remote: any): Net
	assert(remote ~= nil, "remote is required")

	local kind = typeof(remote)
	assert(kind == "Instance" or kind == "table", "remote must be a RemoteEvent or RemoteFunction")

	local eventLike = isEventRemote(remote)
	local functionLike = isFunctionRemote(remote)
	assert(eventLike or functionLike, "remote must be a RemoteEvent or RemoteFunction")

	return (
		setmetatable({
			__remote = remote,
			-- A RemoteEvent never exposes a cast method, so an "event-like" remote
			-- wins when a duck-typed table carries both sets.
			__isFunction = functionLike and not eventLike,
			__connections = {},
			__serverInvoke = nil,
			__destroyed = false,
		}, Net) :: any
	) :: Net
end

-- Registers the server-side handler. `handler` receives `(player, ...)`.
-- `options.validate` runs first; returning `false` drops the call and reports it
-- through `options.onReject` when provided.
--
-- For a RemoteEvent this connects to `OnServerEvent` and returns the connection.
-- For a RemoteFunction it installs `OnServerInvoke` and returns `nil`.
function Net.OnServerEvent(self: any, handler: any, options: Options?): any
	assertAlive(self)
	assert(typeof(handler) == "function", "handler must be a function")

	local wrapped = wrapHandler(handler, options)

	if self.__isFunction then
		self.__serverInvoke = wrapped
		self.__remote.OnServerInvoke = wrapped
		return nil
	end

	local signal = self.__remote.OnServerEvent
	assert(signal ~= nil and typeof(signal.Connect) == "function", "remote has no OnServerEvent signal")

	local connection = signal:Connect(wrapped)
	table.insert(self.__connections, connection)
	return connection
end

-- Client -> server, no reply.
function Net.FireServer(self: any, ...: any)
	assertAlive(self)
	assert(hasMethod(self.__remote, "FireServer"), "remote does not support FireServer")

	self.__remote:FireServer(...)
end

-- Client -> server, awaiting `remote:InvokeServer(...)`. Never throws: returns
-- `(ok, result, err)`.
function Net.InvokeServer(self: any, ...: any): (boolean, any?, string?)
	assertAlive(self)
	assert(hasMethod(self.__remote, "InvokeServer"), "remote does not support InvokeServer")

	local ok, result = pcall(self.__remote.InvokeServer, self.__remote, ...)
	if not ok then
		return false, nil, tostring(result)
	end

	return true, result, nil
end

-- Server -> one client, no reply.
function Net.FireClient(self: any, player: any, ...: any)
	assertAlive(self)
	assert(player ~= nil, "player is required")
	assert(hasMethod(self.__remote, "FireClient"), "remote does not support FireClient")

	self.__remote:FireClient(player, ...)
end

-- Server -> every client, no reply.
function Net.FireAllClients(self: any, ...: any)
	assertAlive(self)
	assert(hasMethod(self.__remote, "FireAllClients"), "remote does not support FireAllClients")

	self.__remote:FireAllClients(...)
end

-- Server -> one client, awaiting a reply. Never throws: returns
-- `(ok, result, err)`. Only RemoteFunctions support this.
function Net.InvokeClient(self: any, player: any, ...: any): (boolean, any?, string?)
	assertAlive(self)
	assert(player ~= nil, "player is required")
	assert(hasMethod(self.__remote, "InvokeClient"), "remote does not support InvokeClient")

	local ok, result = pcall(self.__remote.InvokeClient, self.__remote, player, ...)
	if not ok then
		return false, nil, tostring(result)
	end

	return true, result, nil
end

function Net.IsDestroyed(self: any): boolean
	return self.__destroyed
end

-- Disconnects every tracked connection, detaches an installed `OnServerInvoke`
-- if it is still ours, and prevents further use.
function Net.Destroy(self: any)
	if self.__destroyed then
		return
	end

	for _, connection in self.__connections do
		if typeof(connection.Disconnect) == "function" then
			connection:Disconnect()
		end
	end

	table.clear(self.__connections)

	local owner = self.__serverInvoke
	if owner ~= nil then
		local remote = self.__remote
		if remote.OnServerInvoke == owner then
			remote.OnServerInvoke = nil
		end

		self.__serverInvoke = nil
	end

	self.__destroyed = true
end

return Net
