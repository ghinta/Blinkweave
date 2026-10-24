--!strict
--[[
	Minimal Roblox module shim for headless Lune runs.

	Builds a fake DataModel from default.project.json so source modules can keep
	their normal Roblox requires (`script.Parent.X`, `game:GetService(...)`).
	Only ModuleScripts are loadable; anything touching real Roblox APIs is not
	supported here and belongs in Studio smoke tests.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

export type FakeInstance = { [any]: any }

export type Loader = {
	game: FakeInstance,
	require: (path: string) -> any,
	requireInstance: (instance: FakeInstance) -> any,
}

export type Options = {
	-- Services returned by game:GetService before the project tree is consulted.
	services: { [string]: any }?,
	-- Extra globals for every loaded module (e.g. Lune's Roblox datatypes).
	globals: { [string]: any }?,
}

type Node = {
	name: string,
	parent: Node?,
	-- Source of a ModuleScript (a .luau file or a folder's init.luau).
	source: string?,
	sourcePath: string?,
	children: { [string]: Node },
}

local MODULE_SUFFIX = ".luau"
local SCRIPT_SUFFIXES = { ".server.luau", ".client.luau" }

local function endsWith(text: string, suffix: string): boolean
	return string.sub(text, -#suffix) == suffix
end

-- Lune's fs calls yield, which is not allowed inside metamethods, so the whole
-- mapped tree is scanned and read eagerly when the loader is created.
local function scan(path: string, name: string, parent: Node?): Node
	local node: Node = { name = name, parent = parent, children = {} }
	if fs.isFile(path) then
		node.source = fs.readFile(path)
		node.sourcePath = path
		return node
	end
	assert(fs.isDir(path), `project path does not exist: {path}`)
	local initPath = path .. "/init" .. MODULE_SUFFIX
	if fs.isFile(initPath) then
		node.source = fs.readFile(initPath)
		node.sourcePath = initPath
	end
	for _, entry in fs.readDir(path) do
		local entryPath = path .. "/" .. entry
		if fs.isDir(entryPath) then
			node.children[entry] = scan(entryPath, entry, node)
		elseif endsWith(entry, MODULE_SUFFIX) and entry ~= "init" .. MODULE_SUFFIX then
			local isScript = false
			for _, suffix in SCRIPT_SUFFIXES do
				isScript = isScript or endsWith(entry, suffix)
			end
			-- Scripts are not requirable; only ModuleScripts are exposed.
			if not isScript then
				local childName = string.sub(entry, 1, -#MODULE_SUFFIX - 1)
				node.children[childName] = scan(entryPath, childName, node)
			end
		end
	end
	return node
end

local function buildTree(root: string, name: string, tree: { [string]: any }, parent: Node?): Node
	local path = tree["$path"]
	local node: Node = if path
		then scan(root .. "/" .. path, name, parent)
		else { name = name, parent = parent, children = {} }
	for key, value in tree do
		if string.sub(key, 1, 1) ~= "$" and type(value) == "table" then
			node.children[key] = buildTree(root, key, value, node)
		end
	end
	return node
end

local function findChild(node: Node, name: string): Node?
	return node.children[name]
end

local function createLoader(projectRoot: string, options: Options?): Loader
	local serviceOverrides = if options and options.services then options.services else {}
	local extraGlobals = if options and options.globals then options.globals else {}
	local project = serde.decode("json", fs.readFile(projectRoot .. "/default.project.json"))
	local rootNode = buildTree(projectRoot, "game", project.tree, nil)

	local instances: { [Node]: FakeInstance } = {}
	local moduleCache: { [string]: any } = {}
	local loading: { [string]: boolean } = {}

	local function wrap(node: Node): FakeInstance
		local existing = instances[node]
		if existing then
			return existing
		end
		local methods = {}
		function methods.FindFirstChild(_self: FakeInstance, name: string): FakeInstance?
			local child = findChild(node, name)
			return if child then wrap(child) else nil
		end
		function methods.WaitForChild(_self: FakeInstance, name: string): FakeInstance
			local child = findChild(node, name)
			assert(child, `{node.name} has no child named {name}`)
			return wrap(child)
		end
		function methods.GetService(_self: FakeInstance, name: string): any
			if serviceOverrides[name] then
				return serviceOverrides[name]
			end
			local child = findChild(node, name)
			assert(child, `service {name} is not mapped in default.project.json`)
			return wrap(child)
		end
		function methods.GetFullName(_self: FakeInstance): string
			local parts = {}
			local current: Node? = node
			while current and current.parent do
				table.insert(parts, 1, current.name)
				current = current.parent
			end
			return table.concat(parts, ".")
		end

		local instance = setmetatable({ __node = node }, {
			__index = function(_self: FakeInstance, key: string): any
				if key == "Name" then
					return node.name
				elseif key == "Parent" then
					return if node.parent then wrap(node.parent) else nil
				elseif methods[key] then
					return methods[key]
				end
				local child = findChild(node, key)
				if child then
					return wrap(child)
				end
				error(`{key} is not a valid member of {node.name}`, 2)
			end,
			__tostring = function(): string
				return node.name
			end,
		})
		instances[node] = instance
		return instance
	end

	local function requireInstance(instance: FakeInstance): any
		local node: Node? = if type(instance) == "table" then rawget(instance, "__node") else nil
		assert(node and node.source, `cannot require {tostring(instance)}: not a ModuleScript`)
		local file = node.sourcePath :: string
		if moduleCache[file] ~= nil then
			return moduleCache[file]
		end
		assert(not loading[file], `cyclic require of {file}`)
		loading[file] = true
		local environment: { [string]: any } = table.clone(extraGlobals)
		environment.script = instance
		environment.game = wrap(rootNode)
		environment.require = requireInstance
		local chunk = luau.load(node.source :: string, { debugName = file, environment = environment })
		local result = chunk()
		loading[file] = nil
		moduleCache[file] = result
		return result
	end

	-- Requires by dotted DataModel path, e.g. "ServerScriptService.Server.logic.ToggleEngine".
	local function requirePath(path: string): any
		local current = wrap(rootNode)
		for _, part in string.split(path, ".") do
			current = current[part]
		end
		return requireInstance(current)
	end

	return {
		game = wrap(rootNode),
		require = requirePath,
		requireInstance = requireInstance,
	}
end

return {
	new = createLoader,
}
