--!strict
--[[
	Prints every catalog floor with its generated board, par and solution.

	Usage: lune run scripts/levels.luau
]]

local Loader = require("./lib/Loader")

local loader = Loader.new(".")
local LevelLibrary = loader.require("ServerScriptService.Server.logic.LevelLibrary")
local LevelCodec = loader.require("ServerScriptService.Server.logic.LevelCodec")
local catalog = loader.require("ServerScriptService.Server.levels.Catalog")

for _, entry in LevelLibrary.build(catalog) do
	local level = entry.level
	local kind = if level.tutorial then "tutorial" else "standard"
	print(
		string.format(
			"%2d  %s  %dx%d  %-8s  par %2d%s  undo %-5s  %s",
			entry.floor,
			level.id,
			level.width,
			level.height,
			kind,
			entry.parMoves,
			if entry.parIsOptimal then " (optimal)" else "",
			tostring(level.allowUndo),
			LevelCodec.encodeBoard(entry.initialBoard)
		)
	)
	print(`    solution: {table.concat(entry.solution, ", ")}`)
end
