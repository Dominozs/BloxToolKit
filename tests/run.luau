--!strict
--[[
	Headless test runner for RbxToolkit.

	Runs every `tests/*.spec.luau` under Lune with no Roblox Studio involved:

		lune run tests/run.luau

	Specs are written for TestEZ, so the same files also run in Studio. This
	runner supplies the TestEZ globals plus the `game.ReplicatedStorage.RbxToolkit`
	path the specs require, mapping it onto `src/`.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local realRequire = require
local Harness = realRequire("./Harness")

-- Map `game.ReplicatedStorage.RbxToolkit.<Name>` onto `src/<Name>.luau` so the
-- specs keep the exact `require` line they use inside Roblox.
local toolkit = setmetatable({}, {
	__index = function(_self, name: string)
		return { __toolkitModule = name }
	end,
})

local gameShim = {
	ReplicatedStorage = {
		RbxToolkit = toolkit,
	},
} :: any

local function shimRequire(target: any): any
	if typeof(target) == "table" and target.__toolkitModule ~= nil then
		return realRequire("./../src/" .. target.__toolkitModule)
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

for name, value in globals do
	(getfenv(0) :: any)[name] = value
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

local specs = collectSpecs()
if #specs == 0 then
	print("no spec files found in tests/")
	process.exit(1)
end

for _, file in specs do
	local name = string.gsub(file, "%.luau$", "")
	local ok, chunk = pcall(realRequire, "./" .. name)
	if not ok then
		print(("FAIL  %s"):format(file))
		print(("      could not load: %s"):format(tostring(chunk)))
		process.exit(1)
	end

	if typeof(chunk) == "function" then
		local ran, err = pcall(chunk)
		if not ran then
			print(("FAIL  %s"):format(file))
			print(("      %s"):format(tostring(err)))
			process.exit(1)
		end
	end
end

local passed, skipped, failures = Harness.run()

for _, failure in failures do
	print(("FAIL  %s"):format(failure.name))
	for line in string.gmatch(failure.message, "[^\n]+") do
		print(("      %s"):format(line))
	end
end

print("")
print(("passed: %d  failed: %d  skipped: %d"):format(passed, #failures, skipped))

if #failures > 0 then
	process.exit(1)
end
