-- Place this Script in ServerScriptService.
-- Place DataStoreHelper.luau in ReplicatedStorage/RbxToolkit.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataStoreHelper = require(ReplicatedStorage.RbxToolkit.DataStoreHelper)

local coins = DataStoreHelper.new(DataStoreService:GetDataStore("Coins"), {
	attempts = 4,
	baseDelay = 0.5,
	maxDelay = 8,
})

local function onPlayerAdded(player: Player)
	local value = coins:GetOrDefault(tostring(player.UserId), 0)
	player:SetAttribute("Coins", value)
	print(("%s has %d coins"):format(player.Name, value))
end

local function onPlayerRemoving(player: Player)
	local ok, _, err = coins:Set(tostring(player.UserId), player:GetAttribute("Coins") or 0)
	if not ok then
		warn(("could not save coins for %s: %s"):format(player.Name, err))
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Safe atomic increment. Call this from wherever coins are awarded.
local function awardCoins(player: Player, amount: number)
	local ok, newTotal, err = coins:Increment(tostring(player.UserId), amount)
	if not ok then
		warn(("could not award coins: %s"):format(err))
		return
	end

	player:SetAttribute("Coins", newTotal)
end

return awardCoins
