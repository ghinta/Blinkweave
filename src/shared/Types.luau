--!strict
--[[
	Shared type definitions for Blinkweave.

	Everything in here is safe to replicate to clients: it contains no level
	data, only the shapes of requests, snapshots and progress views.
]]

-- Toggle pattern. The MVP ships the classic cross pattern only; new rules
-- (diagonal, row/column, blocked cells) each need their own tutorial and tests.
export type Rule = "cross"

-- Authoritative level definition (server-only data, see src/server/levels).
export type Level = {
	id: string,
	width: number,
	height: number,
	rule: Rule,
	seed: number,
	target: "allOff",
	-- Number of distinct seeded presses applied to the all-off board.
	scrambleMoves: number,
	-- Computed by the solver when the catalog is built; never hand-authored.
	parMoves: number?,
	allowUndo: boolean,
	tutorial: boolean,
}

-- "sync" asks the server to resend the current snapshot and progress.
export type ActionKind = "press" | "undo" | "reset" | "hint" | "start" | "next" | "leave" | "setting" | "sync"

export type SettingName = "soundOn" | "jumpToggles"

-- Client -> server. The client never sends board state, only intents.
export type ActionRequest = {
	kind: ActionKind,
	sessionId: string?,
	expectedRevision: number?,
	cellIndex: number?,
	floor: number?,
	setting: SettingName?,
	value: boolean?,
}

export type ErrorCode =
	"bad_request"
	| "rate_limited"
	| "no_session"
	| "wrong_session"
	| "stale_revision"
	| "out_of_bounds"
	| "already_solved"
	| "not_solved"
	| "undo_unavailable"
	| "floor_locked"
	| "unavailable"

export type LevelResult = {
	stars: number,
	moves: number,
	parMoves: number,
	hintsUsed: number,
	timeSeconds: number,
}

-- Server -> client board snapshot. Sent only to the owning player.
export type Snapshot = {
	sessionId: string,
	revision: number,
	floor: number,
	floorCount: number,
	levelId: string,
	width: number,
	height: number,
	cells: { boolean },
	moves: number,
	parMoves: number,
	solved: boolean,
	tutorial: boolean,
	allowUndo: boolean,
	canUndo: boolean,
	hintsUsed: number,
	hintCell: number?,
	-- Cells changed by the last accepted action, for client-side effects.
	changedCells: { number },
	result: LevelResult?,
}

export type Settings = {
	soundOn: boolean,
	jumpToggles: boolean,
}

export type FloorView = {
	floor: number,
	levelId: string,
	size: string,
	tutorial: boolean,
	unlocked: boolean,
	stars: number,
	bestMoves: number?,
	bestTime: number?,
	parMoves: number,
}

-- Server -> client progress overview for the lobby.
export type ProgressView = {
	highestUnlocked: number,
	floors: { FloorView },
	settings: Settings,
	persistence: "ok" | "degraded",
}

-- Server -> client notice for rejected actions or failed saves.
export type NoticeCode = ErrorCode | "save_failed"

export type Notice = {
	code: NoticeCode,
}

return {}
