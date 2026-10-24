--!strict
--[[
	Scoring: star rating for a solved floor.

	Stars depend on moves relative to the solver-proven par and on hints.
	Completion time is recorded as a personal best but never decides stars.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

type LevelResult = Types.LevelResult

local Scoring = {}

-- Extra moves above par that still earn two stars.
function Scoring.twoStarAllowance(parMoves: number): number
	return math.max(2, math.ceil(parMoves / 2))
end

function Scoring.stars(moves: number, parMoves: number, hintsUsed: number): number
	if hintsUsed == 0 and moves <= parMoves then
		return 3
	end
	if hintsUsed <= 1 and moves <= parMoves + Scoring.twoStarAllowance(parMoves) then
		return 2
	end
	return 1
end

function Scoring.result(moves: number, parMoves: number, hintsUsed: number, timeSeconds: number): LevelResult
	return {
		stars = Scoring.stars(moves, parMoves, hintsUsed),
		moves = moves,
		parMoves = parMoves,
		hintsUsed = hintsUsed,
		timeSeconds = math.max(0, timeSeconds),
	}
end

return Scoring
