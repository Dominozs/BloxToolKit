-- Place this Script in ServerScriptService.
-- Place Net.luau in ReplicatedStorage/RbxToolkit.
-- Create a RemoteEvent named "DoAction" in ReplicatedStorage/Remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.RbxToolkit.Net)

local net = Net.new(ReplicatedStorage.Remotes.DoAction)

local ALLOWED_ACTIONS = { jump = true, emote = true }

net:OnServerEvent(function(player, payload)
	if not ALLOWED_ACTIONS[payload.action] then
		return
	end

	print(("%s performed %s"):format(player.Name, payload.action))
end, {
	-- Reject anything that is not a well-formed request.
	validate = function(_player, payload)
		if typeof(payload) ~= "table" then
			return false
		end

		if typeof(payload.action) ~= "string" then
			return false
		end

		return true
	end,
	onReject = function(player)
		warn(("%s sent an invalid request"):format(player.Name))
	end,
})

-- Client-side usage, from a LocalScript:
--   local net = Net.new(ReplicatedStorage.Remotes.DoAction)
--   net:FireServer({ action = "jump" })
