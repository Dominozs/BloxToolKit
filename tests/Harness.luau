--!strict
--[[
	A TestEZ-compatible subset, implemented for headless runs under Lune.

	It provides the same globals TestEZ does - `describe`, `it`, `expect`,
	`beforeEach`, `afterEach` - so `tests/*.spec.luau` run unmodified in Lune and
	in Studio. Only the matchers the toolkit actually uses are implemented.

	Supported matchers:
		expect(value).to.equal(expected)
		expect(value).never.to.equal(expected)
		expect(value).to.be.ok()
		expect(value).to.be.a("number")
		expect(value).to.be.near(expected, epsilon)
		expect(fn).to.throw()
]]

local Harness = {}

type Hook = () -> ()
type TestCase = {
	name: string,
	callback: () -> (),
	hooks: { beforeEach: { Hook }, afterEach: { Hook } },
}
type Suite = {
	name: string,
	parent: Suite?,
	prefix: string,
	beforeEach: { Hook },
	afterEach: { Hook },
}

local root: Suite = {
	name = "",
	parent = nil,
	prefix = "",
	beforeEach = {},
	afterEach = {},
}

local current: Suite = root
local cases: { TestCase } = {}
local failures: { { name: string, message: string } } = {}
local passed = 0
local skipped = 0

local function collectHooks(suite: Suite, key: string): { Hook }
	local collected: { Hook } = {}

	local chain: { Suite } = {}
	local node: Suite? = suite
	while node ~= nil do
		table.insert(chain, 1, node)
		node = node.parent
	end

	for _, entry in chain do
		for _, hook in (entry :: any)[key] do
			table.insert(collected, hook)
		end
	end

	return collected
end

function Harness.describe(name: string, callback: () -> ())
	local suite: Suite = {
		name = name,
		parent = current,
		prefix = if current.prefix == "" then name else current.prefix .. " > " .. name,
		beforeEach = {},
		afterEach = {},
	}

	local previous = current
	current = suite
	local ok, err = pcall(callback)
	current = previous

	if not ok then
		table.insert(failures, { name = suite.prefix, message = "describe block failed: " .. tostring(err) })
	end
end

function Harness.it(name: string, callback: () -> ())
	table.insert(cases, {
		name = if current.prefix == "" then name else current.prefix .. " > " .. name,
		callback = callback,
		hooks = {
			beforeEach = collectHooks(current, "beforeEach"),
			afterEach = collectHooks(current, "afterEach"),
		},
	})
end

function Harness.beforeEach(hook: Hook)
	table.insert(current.beforeEach, hook)
end

function Harness.afterEach(hook: Hook)
	table.insert(current.afterEach, hook)
end

local function formatValue(value: any): string
	if typeof(value) == "string" then
		return string.format("%q", value)
	end

	return tostring(value)
end

local function fail(message: string)
	error(message, 3)
end

-- Builds a matcher set for `value`. `negated` flips the sense of every check.
local function buildMatchers(value: any, negated: boolean): any
	local api = {}

	local function check(condition: boolean, description: string)
		if negated then
			condition = not condition
		end

		if not condition then
			fail((if negated then "not " else "") .. description)
		end
	end

	function api.equal(expected: any)
		check(value == expected, ("expected %s, got %s"):format(formatValue(expected), formatValue(value)))
		return api
	end

	function api.a(expectedType: string)
		check(typeof(value) == expectedType, ("expected a %s, got %s"):format(expectedType, typeof(value)))
		return api
	end

	function api.near(expected: number, epsilon: number?)
		local tolerance = epsilon or 1e-6
		check(
			typeof(value) == "number" and math.abs(value - expected) <= tolerance,
			("expected %s to be near %s"):format(formatValue(value), formatValue(expected))
		)
		return api
	end

	function api.throw()
		local ok = pcall(value)
		check(not ok, "expected the function to throw")
		return api
	end

	api.be = {
		ok = function()
			check(value ~= nil and value ~= false, ("expected %s to be truthy"):format(formatValue(value)))
			return api
		end,
		a = api.a,
		near = api.near,
	}

	api.to = api

	return api
end

Harness.expect = function(value: any)
	local api = buildMatchers(value, false)
	local negated = buildMatchers(value, true)

	-- TestEZ exposes both `expect(x).to.*` and `expect(x).never.to.*`.
	api.never = { to = negated }

	return api
end

-- Runs every registered case and returns a summary.
function Harness.run(): (number, number, { { name: string, message: string } })
	passed = 0

	for _, case in cases do
		local ran = true

		for _, hook in case.hooks.beforeEach do
			local ok, err = pcall(hook)
			if not ok then
				ran = false
				table.insert(failures, { name = case.name, message = "beforeEach failed: " .. tostring(err) })
				break
			end
		end

		if ran then
			local ok, err = pcall(case.callback)
			if ok then
				passed += 1
			else
				table.insert(failures, { name = case.name, message = tostring(err) })
			end
		end

		for _, hook in case.hooks.afterEach do
			pcall(hook)
		end
	end

	return passed, skipped, failures
end

function Harness.reset()
	cases = {}
	failures = {}
	passed = 0
	skipped = 0
	root = { name = "", parent = nil, prefix = "", beforeEach = {}, afterEach = {} }
	current = root
end

Harness.failures = function()
	return failures
end

return Harness
