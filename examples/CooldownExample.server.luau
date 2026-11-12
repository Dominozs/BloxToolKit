-- Place this Script in ServerScriptService.
-- Place Cooldown.luau in ReplicatedStorage/RbxToolkit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cooldown = require(ReplicatedStorage.RbxToolkit.Cooldown)
local abilityCooldown = Cooldown.new()

local COOLDOWN_SECONDS = 5

local function useAbility(player: Player)
	if not abilityCooldown:Use(player.UserId, COOLDOWN_SECONDS) then
		local remaining = abilityCooldown:GetRemaining(player.UserId)
		print(("%s must wait %.1f seconds"):format(player.Name, remaining))
		return
	end

	print(player.Name .. " used the ability!")
	-- Add the server-side ability logic here.
end

-- Demonstration: press a ProximityPrompt to use the ability.
local prompt = workspace:WaitForChild("AbilityPrompt"):WaitForChild("ProximityPrompt")
prompt.Triggered:Connect(useAbility)

Players.PlayerRemoving:Connect(function(player)
	abilityCooldown:Reset(player.UserId)
end)
