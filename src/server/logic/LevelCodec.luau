--!strict
--[[
	LevelCodec: text serialization of boards and validation of level data.

	Board text format: rows top to bottom separated by "/", "#" = lit, "." = off.
	Example 3x3 cross in the centre: ".#./###/.#."
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local ToggleEngine = require(script.Parent.ToggleEngine)

type Board = ToggleEngine.Board
type Level = Types.Level

local LevelCodec = {}

LevelCodec.LIT = "#"
LevelCodec.OFF = "."
LevelCodec.ROW_SEPARATOR = "/"

function LevelCodec.encodeBoard(board: Board): string
	local rows = table.create(board.height, "")
	for row = 1, board.height do
		local chars = table.create(board.width, "")
		for column = 1, board.width do
			local lit = board.cells[ToggleEngine.indexOf(board.width, column, row)]
			chars[column] = if lit then LevelCodec.LIT else LevelCodec.OFF
		end
		rows[row] = table.concat(chars)
	end
	return table.concat(rows, LevelCodec.ROW_SEPARATOR)
end

-- Returns the decoded board, or nil plus a reason for malformed input.
function LevelCodec.decodeBoard(text: string): (Board?, string?)
	if type(text) ~= "string" or text == "" then
		return nil, "empty board text"
	end
	local rows = string.split(text, LevelCodec.ROW_SEPARATOR)
	local width = #rows[1]
	local cells = {}
	for rowIndex, row in rows do
		if #row ~= width then
			return nil, `row {rowIndex} has length {#row}, expected {width}`
		end
		for column = 1, width do
			local char = string.sub(row, column, column)
			if char == LevelCodec.LIT then
				table.insert(cells, true)
			elseif char == LevelCodec.OFF then
				table.insert(cells, false)
			else
				return nil, `invalid character "{char}" in row {rowIndex}`
			end
		end
	end
	if not ToggleEngine.isValidSize(width, #rows) then
		return nil, "unsupported board size"
	end
	return ToggleEngine.new(width, #rows, cells), nil
end

local function isPositiveInteger(value: unknown): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= 1
end

-- Validates the authored fields of a level definition.
function LevelCodec.validateLevel(level: Level): (boolean, string?)
	if type(level) ~= "table" then
		return false, "level must be a table"
	end
	if type(level.id) ~= "string" or not string.match(level.id, "^floor_%d%d%d$") then
		return false, "id must look like floor_001"
	end
	if not ToggleEngine.isValidSize(level.width, level.height) then
		return false, `{level.id}: invalid size`
	end
	if not ToggleEngine.isRule(level.rule) then
		return false, `{level.id}: unknown rule`
	end
	if type(level.seed) ~= "number" or level.seed % 1 ~= 0 then
		return false, `{level.id}: seed must be an integer`
	end
	if level.target ~= "allOff" then
		return false, `{level.id}: unsupported target`
	end
	if not isPositiveInteger(level.scrambleMoves) or level.scrambleMoves > level.width * level.height then
		return false, `{level.id}: scrambleMoves out of range`
	end
	if level.parMoves ~= nil then
		return false, `{level.id}: parMoves is computed by the solver and must not be authored`
	end
	if type(level.allowUndo) ~= "boolean" or type(level.tutorial) ~= "boolean" then
		return false, `{level.id}: allowUndo and tutorial must be booleans`
	end
	return true, nil
end

return LevelCodec
