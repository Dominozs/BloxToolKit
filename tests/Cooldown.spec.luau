-- TestEZ-style tests.
-- Put this file in your TestEZ test hierarchy and adjust the require path if needed.

return function()
	local Cooldown = require(game.ReplicatedStorage.RbxToolkit.Cooldown)

	describe("Cooldown", function()
		local cooldown

		beforeEach(function()
			cooldown = Cooldown.new()
		end)

		afterEach(function()
			cooldown:Destroy()
		end)

		it("allows a key with no active cooldown", function()
			expect(cooldown:IsReady("player-1")).to.equal(true)
		end)

		it("starts a cooldown and blocks reuse", function()
			expect(cooldown:Use("player-1", 10)).to.equal(true)
			expect(cooldown:Use("player-1", 10)).to.equal(false)
			expect(cooldown:IsReady("player-1")).to.equal(false)
		end)

		it("reports remaining time", function()
			cooldown:Use("player-1", 10)
			expect(cooldown:GetRemaining("player-1") > 0).to.equal(true)
		end)

		it("resets a single key", function()
			cooldown:Use("player-1", 10)
			cooldown:Reset("player-1")
			expect(cooldown:IsReady("player-1")).to.equal(true)
		end)

		it("clears all keys", function()
			cooldown:Use("player-1", 10)
			cooldown:Use("player-2", 10)
			cooldown:Clear()
			expect(cooldown:IsReady("player-1")).to.equal(true)
			expect(cooldown:IsReady("player-2")).to.equal(true)
		end)

		it("expires once the clock passes the duration", function()
			local now = 0
			local timed = Cooldown.new(function()
				return now
			end)

			expect(timed:Use("player-1", 10)).to.equal(true)

			now = 9
			expect(timed:IsReady("player-1")).to.equal(false)
			expect(timed:GetRemaining("player-1")).to.equal(1)

			now = 10
			expect(timed:IsReady("player-1")).to.equal(true)
			expect(timed:GetRemaining("player-1")).to.equal(0)
			timed:Destroy()
		end)

		it("treats a zero duration as immediately ready", function()
			expect(cooldown:Use("player-1", 0)).to.equal(true)
			expect(cooldown:IsReady("player-1")).to.equal(true)
		end)

		it("rejects a negative duration", function()
			expect(function()
				cooldown:Use("player-1", -1)
			end).to.throw()
		end)

		it("refuses to be used after being destroyed", function()
			cooldown:Destroy()
			expect(function()
				cooldown:Use("player-1", 1)
			end).to.throw()
		end)

		it("counts entries", function()
			cooldown:Use("player-1", 10)
			cooldown:Use("player-2", 10)

			expect(cooldown:GetCount()).to.equal(2)
			cooldown:Clear()
			expect(cooldown:GetCount()).to.equal(0)
		end)

		it("sweeps expired entries", function()
			local now = 0
			local timed = Cooldown.new(function()
				return now
			end)

			timed:Use("gone", 5)
			timed:Use("kept", 50)

			now = 10
			expect(timed:Sweep()).to.equal(1)
			expect(timed:GetCount()).to.equal(1)
			expect(timed:IsReady("kept")).to.equal(false)
			expect(timed:IsReady("gone")).to.equal(true)
			timed:Destroy()
		end)
	end)
end
