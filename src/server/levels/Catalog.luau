--!strict
--[[
	Level catalog: data only, server-only (lives in ServerScriptService).

	Floors are played in this order. Boards are generated from the seed and
	validated by the solver at server start; parMoves is computed, never authored.
	Changing a seed or size changes the board, so bump the floor's tests too.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

type Level = Types.Level

local catalog: { Level } = {
	-- Tutorial: 3x3, one new idea per floor, reset without penalty.
	{
		id = "floor_001",
		width = 3,
		height = 3,
		rule = "cross",
		seed = 10427,
		target = "allOff",
		scrambleMoves = 1,
		allowUndo = true,
		tutorial = true,
	},
	{
		id = "floor_002",
		width = 3,
		height = 3,
		rule = "cross",
		seed = 20981,
		target = "allOff",
		scrambleMoves = 2,
		allowUndo = true,
		tutorial = true,
	},
	{
		id = "floor_003",
		width = 3,
		height = 3,
		rule = "cross",
		seed = 31337,
		target = "allOff",
		scrambleMoves = 3,
		allowUndo = true,
		tutorial = true,
	},
	-- Standard: 4x4.
	{
		id = "floor_004",
		width = 4,
		height = 4,
		rule = "cross",
		seed = 40213,
		target = "allOff",
		scrambleMoves = 3,
		allowUndo = true,
		tutorial = false,
	},
	{
		id = "floor_005",
		width = 4,
		height = 4,
		rule = "cross",
		seed = 52771,
		target = "allOff",
		scrambleMoves = 4,
		allowUndo = true,
		tutorial = false,
	},
	{
		id = "floor_006",
		width = 4,
		height = 4,
		rule = "cross",
		seed = 61909,
		target = "allOff",
		scrambleMoves = 5,
		allowUndo = true,
		tutorial = false,
	},
	{
		id = "floor_007",
		width = 4,
		height = 4,
		rule = "cross",
		seed = 73351,
		target = "allOff",
		scrambleMoves = 6,
		allowUndo = true,
		tutorial = false,
	},
	-- Advanced: 5x5; the last floor disables undo.
	{
		id = "floor_008",
		width = 5,
		height = 5,
		rule = "cross",
		seed = 81457,
		target = "allOff",
		scrambleMoves = 6,
		allowUndo = true,
		tutorial = false,
	},
	{
		id = "floor_009",
		width = 5,
		height = 5,
		rule = "cross",
		seed = 92503,
		target = "allOff",
		scrambleMoves = 8,
		allowUndo = true,
		tutorial = false,
	},
	{
		id = "floor_010",
		width = 5,
		height = 5,
		rule = "cross",
		seed = 104729,
		target = "allOff",
		scrambleMoves = 10,
		allowUndo = false,
		tutorial = false,
	},
}

return catalog
