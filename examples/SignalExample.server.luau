-- Place this Script in ServerScriptService.
-- Place Signal.luau in ReplicatedStorage/RbxToolkit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.RbxToolkit.Signal)

-- One signal per player, cleared when they leave.
local playerLeveled = {}

Players.PlayerAdded:Connect(function(player)
	local signal = Signal.new()

	signal:Connect(function(newLevel: number)
		print(("%s reached level %d!"):format(player.Name, newLevel))
	end)

	playerLeveled[player.UserId] = signal
end)

Players.PlayerRemoving:Connect(function(player)
	playerLeveled[player.UserId]:Destroy()
	playerLeveled[player.UserId] = nil
end)

-- Fire it from wherever levels are awarded:
local function awardLevel(player: Player, newLevel: number)
	local signal = playerLeveled[player.UserId]
	if signal ~= nil then
		signal:Fire(newLevel)
	end
end

awardLevel(Players:GetPlayers()[1], 2)
