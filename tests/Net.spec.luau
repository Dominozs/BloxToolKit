-- TestEZ-style tests.
return function()
	local Net = require(game.ReplicatedStorage.RbxToolkit.Net)

	-- A minimal RemoteEvent: a signal-like `OnServerEvent` plus the cast methods.
	local function newFakeEvent()
		local handlers = {}
		local event = {
			fired = {} :: { any },
			disconnects = 0,
		}

		rawset(event, "__robloxType", "Instance")

		event.OnServerEvent = {
			Connect = function(_self, callback)
				table.insert(handlers, callback)
				return {
					Connected = true,
					Disconnect = function(connection)
						connection.Connected = false
						event.disconnects += 1
					end,
				}
			end,
		}

		function event:FireServer(...)
			table.insert(self.fired, { "FireServer", ... })
		end

		function event:FireClient(player, ...)
			table.insert(self.fired, { "FireClient", player, ... })
		end

		function event:FireAllClients(...)
			table.insert(self.fired, { "FireAllClients", ... })
		end

		-- Simulates the engine delivering a client call to the server handler.
		function event:Deliver(player, ...)
			for _, handler in handlers do
				handler(player, ...)
			end
		end

		return event
	end

	-- A minimal RemoteFunction: `OnServerInvoke` is a single callback.
	local function newFakeFunction()
		local fn = { invoked = {} :: { any } }
		rawset(fn, "__robloxType", "Instance")

		function fn:InvokeServer(...)
			table.insert(self.invoked, { "InvokeServer", ... })
			return "server-reply"
		end

		function fn:InvokeClient(player, ...)
			table.insert(self.invoked, { "InvokeClient", player, ... })
			return "client-reply"
		end

		return fn
	end

	describe("Net", function()
		it("rejects a nil remote", function()
			expect(function()
				Net.new(nil)
			end).to.throw()
		end)

		it("rejects an object with no remote methods", function()
			expect(function()
				Net.new({})
			end).to.throw()
		end)

		it("accepts a RemoteEvent", function()
			local net = Net.new(newFakeEvent())
			expect(net:IsDestroyed()).to.equal(false)
		end)

		it("accepts a RemoteFunction", function()
			local net = Net.new(newFakeFunction())
			expect(net:IsDestroyed()).to.equal(false)
		end)

		it("passes fired arguments straight through", function()
			local event = newFakeEvent()
			local net = Net.new(event)

			net:FireServer("a", 2)
			net:FireClient("player", "b")
			net:FireAllClients("c")

			expect(#event.fired).to.equal(3)
			expect(event.fired[1][1]).to.equal("FireServer")
			expect(event.fired[1][2]).to.equal("a")
			expect(event.fired[2][1]).to.equal("FireClient")
			expect(event.fired[2][2]).to.equal("player")
			expect(event.fired[3][1]).to.equal("FireAllClients")
		end)

		it("delivers server events to the handler", function()
			local event = newFakeEvent()
			local net = Net.new(event)
			local received

			net:OnServerEvent(function(player, payload)
				received = { player, payload }
			end)

			event:Deliver("player", "payload")

			expect(received[1]).to.equal("player")
			expect(received[2]).to.equal("payload")
		end)

		it("drops a call when validate returns false", function()
			local event = newFakeEvent()
			local net = Net.new(event)
			local calls = 0

			net:OnServerEvent(function()
				calls += 1
			end, {
				validate = function()
					return false
				end,
			})

			event:Deliver("player", "payload")
			expect(calls).to.equal(0)
		end)

		it("reports a rejected call through onReject", function()
			local event = newFakeEvent()
			local net = Net.new(event)
			local rejected

			net:OnServerEvent(function() end, {
				validate = function()
					return false
				end,
				onReject = function(player)
					rejected = player
				end,
			})

			event:Deliver("player")
			expect(rejected).to.equal("player")
		end)

		it("runs the handler when validate returns true", function()
			local event = newFakeEvent()
			local net = Net.new(event)
			local calls = 0

			net:OnServerEvent(function()
				calls += 1
			end, {
				validate = function()
					return true
				end,
			})

			event:Deliver("player")
			expect(calls).to.equal(1)
		end)

		it("rejects a non-function validate option", function()
			local net = Net.new(newFakeEvent())

			expect(function()
				net:OnServerEvent(function() end, { validate = 5 } :: any)
			end).to.throw()
		end)

		it("installs OnServerInvoke for a RemoteFunction", function()
			local fn = newFakeFunction()
			local net = Net.new(fn)

			net:OnServerEvent(function(player, payload)
				return player .. ":" .. payload
			end)

			expect(typeof(fn.OnServerInvoke)).to.equal("function")
			expect(fn.OnServerInvoke("player", "payload")).to.equal("player:payload")
		end)

		it("returns nil from a rejected RemoteFunction call", function()
			local fn = newFakeFunction()
			local net = Net.new(fn)

			net:OnServerEvent(function()
				return "should not run"
			end, {
				validate = function()
					return false
				end,
			})

			expect(fn.OnServerInvoke("player")).to.equal(nil)
		end)

		it("returns (true, result) from InvokeServer", function()
			local net = Net.new(newFakeFunction())

			local ok, result = net:InvokeServer("a")
			expect(ok).to.equal(true)
			expect(result).to.equal("server-reply")
		end)

		it("returns (false, nil, err) when InvokeServer throws", function()
			local fn = newFakeFunction()
			fn.InvokeServer = function()
				error("boom")
			end
			local net = Net.new(fn)

			local ok, result, err = net:InvokeServer()
			expect(ok).to.equal(false)
			expect(result).to.equal(nil)
			expect(string.find(err, "boom", 1, true) ~= nil).to.equal(true)
		end)

		it("returns (false, nil, err) when InvokeClient throws", function()
			local fn = newFakeFunction()
			fn.InvokeClient = function()
				error("client boom")
			end
			local net = Net.new(fn)

			local ok, _, err = net:InvokeClient("player")
			expect(ok).to.equal(false)
			expect(string.find(err, "client boom", 1, true) ~= nil).to.equal(true)
		end)

		it("disconnects tracked connections on Destroy", function()
			local event = newFakeEvent()
			local net = Net.new(event)

			net:OnServerEvent(function() end)
			net:Destroy()

			expect(event.disconnects).to.equal(1)
			expect(net:IsDestroyed()).to.equal(true)
		end)

		it("clears an installed OnServerInvoke on Destroy", function()
			local fn = newFakeFunction()
			local net = Net.new(fn)

			net:OnServerEvent(function() end)
			net:Destroy()

			expect(fn.OnServerInvoke).to.equal(nil)
		end)

		it("leaves a foreign OnServerInvoke alone on Destroy", function()
			local fn = newFakeFunction()
			local net = Net.new(fn)
			net:OnServerEvent(function() end)

			local foreign = function() end
			fn.OnServerInvoke = foreign

			net:Destroy()
			expect(fn.OnServerInvoke).to.equal(foreign)
		end)

		it("is idempotent when destroyed twice", function()
			local event = newFakeEvent()
			local net = Net.new(event)
			net:OnServerEvent(function() end)

			net:Destroy()
			net:Destroy()

			expect(event.disconnects).to.equal(1)
		end)

		it("refuses to fire after being destroyed", function()
			local net = Net.new(newFakeEvent())
			net:Destroy()

			expect(function()
				net:FireServer()
			end).to.throw()
		end)

		it("refuses to register a handler after being destroyed", function()
			local net = Net.new(newFakeEvent())
			net:Destroy()

			expect(function()
				net:OnServerEvent(function() end)
			end).to.throw()
		end)
	end)
end
