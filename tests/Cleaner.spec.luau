-- TestEZ-style tests.
return function()
	local Cleaner = require(game.ReplicatedStorage.RbxToolkit.Cleaner)
	describe("Cleaner", function()
		local cleaner

		beforeEach(function()
			cleaner = Cleaner.new()
		end)

		afterEach(function()
			if not cleaner:IsDestroyed() then
				cleaner:Destroy()
			end
		end)

		it("starts empty", function()
			expect(cleaner:GetCount()).to.equal(0)
		end)

		it("calls function items", function()
			local calls = 0
			cleaner:Add(function()
				calls += 1
			end)

			cleaner:Clean()

			expect(calls).to.equal(1)
			expect(cleaner:GetCount()).to.equal(0)
		end)

		it("cleans in reverse order of addition", function()
			local order = {}

			cleaner:Add(function()
				table.insert(order, "first")
			end)
			cleaner:Add(function()
				table.insert(order, "second")
			end)

			cleaner:Clean()

			expect(order[1]).to.equal("second")
			expect(order[2]).to.equal("first")
		end)

		it("prefers Disconnect over Destroy for tables", function()
			local calls = {}

			cleaner:Add({
				Disconnect = function()
					table.insert(calls, "disconnect")
				end,
				Destroy = function()
					table.insert(calls, "destroy")
				end,
			})

			cleaner:Clean()

			expect(#calls).to.equal(1)
			expect(calls[1]).to.equal("disconnect")
		end)

		it("calls Destroy on tables that only provide it", function()
			local destroyed = false

			cleaner:Add({
				Destroy = function()
					destroyed = true
				end,
			})

			cleaner:Clean()
			expect(destroyed).to.equal(true)
		end)

		it("closes threads", function()
			local finished = false
			local thread = coroutine.create(function()
				coroutine.yield()
				finished = true
			end)

			coroutine.resume(thread)
			cleaner:Add(thread)
			cleaner:Clean()

			expect(coroutine.status(thread)).to.equal("dead")
			expect(finished).to.equal(false)
		end)

		it("removes an item without cleaning it", function()
			local calls = 0
			local item = function()
				calls += 1
			end

			cleaner:Add(item)
			expect(cleaner:Remove(item)).to.equal(true)
			expect(cleaner:Remove(item)).to.equal(false)

			cleaner:Clean()
			expect(calls).to.equal(0)
		end)

		it("adds several items at once", function()
			local calls = 0

			cleaner:AddMany({
				function()
					calls += 1
				end,
				function()
					calls += 1
				end,
			})

			expect(cleaner:GetCount()).to.equal(2)
			cleaner:Clean()
			expect(calls).to.equal(2)
		end)

		it("keeps cleaning after one item fails", function()
			local cleaned = false
			local reported = {}
			local failingCleaner = Cleaner.new({
				onError = function(message: string)
					table.insert(reported, message)
				end,
			})

			failingCleaner:Add(function()
				cleaned = true
			end)
			failingCleaner:Add(function()
				error("boom")
			end)

			failingCleaner:Clean()

			expect(cleaned).to.equal(true)
			expect(#reported).to.equal(1)
			expect(failingCleaner:GetCount()).to.equal(0)
		end)

		it("reports a table without Disconnect or Destroy", function()
			local reported = {}
			local bareCleaner = Cleaner.new({
				onError = function(message: string)
					table.insert(reported, message)
				end,
			})

			bareCleaner:Add({})

			bareCleaner:Clean()

			expect(#reported).to.equal(1)
			expect(bareCleaner:GetCount()).to.equal(0)
		end)

		it("can be reused after Clean", function()
			local calls = 0

			cleaner:Add(function()
				calls += 1
			end)
			cleaner:Clean()

			cleaner:Add(function()
				calls += 1
			end)
			cleaner:Clean()

			expect(calls).to.equal(2)
		end)

		it("rejects nil items", function()
			expect(function()
				cleaner:Add(nil)
			end).to.throw()
		end)

		it("refuses to add after being destroyed", function()
			cleaner:Destroy()

			expect(cleaner:IsDestroyed()).to.equal(true)
			expect(function()
				cleaner:Add(function() end)
			end).to.throw()
		end)

		it("makes Destroy idempotent", function()
			local calls = 0

			cleaner:Add(function()
				calls += 1
			end)

			cleaner:Destroy()
			cleaner:Destroy()

			expect(calls).to.equal(1)
		end)

		it("disconnects a Roblox RBXScriptConnection", function()
			local disconnected = false
			local connection = {
				__robloxType = "RBXScriptConnection",
				Disconnect = function()
					disconnected = true
				end,
			}

			cleaner:Add(connection :: any)
			cleaner:Clean()

			expect(disconnected).to.equal(true)
		end)
	end)
end
