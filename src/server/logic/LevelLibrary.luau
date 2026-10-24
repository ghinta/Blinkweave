--!strict
--[[
	LevelLibrary: turns authored level definitions into playable floors.

	Validates every definition, generates its board deterministically and
	stores the solver-computed par. Fails loudly at server start instead of
	shipping an unsolvable or malformed floor.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local ToggleEngine = require(script.Parent.ToggleEngine)
local GF2Solver = require(script.Parent.GF2Solver)
local PuzzleGenerator = require(script.Parent.PuzzleGenerator)
local LevelCodec = require(script.Parent.LevelCodec)

type Level = Types.Level
type Board = ToggleEngine.Board

export type Entry = {
	floor: number,
	level: Level,
	initialBoard: Board,
	solution: { number },
	parMoves: number,
	parIsOptimal: boolean,
}

local LevelLibrary = {}

function LevelLibrary.build(levels: { Level }): { Entry }
	local entries: { Entry } = {}
	local seenIds: { [string]: boolean } = {}
	for floor, level in levels do
		local ok, reason = LevelCodec.validateLevel(level)
		assert(ok, reason)
		assert(not seenIds[level.id], `duplicate level id {level.id}`)
		seenIds[level.id] = true

		local puzzle = PuzzleGenerator.generate({
			width = level.width,
			height = level.height,
			rule = level.rule,
			seed = level.seed,
			scrambleMoves = level.scrambleMoves,
		})
		assert(GF2Solver.isSolvable(puzzle.board, level.rule), `{level.id} is not solvable`)
		assert(not ToggleEngine.isSolved(puzzle.board), `{level.id} starts solved`)

		table.insert(entries, {
			floor = floor,
			level = level,
			initialBoard = puzzle.board,
			solution = puzzle.solution,
			parMoves = puzzle.parMoves,
			parIsOptimal = puzzle.parIsOptimal,
		})
	end
	return entries
end

return LevelLibrary
