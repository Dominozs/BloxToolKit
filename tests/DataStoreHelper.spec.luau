-- TestEZ-style tests.
return function()
	local DataStoreHelper = require(game.ReplicatedStorage.RbxToolkit.DataStoreHelper)

	-- A fake DataStore: records calls and replays scripted failures.
	local function newFakeStore(robloxType: string?)
		local store = {
			data = {} :: { [string]: any },
			calls = {} :: { string },
			failures = {} :: { [string]: number },
			failureMessage = "DataStore request failed",
			transformError = nil :: string?,
		}

		if robloxType ~= nil then
			rawset(store, "__robloxType", robloxType)
		end

		local function record(method: string)
			table.insert(store.calls, method)

			local remaining = store.failures[method]
			if remaining ~= nil and remaining > 0 then
				store.failures[method] = remaining - 1
				error(store.failureMessage)
			end
		end

		function store:GetAsync(key: string)
			record("GetAsync")
			local value = self.data[key]
			if value == nil then
				error(("%s not found"):format(key))
			end
			return value
		end

		function store:SetAsync(key: string, value: any)
			record("SetAsync")
			self.data[key] = value
			return key
		end

		function store:UpdateAsync(key: string, transform: (any) -> any)
			record("UpdateAsync")
			if self.transformError ~= nil then
				error(self.transformError)
			end
			local nextValue = transform(self.data[key])
			self.data[key] = nextValue
			return nextValue
		end

		function store:RemoveAsync(key: string)
			record("RemoveAsync")
			self.data[key] = nil
			return key
		end

		function store:IncrementAsync(key: string, delta: number)
			record("IncrementAsync")
			self.data[key] = (self.data[key] or 0) + delta
			return self.data[key]
		end

		return store
	end

	describe("DataStoreHelper", function()
		local store
		local waits
		local logs
		local helper

		local function noWait(seconds: number)
			table.insert(waits, seconds)
		end

		local function noLog(message: string)
			table.insert(logs, message)
		end

		beforeEach(function()
			store = newFakeStore()
			waits = {}
			logs = {}
			helper = DataStoreHelper.new(store, {
				attempts = 3,
				baseDelay = 1,
				maxDelay = 4,
				jitter = 0,
				wait = noWait,
				logger = noLog,
			})
		end)

		afterEach(function()
			helper:Destroy()
		end)

		it("rejects a store that is missing methods", function()
			expect(function()
				DataStoreHelper.new({})
			end).to.throw()
		end)

		it("accepts a Roblox DataStore instance", function()
			local realLike = newFakeStore("Instance")
			local robloxHelper = DataStoreHelper.new(realLike :: any, { wait = noWait, logger = noLog })

			expect(robloxHelper:Set("player-1", 7)).to.equal(true)
			expect(realLike.data["player-1"]).to.equal(7)
			robloxHelper:Destroy()
		end)

		it("reads a value", function()
			store.data["player-1"] = 42

			local ok, value, err = helper:Get("player-1")

			expect(ok).to.equal(true)
			expect(value).to.equal(42)
			expect(err).to.equal(nil)
		end)

		it("returns a default when the key is missing", function()
			local ok, value, err = helper:Get("missing", "fallback")

			expect(ok).to.equal(false)
			expect(value).to.equal("fallback")
			expect(err).to.be.a("string")
		end)

		it("does not retry a missing key", function()
			helper:Get("missing")

			expect(#store.calls).to.equal(1)
			expect(#waits).to.equal(0)
		end)

		it("writes a value", function()
			local ok = helper:Set("player-1", 7)

			expect(ok).to.equal(true)
			expect(store.data["player-1"]).to.equal(7)
		end)

		it("removes a value", function()
			store.data["player-1"] = 7

			local ok = helper:Remove("player-1")

			expect(ok).to.equal(true)
			expect(store.data["player-1"]).to.equal(nil)
		end)

		it("increments a value", function()
			local ok, value = helper:Increment("player-1", 5)

			expect(ok).to.equal(true)
			expect(value).to.equal(5)
		end)

		it("updates a value atomically", function()
			store.data["player-1"] = { coins = 1 }
			local seenCurrent

			local ok, value = helper:Update("player-1", function(current)
				seenCurrent = current
				return { coins = current.coins + 1 }
			end)

			expect(ok).to.equal(true)
			expect(seenCurrent.coins).to.equal(1)
			expect(value.coins).to.equal(2)
			expect(store.data["player-1"].coins).to.equal(2)
		end)

		it("retries a retryable failure and then succeeds", function()
			store.failures.SetAsync = 2

			local ok = helper:Set("player-1", 7)

			expect(ok).to.equal(true)
			expect(#store.calls).to.equal(3)
			expect(#waits).to.equal(2)
		end)

		it("gives up after the configured attempts", function()
			store.failures.SetAsync = 10

			local ok, _, err = helper:Set("player-1", 7)

			expect(ok).to.equal(false)
			expect(#store.calls).to.equal(3)
			expect(err).to.be.a("string")
		end)

		it("backs off exponentially up to the configured ceiling", function()
			store.failures.SetAsync = 10

			helper:Set("player-1", 7)

			expect(waits[1]).to.equal(1)
			expect(waits[2]).to.equal(2)
		end)

		it("caps the backoff at maxDelay", function()
			store.failures.SetAsync = 10
			local capped = DataStoreHelper.new(store, {
				attempts = 5,
				baseDelay = 1,
				maxDelay = 2,
				jitter = 0,
				wait = noWait,
				logger = noLog,
			})

			capped:Set("player-1", 7)

			expect(waits[3]).to.equal(2)
			expect(waits[4]).to.equal(2)
			capped:Destroy()
		end)

		it("applies jitter to delays", function()
			store.failures.SetAsync = 10
			local jittered = DataStoreHelper.new(store, {
				attempts = 2,
				baseDelay = 1,
				maxDelay = 4,
				jitter = 0.5,
				wait = noWait,
				logger = noLog,
			})

			jittered:Set("player-1", 7)

			expect(#waits).to.equal(1)
			expect(waits[1] >= 1 and waits[1] <= 1.5).to.equal(true)
			jittered:Destroy()
		end)

		it("logs the final failure", function()
			store.failures.SetAsync = 10

			helper:Set("player-1", 7)

			expect(#logs).to.equal(1)
			expect(string.find(logs[1], "request failed", 1, true) ~= nil).to.equal(true)
		end)

		it("honours a custom retryability rule", function()
			store.failures.SetAsync = 10
			local custom = DataStoreHelper.new(store, {
				attempts = 3,
				wait = noWait,
				logger = noLog,
				isRetryable = function(err: string)
					return string.find(err, "wrong", 1, true) ~= nil
				end,
			})

			custom:Set("player-1", 7)

			expect(#store.calls).to.equal(1)
			custom:Destroy()
		end)

		it("returns the value from GetOrDefault and never throws", function()
			expect(helper:GetOrDefault("missing", "fallback")).to.equal("fallback")

			store.data["player-1"] = "real"
			expect(helper:GetOrDefault("player-1", "fallback")).to.equal("real")
		end)

		it("rejects an empty key", function()
			expect(function()
				helper:Get("")
			end).to.throw()
		end)

		it("refuses to work after being destroyed", function()
			helper:Destroy()

			expect(helper:IsDestroyed()).to.equal(true)
			expect(function()
				helper:Get("player-1")
			end).to.throw()
		end)
	end)
end
