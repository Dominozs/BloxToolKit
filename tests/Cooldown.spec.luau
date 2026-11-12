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
    end)
end
