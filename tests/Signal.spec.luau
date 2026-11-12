-- TestEZ-style tests.
-- Put this file in your TestEZ test hierarchy and adjust the require path if needed.
return function()
	local Signal = require(game.ReplicatedStorage.RbxToolkit.Signal)
	describe("Signal", function()
		local signal

		beforeEach(function()
			signal = Signal.new()
		end)

		afterEach(function()
			signal:Destroy()
		end)

		it("starts with no connections", function()
			expect(signal:GetConnectionCount()).to.equal(0)
		end)

		it("passes arguments to connected handlers", function()
			local seen = {}

			signal:Connect(function(a, b)
				seen = { a, b }
			end)
			signal:Fire("one", "two")

			expect(#seen).to.equal(2)
			expect(seen[1]).to.equal("one")
			expect(seen[2]).to.equal("two")
		end)

		it("calls handlers in the order they were connected", function()
			local order = {}

			signal:Connect(function()
				table.insert(order, 1)
			end)
			signal:Connect(function()
				table.insert(order, 2)
			end)
			signal:Fire()

			expect(order[1]).to.equal(1)
			expect(order[2]).to.equal(2)
		end)

		it("stops calling a disconnected handler", function()
			local calls = 0
			local connection = signal:Connect(function()
				calls += 1
			end)

			signal:Fire()
			connection:Disconnect()
			signal:Fire()

			expect(calls).to.equal(1)
			expect(connection.Connected).to.equal(false)
		end)

		it("treats a repeated disconnect as a no-op", function()
			local connection = signal:Connect(function() end)

			connection:Disconnect()
			connection:Disconnect()

			expect(connection.Connected).to.equal(false)
			expect(signal:GetConnectionCount()).to.equal(0)
		end)

		it("runs a Once handler exactly one time", function()
			local calls = 0

			signal:Once(function()
				calls += 1
			end)

			signal:Fire()
			signal:Fire()

			expect(calls).to.equal(1)
			expect(signal:GetConnectionCount()).to.equal(0)
		end)

		it("keeps other handlers running when one errors", function()
			local logged = {}
			signal.__logError = function(message: string)
				table.insert(logged, message)
			end

			local calls = 0
			signal:Connect(function()
				error("boom")
			end)
			signal:Connect(function()
				calls += 1
			end)

			signal:Fire()

			expect(calls).to.equal(1)
			expect(#logged).to.equal(1)
		end)

		it("skips a handler disconnected earlier in the same Fire", function()
			local calls = 0
			local second

			signal:Connect(function()
				second:Disconnect()
			end)
			second = signal:Connect(function()
				calls += 1
			end)

			signal:Fire()

			expect(calls).to.equal(0)
		end)

		it("does not call handlers connected during the same Fire", function()
			local lateCalls = 0

			signal:Connect(function()
				signal:Connect(function()
					lateCalls += 1
				end)
			end)

			signal:Fire()
			expect(lateCalls).to.equal(0)

			signal:Fire()
			expect(lateCalls).to.equal(1)
		end)

		it("disconnects everything with DisconnectAll but stays usable", function()
			local calls = 0
			signal:Connect(function()
				calls += 1
			end)

			signal:DisconnectAll()
			expect(signal:GetConnectionCount()).to.equal(0)

			signal:Fire()
			expect(calls).to.equal(0)

			signal:Connect(function()
				calls += 1
			end)
			signal:Fire()
			expect(calls).to.equal(1)
		end)

		it("marks connections disconnected when destroyed", function()
			local connection = signal:Connect(function() end)

			signal:Destroy()

			expect(connection.Connected).to.equal(false)
			expect(signal:IsDestroyed()).to.equal(true)
		end)

		it("refuses to fire after being destroyed", function()
			signal:Destroy()

			expect(function()
				signal:Fire()
			end).to.throw()
		end)

		it("refuses to connect after being destroyed", function()
			signal:Destroy()

			expect(function()
				signal:Connect(function() end)
			end).to.throw()
		end)

		it("rejects a non-function callback", function()
			expect(function()
				signal:Connect(5)
			end).to.throw()
		end)
	end)
end
