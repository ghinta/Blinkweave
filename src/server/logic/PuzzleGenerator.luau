--!strict
--[[
	PuzzleGenerator: deterministic, solver-validated boards.

	Starts from the all-off board and applies `scrambleMoves` distinct presses
	chosen by a seeded PRNG, so every generated board is solvable by
	construction. The GF2Solver then confirms solvability and computes the par.
	Boards that come out solved, or whose minimal solution is shorter than
	`minParMoves`, are rejected and re-rolled from the same PRNG stream.
]]

local ToggleEngine = require(script.Parent.ToggleEngine)
local GF2Solver = require(script.Parent.GF2Solver)
local Prng = require(script.Parent.Prng)

type Board = ToggleEngine.Board
type Rule = ToggleEngine.Rule

export type Params = {
	width: number,
	height: number,
	rule: Rule,
	seed: number,
	scrambleMoves: number,
	-- Defaults to scrambleMoves; lower it to accept easier boards.
	minParMoves: number?,
	maxAttempts: number?,
}

export type Puzzle = {
	board: Board,
	solution: { number },
	parMoves: number,
	parIsOptimal: boolean,
	attempts: number,
}

local PuzzleGenerator = {}

PuzzleGenerator.DEFAULT_MAX_ATTEMPTS = 64

-- Partial Fisher-Yates shuffle: `count` distinct indices from 1..cellCount.
local function pickDistinct(rng: Prng.Prng, cellCount: number, count: number): { number }
	local pool = table.create(cellCount, 0)
	for index = 1, cellCount do
		pool[index] = index
	end
	for slot = 1, count do
		local swapWith = rng:nextInt(slot, cellCount)
		pool[slot], pool[swapWith] = pool[swapWith], pool[slot]
	end
	local picked = table.move(pool, 1, count, 1, {})
	table.sort(picked)
	return picked
end

function PuzzleGenerator.generate(params: Params): Puzzle
	local width, height = params.width, params.height
	local rule: Rule = params.rule
	assert(ToggleEngine.isValidSize(width, height), "invalid board size")
	assert(ToggleEngine.isRule(rule), "unknown rule")
	local cellCount = width * height
	local scrambleMoves = params.scrambleMoves
	assert(
		type(scrambleMoves) == "number" and scrambleMoves % 1 == 0 and scrambleMoves >= 1 and scrambleMoves <= cellCount,
		"scrambleMoves must be an integer in 1..cellCount"
	)
	local minParMoves = params.minParMoves or scrambleMoves
	local maxAttempts = params.maxAttempts or PuzzleGenerator.DEFAULT_MAX_ATTEMPTS

	local rng = Prng.new(params.seed)
	local best: Puzzle? = nil
	for attempt = 1, maxAttempts do
		local presses = pickDistinct(rng, cellCount, scrambleMoves)
		local board = ToggleEngine.applyAll(ToggleEngine.new(width, height), presses, rule)
		if not ToggleEngine.isSolved(board) then
			local solution = GF2Solver.solve(board, rule)
			assert(solution ~= nil, "scrambled boards are solvable by construction")
			local candidate: Puzzle = {
				board = board,
				solution = solution.presses,
				parMoves = #solution.presses,
				parIsOptimal = solution.optimal,
				attempts = attempt,
			}
			if candidate.parMoves >= minParMoves then
				return candidate
			end
			if not best or candidate.parMoves > best.parMoves then
				best = candidate
			end
		end
	end

	assert(best ~= nil, "could not generate an unsolved board")
	return best
end

return PuzzleGenerator
