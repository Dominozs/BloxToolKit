-- TestEZ-style tests.
return function()
	local RateLimiter = require(game.ReplicatedStorage.RbxToolkit.RateLimiter)
	describe("RateLimiter", function()
		local now
		local limiter

		local function clock()
			return now
		end

		beforeEach(function()
			now = 0
			limiter = RateLimiter.new(2, 4, clock)
		end)

		afterEach(function()
			limiter:Destroy()
		end)

		it("rejects a non-positive rate", function()
			expect(function()
				RateLimiter.new(0)
			end).to.throw()
			expect(function()
				RateLimiter.new(-1)
			end).to.throw()
		end)

		it("starts with a full bucket", function()
			expect(limiter:Peek("player")).to.equal(4)
		end)

		it("defaults the burst to the rate", function()
			local other = RateLimiter.new(3, nil, clock)
			expect(other:Peek("player")).to.equal(3)
			other:Destroy()
		end)

		it("defaults the burst to 1 when the rate is below 1", function()
			local other = RateLimiter.new(0.5, nil, clock)
			expect(other:Peek("player")).to.equal(1)
			other:Destroy()
		end)

		it("spends one token per consume", function()
			expect(limiter:Consume("player")).to.equal(true)
			expect(limiter:Consume("player")).to.equal(true)
			expect(limiter:Peek("player")).to.equal(2)
		end)

		it("blocks once the bucket is empty", function()
			for _ = 1, 4 do
				expect(limiter:Consume("player")).to.equal(true)
			end

			expect(limiter:Consume("player")).to.equal(false)
			expect(limiter:Peek("player")).to.equal(0)
		end)

		it("refills over time", function()
			for _ = 1, 4 do
				limiter:Consume("player")
			end

			now = 1
			expect(limiter:Peek("player")).to.equal(2)
			expect(limiter:Consume("player")).to.equal(true)
		end)

		it("never refills past the burst size", function()
			for _ = 1, 4 do
				limiter:Consume("player")
			end

			now = 100
			expect(limiter:Peek("player")).to.equal(4)
		end)

		it("keeps keys independent", function()
			for _ = 1, 4 do
				limiter:Consume("a")
			end

			expect(limiter:Consume("a")).to.equal(false)
			expect(limiter:Consume("b")).to.equal(true)
		end)

		it("supports a token cost bigger than one", function()
			expect(limiter:Consume("player", 3)).to.equal(true)
			expect(limiter:Peek("player")).to.equal(1)
			expect(limiter:Consume("player", 3)).to.equal(false)
		end)

		it("reports the retry time", function()
			for _ = 1, 4 do
				limiter:Consume("player")
			end

			expect(limiter:GetRetryTime("player")).to.be.near(0.5, 1e-9)
			expect(limiter:GetRetryTime("player", 2)).to.be.near(1, 1e-9)
		end)

		it("reports zero retry time when a token is available", function()
			expect(limiter:GetRetryTime("player")).to.equal(0)
		end)

		it("reports an infinite retry time for costs above the burst", function()
			expect(limiter:GetRetryTime("player", 5)).to.equal(math.huge)
		end)

		it("resets a single key", function()
			for _ = 1, 4 do
				limiter:Consume("player")
			end

			limiter:Reset("player")
			expect(limiter:Peek("player")).to.equal(4)
		end)

		it("clears every key", function()
			limiter:Consume("a")
			limiter:Consume("b")

			limiter:Clear()

			expect(limiter:Peek("a")).to.equal(4)
			expect(limiter:Peek("b")).to.equal(4)
		end)

		it("rejects invalid costs", function()
			expect(function()
				limiter:Consume("player", 0)
			end).to.throw()
			expect(function()
				limiter:Consume("player", -1)
			end).to.throw()
		end)

		it("refuses to consume after being destroyed", function()
			limiter:Destroy()

			expect(limiter:IsDestroyed()).to.equal(true)
			expect(function()
				limiter:Consume("player")
			end).to.throw()
		end)

		it("counts buckets", function()
			limiter:Consume("a")
			limiter:Consume("b")

			expect(limiter:GetCount()).to.equal(2)
			limiter:Clear()
			expect(limiter:GetCount()).to.equal(0)
		end)

		it("sweeps full buckets", function()
			for _ = 1, 4 do
				limiter:Consume("full")
			end

			now = 2 -- fully refills "full" (rate 2/s, burst 4)
			limiter:Consume("active")

			expect(limiter:Sweep()).to.equal(1)
			expect(limiter:GetCount()).to.equal(1)
			expect(limiter:Peek("full")).to.equal(4)

			-- A full bucket swept away is indistinguishable from a fresh one.
			limiter:Consume("full")
			expect(limiter:Peek("full")).to.equal(3)
		end)
	end)
end
