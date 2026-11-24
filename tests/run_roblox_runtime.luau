--!strict
--[[
	Headless "real Roblox runtime" test harness.

	The toolkit checks `typeof(item) == "RBXScriptConnection"` and
	`typeof(store) == "Instance"`; those strings only exist in Roblox. Under
	Lune, `typeof` on a Lua table returns "table", so the branches that handle
	Roblox objects are dead code in a plain Lune run - and that is exactly how
	two real bugs slipped through (see CHANGELOG 0.1.1).

	This harness re-executes a module with `loadstring` + `setfenv`, replacing
	`typeof` with a Roblox-flavoured one driven by a `__robloxType` tag. That
	lets specs assert what happens in the actual engine.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local realTypeof = typeof
local realRequire = require

-- A `typeof` that behaves like Roblox: any object tagged with `__robloxType`
-- reports that string, everything else falls through to the real one.
local function robloxTypeof(value: any): string
	if type(value) == "table" or type(value) == "userdata" then
		local tagged = rawget(value, "__robloxType")
		if type(tagged) == "string" then
			return tagged
		end
	end

	return realTypeof(value)
end

-- Loads `src/<name>.luau` into a fresh environment where `typeof` is
-- robloxTypeof, then returns the module.
local function loadWithRobloxTypeof(name: string)
	local path = "src/" .. name .. ".luau"
	local source = fs.readFile(path)
	local chunk = loadstring(source, "=" .. path)
	assert(chunk ~= nil, "could not load " .. name)

	local ok, module
	if realTypeof(_G) == "table" and next(_G) == nil then
		-- Lune: the global table is empty, so an isolated environment would be
		-- missing pcall/table/assert. Swap the global `typeof` for the duration
		-- of the module load instead.
		getfenv(0).typeof = robloxTypeof
		ok, module = pcall(chunk)
		getfenv(0).typeof = realTypeof
	else
		-- Real Lua/Luau hosts with a populated _G: use a sandboxed environment.
		local env = setmetatable({ typeof = robloxTypeof }, { __index = _G })
		setfenv(chunk, env)
		ok, module = pcall(chunk)
	end

	assert(ok, ("module %s failed to load: %s"):format(name, tostring(module)))
	return module
end

local Harness = realRequire("./Harness")

-- Map `game.ReplicatedStorage.RbxToolkit.<Name>` so specs can require the same
-- module this harness prepared.
local modules = {}
local toolkit = setmetatable({}, {
	__index = function(_self, moduleName: string)
		return { __robloxHarnessModule = moduleName }
	end,
})

local gameShim = { ReplicatedStorage = { RbxToolkit = toolkit } } :: any

local function shimRequire(target: any): any
	if typeof(target) == "table" and target.__robloxHarnessModule ~= nil then
		local name = target.__robloxHarnessModule
		local prepared = modules[name]
		assert(prepared ~= nil, "module " .. name .. " was not prepared for the Roblox runtime")
		return prepared
	end

	return realRequire(target)
end

local globals: { [string]: any } = {
	describe = Harness.describe,
	it = Harness.it,
	expect = Harness.expect,
	beforeEach = Harness.beforeEach,
	afterEach = Harness.afterEach,
	game = gameShim,
	require = shimRequire,
}

for key, value in globals do
	(getfenv(0) :: any)[key] = value
end

local function collectSpecs(): { string }
	local specs: { string } = {}
	for _, entry in fs.readDir("tests") do
		if string.sub(entry, -#".spec.luau") == ".spec.luau" then
			table.insert(specs, entry)
		end
	end
	table.sort(specs)
	return specs
end

local function main(): number
	local specs = collectSpecs()
	if #specs == 0 then
		print("no spec files found in tests/")
		return 1
	end

	-- Modules under test get the Roblox `typeof`; spec files run with globals
	-- from this file (realTypeof + shims) so both sides are exercised.
	for _, name in { "Signal", "Cleaner", "Cooldown", "RateLimiter", "DataStoreHelper", "Net" } do
		local module, _env = loadWithRobloxTypeof(name)
		modules[name] = module
	end

	local loadFailures = 0
	for _, file in specs do
		local chunkName = string.gsub(file, "%.luau$", "")
		local ok, chunk = pcall(realRequire, "./" .. chunkName)
		if not ok then
			print(("FAIL  %s: %s"):format(file, tostring(chunk)))
			return 1
		end

		if typeof(chunk) == "function" then
			local ran, err = pcall(chunk)
			if not ran then
				print(("FAIL  %s: %s"):format(file, tostring(err)))
				return 1
			end
		end
	end

	local passed, _skipped, failures = Harness.run()

	for _, failure in failures do
		loadFailures += 1
		print(("FAIL  %s"):format(failure.name))
		for line in string.gmatch(failure.message, "[^\n]+") do
			print(("      %s"):format(line))
		end
	end

	print("")
	print(("passed: %d  failed: %d"):format(passed, #failures))
	return if #failures > 0 then 1 else 0
end

process.exit(main())
