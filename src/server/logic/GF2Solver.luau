--!strict
--[[
	GF2Solver: solves boards as a linear system over GF(2).

	Unknown x[j] = 1 means "press cell j once" (pressing twice cancels out).
	Row i of the system lists the presses that toggle cell i, the right-hand
	side is the current lit state. Each row is stored as a 32-bit mask.

	Every solution is the particular solution XOR a combination of null-space
	vectors. Enumerating all 2^k combinations (k = number of free variables)
	therefore yields a provably minimal press count. Above MAX_FREE_VARIABLES
	the particular solution is returned and flagged as not optimal.
]]

local ToggleEngine = require(script.Parent.ToggleEngine)

type Board = ToggleEngine.Board
type Rule = ToggleEngine.Rule

export type Solution = {
	-- Cells to press once each, ascending. Empty when the board is solved.
	presses: { number },
	-- True when no shorter solution exists.
	optimal: boolean,
}

type Reduced = {
	cellCount: number,
	particular: number,
	nullBasis: { number },
}

local GF2Solver = {}

GF2Solver.MAX_FREE_VARIABLES = 16

local function bit(index: number): number
	return bit32.lshift(1, index - 1)
end

local function popCount(mask: number): number
	local count = 0
	while mask ~= 0 do
		mask = bit32.band(mask, mask - 1)
		count += 1
	end
	return count
end

local function maskToIndices(mask: number, cellCount: number): { number }
	local indices = {}
	for index = 1, cellCount do
		if bit32.band(mask, bit(index)) ~= 0 then
			table.insert(indices, index)
		end
	end
	return indices
end

-- Gauss-Jordan elimination. Returns nil when the board has no solution.
local function reduce(board: Board, rule: Rule): Reduced?
	local width, height = board.width, board.height
	local cellCount = width * height
	assert(cellCount <= ToggleEngine.MAX_CELLS, "board too large for GF2Solver")

	local rows = table.create(cellCount, 0)
	local rhs = table.clone(board.cells)
	for press = 1, cellCount do
		for _, cell in ToggleEngine.affectedCells(width, height, press, rule) do
			rows[cell] = bit32.bor(rows[cell], bit(press))
		end
	end

	local rank = 0
	local pivotColumns: { number } = {}
	local isPivot: { [number]: boolean } = {}
	for column = 1, cellCount do
		local columnBit = bit(column)
		local pivotRow: number? = nil
		for row = rank + 1, cellCount do
			if bit32.band(rows[row], columnBit) ~= 0 then
				pivotRow = row
				break
			end
		end
		if pivotRow then
			rank += 1
			rows[rank], rows[pivotRow] = rows[pivotRow], rows[rank]
			rhs[rank], rhs[pivotRow] = rhs[pivotRow], rhs[rank]
			for row = 1, cellCount do
				if row ~= rank and bit32.band(rows[row], columnBit) ~= 0 then
					rows[row] = bit32.bxor(rows[row], rows[rank])
					rhs[row] = rhs[row] ~= rhs[rank]
				end
			end
			pivotColumns[rank] = column
			isPivot[column] = true
		end
	end

	-- Rows below the rank are all-zero; a lit right-hand side there is 0 = 1.
	for row = rank + 1, cellCount do
		if rhs[row] then
			return nil
		end
	end

	local particular = 0
	for row = 1, rank do
		if rhs[row] then
			particular = bit32.bor(particular, bit(pivotColumns[row]))
		end
	end

	local nullBasis = {}
	for free = 1, cellCount do
		if not isPivot[free] then
			local vector = bit(free)
			for row = 1, rank do
				if bit32.band(rows[row], bit(free)) ~= 0 then
					vector = bit32.bor(vector, bit(pivotColumns[row]))
				end
			end
			table.insert(nullBasis, vector)
		end
	end

	return { cellCount = cellCount, particular = particular, nullBasis = nullBasis }
end

-- Dimension of the null space: how many independent "quiet" press patterns exist.
function GF2Solver.nullity(width: number, height: number, rule: Rule): number
	local reduced = reduce(ToggleEngine.new(width, height), rule)
	assert(reduced ~= nil, "the all-off board is always solvable")
	return #reduced.nullBasis
end

function GF2Solver.isSolvable(board: Board, rule: Rule): boolean
	return reduce(board, rule) ~= nil
end

-- Returns a solution, minimal when provable, or nil when the board is unsolvable.
function GF2Solver.solve(board: Board, rule: Rule): Solution?
	local reduced = reduce(board, rule)
	if not reduced then
		return nil
	end

	local freeCount = #reduced.nullBasis
	if freeCount > GF2Solver.MAX_FREE_VARIABLES then
		return { presses = maskToIndices(reduced.particular, reduced.cellCount), optimal = false }
	end

	-- Walk all combinations in Gray-code order: one XOR per step.
	local best = reduced.particular
	local bestWeight = popCount(best)
	local candidate = reduced.particular
	for step = 1, bit32.lshift(1, freeCount) - 1 do
		local flipped = bit32.countrz(step) + 1
		candidate = bit32.bxor(candidate, reduced.nullBasis[flipped])
		local weight = popCount(candidate)
		if weight < bestWeight then
			best = candidate
			bestWeight = weight
		end
	end

	return { presses = maskToIndices(best, reduced.cellCount), optimal = true }
end

-- One useful next press (part of a minimal solution), or nil if solved/unsolvable.
function GF2Solver.hint(board: Board, rule: Rule): number?
	local solution = GF2Solver.solve(board, rule)
	if not solution then
		return nil
	end
	return solution.presses[1]
end

return GF2Solver
