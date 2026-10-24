--!strict
--[[
	ToggleEngine: the pure board rules of Blinkweave.

	A board is a row-major array of booleans (true = lit) plus its size.
	Cell indices are 1-based: index = (row - 1) * width + column.
	Boards are treated as immutable; every operation returns a new board.

	This module must not touch Roblox instances so it can be tested headless.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

export type Rule = Types.Rule

export type Board = {
	width: number,
	height: number,
	cells: { boolean },
}

local ToggleEngine = {}

-- The GF(2) solver stores one cell per bit of a 32-bit integer.
ToggleEngine.MAX_CELLS = 32

-- {dx, dy} offsets toggled by a press, the pressed cell first.
local RULE_OFFSETS: { [Rule]: { { number } } } = {
	cross = { { 0, 0 }, { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } },
}

local function isInteger(value: unknown): boolean
	return type(value) == "number" and value == value and value % 1 == 0
end

function ToggleEngine.isRule(value: unknown): boolean
	return type(value) == "string" and RULE_OFFSETS[value :: Rule] ~= nil
end

function ToggleEngine.isValidSize(width: unknown, height: unknown): boolean
	if not isInteger(width) or not isInteger(height) then
		return false
	end
	local w = width :: number
	local h = height :: number
	return w >= 1 and h >= 1 and w * h <= ToggleEngine.MAX_CELLS
end

-- Creates a board. Without `cells` every cell starts off.
function ToggleEngine.new(width: number, height: number, cells: { boolean }?): Board
	assert(ToggleEngine.isValidSize(width, height), "invalid board size")
	local count = width * height
	local copy = table.create(count, false)
	if cells then
		assert(#cells == count, "cell count does not match board size")
		for index = 1, count do
			assert(type(cells[index]) == "boolean", "cells must be booleans")
			copy[index] = cells[index]
		end
	end
	return table.freeze({ width = width, height = height, cells = table.freeze(copy) })
end

function ToggleEngine.cellCount(board: Board): number
	return board.width * board.height
end

function ToggleEngine.isValidIndex(board: Board, index: unknown): boolean
	return isInteger(index) and (index :: number) >= 1 and (index :: number) <= board.width * board.height
end

function ToggleEngine.indexOf(width: number, column: number, row: number): number
	return (row - 1) * width + column
end

function ToggleEngine.positionOf(width: number, index: number): (number, number)
	local column = (index - 1) % width + 1
	local row = (index - column) // width + 1
	return column, row
end

-- Cells toggled by pressing `index`, the pressed cell first, then N, E, S, W.
function ToggleEngine.affectedCells(width: number, height: number, index: number, rule: Rule): { number }
	local offsets = RULE_OFFSETS[rule]
	assert(offsets ~= nil, "unknown rule")
	local column, row = ToggleEngine.positionOf(width, index)
	local result = {}
	for _, offset in offsets do
		local c = column + offset[1]
		local r = row + offset[2]
		if c >= 1 and c <= width and r >= 1 and r <= height then
			table.insert(result, ToggleEngine.indexOf(width, c, r))
		end
	end
	return result
end

-- XORs the pressed cell and its in-bounds neighbors. Errors on invalid input.
function ToggleEngine.toggle(board: Board, index: number, rule: Rule): Board
	assert(ToggleEngine.isValidIndex(board, index), "cell index out of bounds")
	local cells = table.clone(board.cells)
	for _, cell in ToggleEngine.affectedCells(board.width, board.height, index, rule) do
		cells[cell] = not cells[cell]
	end
	return table.freeze({ width = board.width, height = board.height, cells = table.freeze(cells) })
end

-- Applies presses in order.
function ToggleEngine.applyAll(board: Board, presses: { number }, rule: Rule): Board
	local result = board
	for _, index in presses do
		result = ToggleEngine.toggle(result, index, rule)
	end
	return result
end

function ToggleEngine.isSolved(board: Board): boolean
	for _, lit in board.cells do
		if lit then
			return false
		end
	end
	return true
end

function ToggleEngine.litCount(board: Board): number
	local count = 0
	for _, lit in board.cells do
		if lit then
			count += 1
		end
	end
	return count
end

function ToggleEngine.equals(a: Board, b: Board): boolean
	if a.width ~= b.width or a.height ~= b.height then
		return false
	end
	for index, lit in a.cells do
		if b.cells[index] ~= lit then
			return false
		end
	end
	return true
end

-- Indices whose state differs between two boards of the same size.
function ToggleEngine.diff(a: Board, b: Board): { number }
	assert(a.width == b.width and a.height == b.height, "boards differ in size")
	local changed = {}
	for index, lit in a.cells do
		if b.cells[index] ~= lit then
			table.insert(changed, index)
		end
	end
	return changed
end

return ToggleEngine
