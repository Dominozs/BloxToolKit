-- Place this Script in ServerScriptService.
-- Place Cleaner.luau and Signal.luau in ReplicatedStorage/RbxToolkit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cleaner = require(ReplicatedStorage.RbxToolkit.Cleaner)

-- Everything one round of gameplay creates, released in one call.
local function startRound(roundNumber: number): Cleaner.Cleaner
	local cleaner = Cleaner.new()

	local arena = Instance.new("Folder")
	arena.Name = "Arena" .. roundNumber
	arena.Parent = workspace
	cleaner:Add(arena)

	local connection = game:GetService("RunService").Heartbeat:Connect(function()
		-- round logic here
	end)
	cleaner:Add(connection)

	cleaner:Add(function()
		print(("round %d cleaned up"):format(roundNumber))
	end)

	return cleaner
end

local round = startRound(1)

-- When the round ends:
round:Destroy()
