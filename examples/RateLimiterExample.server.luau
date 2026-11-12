-- Place this Script in ServerScriptService.
-- Place RateLimiter.luau in ReplicatedStorage/RbxToolkit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RateLimiter = require(ReplicatedStorage.RbxToolkit.RateLimiter)

-- 10 requests per second sustained, bursts up to 20, per player.
local limiter = RateLimiter.new(10, 20)

local remote = ReplicatedStorage:WaitForChild("DoAction") :: RemoteEvent

remote.OnServerEvent:Connect(function(player: Player)
	-- Never trust the client: validate and rate-limit on the server.
	if not limiter:Consume(player.UserId) then
		warn(("%s is sending too fast - retry in %.2fs"):format(player.Name, limiter:GetRetryTime(player.UserId)))
		return
	end

	-- Handle the action here.
end)

Players.PlayerRemoving:Connect(function(player)
	limiter:Reset(player.UserId)
end)
