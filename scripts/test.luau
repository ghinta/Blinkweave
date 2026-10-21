--!strict
--[[
	Headless test runner for pure Luau modules.

	Usage:
	  lune run scripts/test.luau            run every tests/*.spec.luau
	  lune run scripts/test.luau Solver     run specs whose file name contains "Solver"

	A spec file returns `function(t)` and uses t.describe / t.it / t.expect.
	Source modules are loaded with t.require("ServerScriptService.Server.logic.X").
	t.roblox() returns a separate loader backed by Lune's Roblox DataModel.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Loader = require("./lib/Loader")

local TESTS_DIR = "tests"
local SPEC_SUFFIX = ".spec.luau"

type Case = { name: string, run: () -> () }
type Failure = { name: string, message: string }

local function formatValue(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) == "table" then
		local parts = {}
		local count = 0
		for key, item in value do
			count += 1
			if count > 32 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, `{tostring(key)}={formatValue(item)}`)
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function expect(actual: any)
	local function fail(message: string)
		error(message, 3)
	end
	local expectation = {}
	function expectation.toBe(expected: any)
		if actual ~= expected then
			fail(`expected {formatValue(actual)} to be {formatValue(expected)}`)
		end
	end
	function expectation.notToBe(expected: any)
		if actual == expected then
			fail(`expected value not to be {formatValue(expected)}`)
		end
	end
	function expectation.toEqual(expected: any)
		if not deepEqual(actual, expected) then
			fail(`expected {formatValue(actual)} to equal {formatValue(expected)}`)
		end
	end
	function expectation.toBeNil()
		if actual ~= nil then
			fail(`expected {formatValue(actual)} to be nil`)
		end
	end
	function expectation.toBeTruthy()
		if not actual then
			fail(`expected {formatValue(actual)} to be truthy`)
		end
	end
	function expectation.toBeFalsy()
		if actual then
			fail(`expected {formatValue(actual)} to be falsy`)
		end
	end
	function expectation.toBeGreaterThan(expected: number)
		if not (actual > expected) then
			fail(`expected {formatValue(actual)} > {formatValue(expected)}`)
		end
	end
	function expectation.toBeAtMost(expected: number)
		if not (actual <= expected) then
			fail(`expected {formatValue(actual)} <= {formatValue(expected)}`)
		end
	end
	function expectation.toThrow(pattern: string?)
		local ok, err = pcall(actual)
		if ok then
			fail("expected function to throw")
		elseif pattern and not string.find(tostring(err), pattern, 1, true) then
			fail(`expected error containing {formatValue(pattern)}, got {formatValue(tostring(err))}`)
		end
	end
	return expectation
end

-- A loader backed by Lune's Roblox DataModel. Instances created by modules are
-- validated against the Roblox reflection database (property names and types).
-- Signals, physics and networking do not exist here; those need Studio.
local function robloxEnvironment()
	local dataModel = roblox.Instance.new("DataModel")
	local workspace = dataModel:GetService("Workspace")
	local collectionService = {
		AddTag = function(_self: any, instance: any, tag: string)
			instance:AddTag(tag)
		end,
		HasTag = function(_self: any, instance: any, tag: string): boolean
			return instance:HasTag(tag)
		end,
		GetTagged = function(_self: any, tag: string): { any }
			local tagged = {}
			for _, descendant in dataModel:GetDescendants() do
				if descendant:HasTag(tag) then
					table.insert(tagged, descendant)
				end
			end
			return tagged
		end,
	}
	local runService = {
		IsServer = function(): boolean
			return true
		end,
		IsClient = function(): boolean
			return false
		end,
		IsStudio = function(): boolean
			return false
		end,
	}
	local loader = Loader.new(".", {
		services = {
			Workspace = workspace,
			Lighting = dataModel:GetService("Lighting"),
			CollectionService = collectionService,
			RunService = runService,
		},
		globals = {
			Instance = roblox.Instance,
			Vector2 = roblox.Vector2,
			Vector3 = roblox.Vector3,
			CFrame = roblox.CFrame,
			Color3 = roblox.Color3,
			UDim = roblox.UDim,
			UDim2 = roblox.UDim2,
			Enum = roblox.Enum,
			workspace = workspace,
		},
	})
	return {
		require = loader.require,
		datatypes = roblox,
		dataModel = dataModel,
		workspace = workspace,
		collectionService = collectionService,
	}
end

local function collectSpecs(filter: string?): { string }
	local specs = {}
	for _, name in fs.readDir(TESTS_DIR) do
		if string.sub(name, -#SPEC_SUFFIX) == SPEC_SUFFIX and (not filter or string.find(name, filter, 1, true)) then
			table.insert(specs, TESTS_DIR .. "/" .. name)
		end
	end
	table.sort(specs)
	return specs
end

local function runSpec(path: string): (number, { Failure })
	local loader = Loader.new(".")
	local cases: { Case } = {}
	local prefix: { string } = {}

	local api = {
		expect = expect,
		require = loader.require,
		game = loader.game,
		roblox = robloxEnvironment,
		describe = function(name: string, body: () -> ())
			table.insert(prefix, name)
			body()
			table.remove(prefix)
		end,
		it = function(name: string, run: () -> ())
			local fullName = table.concat(prefix, " > ") .. (if #prefix > 0 then " > " else "") .. name
			table.insert(cases, { name = fullName, run = run })
		end,
	}

	local failures: { Failure } = {}
	local ok, err = pcall(function()
		local chunk = luau.load(fs.readFile(path), { debugName = path })
		chunk()(api)
	end)
	if not ok then
		table.insert(failures, { name = "<load>", message = tostring(err) })
		return 0, failures
	end

	for _, case in cases do
		local passed, message = xpcall(case.run, function(caught: any): string
			return debug.traceback(tostring(caught), 2)
		end)
		if not passed then
			table.insert(failures, { name = case.name, message = message })
		end
	end
	return #cases, failures
end

local filter = process.args[1]
local specs = collectSpecs(filter)
if #specs == 0 then
	print("No specs found.")
	process.exit(1)
end

local total, failed = 0, 0
local started = os.clock()
for _, path in specs do
	local count, failures = runSpec(path)
	total += count
	failed += #failures
	local status = if #failures == 0 then "PASS" else "FAIL"
	print(`{status}  {path}  ({count - #failures}/{count})`)
	for _, failure in failures do
		print(`  x {failure.name}\n    {string.gsub(failure.message, "\n", "\n    ")}`)
	end
end

print(string.format("\n%d tests, %d failed (%.2fs)", total, failed, os.clock() - started))
process.exit(if failed == 0 then 0 else 1)
