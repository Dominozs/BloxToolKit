--!strict
--[[
	RbxToolkit - Cleaner
	A single place to release everything a piece of code created.

	`Cleaner` accepts a mixed bag of things that need releasing and cleans them
	in reverse order of addition:

		function        called
		thread          closed with `coroutine.close`
		Instance        `:Destroy()`
		table           `:Disconnect()` if present, otherwise `:Destroy()`
		Connection      `:Disconnect()` (RbxScriptConnection or toolkit Signal)

	Example:
		local Cleaner = require(path.To.Cleaner)
		local cleaner = Cleaner.new()

		cleaner:Add(part.Touched:Connect(onTouched))
		cleaner:Add(someModel)
		cleaner:Add(function()
			print("cleaning up")
		end)

		cleaner:Clean()
]]

local Cleaner = {}
Cleaner.__index = Cleaner

export type CleanerItem = (() -> ()) | thread | Instance | { Destroy: (any) -> () } | { Disconnect: (any) -> () }

export type Options = {
	onError: ((message: string) -> ())?,
}

export type Cleaner = {
	Add: (self: Cleaner, CleanerItem) -> (),
	AddMany: (self: Cleaner, { CleanerItem }) -> (),
	Remove: (self: Cleaner, CleanerItem) -> boolean,
	Clean: (self: Cleaner) -> (),
	IsDestroyed: (self: Cleaner) -> boolean,
	Destroy: (self: Cleaner) -> (),
	GetCount: (self: Cleaner) -> number,
}

local function assertAlive(self: any)
	assert(not self.__destroyed, "Cleaner has been destroyed")
end

local function defaultOnError(message: string)
	warn(message)
end

-- `onError` receives one message per failing item. The default reports through
-- `warn`, because `Clean` is usually called from a Roblox event handler where a
-- thrown error would be swallowed. Pass a function that errors if you want
-- failures to propagate.
function Cleaner.new(options: Options?): Cleaner
	local config: Options = options or {}
	assert(config.onError == nil or typeof(config.onError) == "function", "onError must be a function")

	return (
		setmetatable({
			__items = {},
			__onError = config.onError or defaultOnError,
			__destroyed = false,
		}, Cleaner) :: any
	) :: Cleaner
end

local function cleanItem(item: any)
	if typeof(item) == "function" then
		item()
	elseif typeof(item) == "thread" then
		coroutine.close(item)
	elseif typeof(item) == "Instance" then
		item:Destroy()
	elseif typeof(item) == "table" then
		local disconnect = item.Disconnect
		if typeof(disconnect) == "function" then
			disconnect(item)
			return
		end

		local destroy = item.Destroy
		assert(typeof(destroy) == "function", "table item must provide :Disconnect() or :Destroy()")
		destroy(item)
	else
		error(("cannot clean item of type %s"):format(typeof(item)), 3)
	end
end

-- Adds one item. Items can be added at any time and are cleaned in reverse order.
function Cleaner:Add(item: CleanerItem)
	assertAlive(self)
	assert(item ~= nil, "item cannot be nil")

	table.insert(self.__items, item)
end

-- Adds several items at once.
function Cleaner:AddMany(items: { CleanerItem })
	assertAlive(self)
	assert(typeof(items) == "table", "items must be a table")

	for _, item in items do
		self:Add(item)
	end
end

-- Removes an item without cleaning it. Returns whether it was found.
function Cleaner:Remove(item: CleanerItem): boolean
	assertAlive(self)

	for index, other in self.__items do
		if other == item then
			table.remove(self.__items, index)
			return true
		end
	end

	return false
end

-- Cleans every item in reverse order and empties the cleaner. The cleaner stays
-- usable. If an item fails, remaining items are still cleaned and the failure
-- is reported through `onError` instead of stopping the caller.
function Cleaner:Clean()
	assertAlive(self)

	local items = self.__items
	self.__items = {}

	for index = #items, 1, -1 do
		local results = table.pack(pcall(cleanItem, items[index]))
		if not results[1] then
			self.__onError(("Cleaner item failed: %s"):format(tostring(results[2])))
		end
	end
end

function Cleaner:GetCount(): number
	assertAlive(self)
	return #self.__items
end

function Cleaner:IsDestroyed(): boolean
	return self.__destroyed
end

-- Cleans every item and prevents further use.
function Cleaner:Destroy()
	if self.__destroyed then
		return
	end

	self:Clean()
	self.__destroyed = true
end

return Cleaner
