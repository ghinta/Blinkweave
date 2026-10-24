--!strict
--[[
	SessionManager: authoritative per-player puzzle sessions.

	Pure Luau (no Roblox APIs): time is passed in, owners are plain numeric
	keys (UserIds), so every rule can be unit-tested headless.

	Every accepted action increments the session revision. Requests must name
	the current session and revision, which rejects stale and duplicate actions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local logic = script.Parent.Parent.logic
local ToggleEngine = require(logic.ToggleEngine)
local GF2Solver = require(logic.GF2Solver)
local Scoring = require(logic.Scoring)
local LevelLibrary = require(logic.LevelLibrary)

type Board = ToggleEngine.Board
type Entry = LevelLibrary.Entry
type ActionRequest = Types.ActionRequest
type ErrorCode = Types.ErrorCode
type LevelResult = Types.LevelResult
type Snapshot = Types.Snapshot

export type Session = {
	id: string,
	ownerKey: number,
	entry: Entry,
	board: Board,
	revision: number,
	moves: number,
	hintsUsed: number,
	resets: number,
	-- State before the last accepted press; one step of undo only.
	undoState: { board: Board, moves: number }?,
	hintCell: number?,
	changedCells: { number },
	startedAt: number,
	result: LevelResult?,
}

export type Outcome = {
	ok: boolean,
	error: ErrorCode?,
	session: Session?,
	-- False when the request was valid but did not change anything.
	changed: boolean,
	solvedNow: boolean,
}

local SessionManager = {}
SessionManager.__index = SessionManager

export type SessionManager = typeof(setmetatable(
	{} :: {
		sessions: { [number]: Session },
		counter: number,
		floorCount: number,
	},
	SessionManager
))

local SESSION_ACTIONS = {
	press = true,
	undo = true,
	reset = true,
	hint = true,
}

local function reject(code: ErrorCode, session: Session?): Outcome
	return { ok = false, error = code, session = session, changed = false, solvedNow = false }
end

local function accept(session: Session, changed: boolean, solvedNow: boolean): Outcome
	return { ok = true, error = nil, session = session, changed = changed, solvedNow = solvedNow }
end

function SessionManager.new(floorCount: number): SessionManager
	return setmetatable({ sessions = {}, counter = 0, floorCount = floorCount }, SessionManager)
end

function SessionManager.isSessionAction(kind: string): boolean
	return SESSION_ACTIONS[kind] == true
end

-- Starts (or restarts) a floor for an owner, replacing any previous session.
function SessionManager.start(self: SessionManager, ownerKey: number, entry: Entry, now: number): Session
	self.counter += 1
	local session: Session = {
		id = `{ownerKey}-{self.counter}`,
		ownerKey = ownerKey,
		entry = entry,
		board = entry.initialBoard,
		revision = 0,
		moves = 0,
		hintsUsed = 0,
		resets = 0,
		undoState = nil,
		hintCell = nil,
		changedCells = {},
		startedAt = now,
		result = nil,
	}
	self.sessions[ownerKey] = session
	return session
end

function SessionManager.get(self: SessionManager, ownerKey: number): Session?
	return self.sessions[ownerKey]
end

function SessionManager.stop(self: SessionManager, ownerKey: number): Session?
	local session = self.sessions[ownerKey]
	self.sessions[ownerKey] = nil
	return session
end

local function press(session: Session, cellIndex: number?, now: number): Outcome
	if not ToggleEngine.isValidIndex(session.board, cellIndex) then
		return reject("out_of_bounds", session)
	end
	local index = cellIndex :: number
	local before = session.board
	session.undoState = { board = before, moves = session.moves }
	session.board = ToggleEngine.toggle(before, index, session.entry.level.rule)
	session.moves += 1
	session.hintCell = nil
	session.changedCells = ToggleEngine.diff(before, session.board)
	session.revision += 1

	if ToggleEngine.isSolved(session.board) then
		session.undoState = nil
		session.result =
			Scoring.result(session.moves, session.entry.parMoves, session.hintsUsed, now - session.startedAt)
		return accept(session, true, true)
	end
	return accept(session, true, false)
end

local function undo(session: Session): Outcome
	local undoState = session.undoState
	if not session.entry.level.allowUndo or not undoState then
		return reject("undo_unavailable", session)
	end
	session.changedCells = ToggleEngine.diff(session.board, undoState.board)
	session.board = undoState.board
	session.moves = undoState.moves
	session.undoState = nil
	session.hintCell = nil
	session.revision += 1
	return accept(session, true, false)
end

local function reset(session: Session): Outcome
	local initial = session.entry.initialBoard
	session.changedCells = ToggleEngine.diff(session.board, initial)
	session.board = initial
	session.undoState = nil
	session.hintCell = nil
	session.resets += 1
	-- Tutorial resets are free; elsewhere the move counter keeps running.
	if session.entry.level.tutorial then
		session.moves = 0
	end
	session.revision += 1
	return accept(session, true, false)
end

local function hint(session: Session): Outcome
	if session.hintCell then
		-- Asking again for the same board neither costs nor changes anything.
		return accept(session, false, false)
	end
	local cell = GF2Solver.hint(session.board, session.entry.level.rule)
	if not cell then
		return reject("unavailable", session)
	end
	session.hintCell = cell
	session.hintsUsed += 1
	session.changedCells = {}
	session.revision += 1
	return accept(session, true, false)
end

-- Applies a parsed session action (press/undo/reset/hint) for an owner.
function SessionManager.apply(self: SessionManager, ownerKey: number, request: ActionRequest, now: number): Outcome
	local session = self.sessions[ownerKey]
	if not session then
		return reject("no_session", nil)
	end
	if not SESSION_ACTIONS[request.kind] then
		return reject("bad_request", session)
	end
	if request.sessionId ~= session.id then
		return reject("wrong_session", session)
	end
	if request.expectedRevision ~= session.revision then
		return reject("stale_revision", session)
	end
	if session.result then
		return reject("already_solved", session)
	end

	if request.kind == "press" then
		return press(session, request.cellIndex, now)
	elseif request.kind == "undo" then
		return undo(session)
	elseif request.kind == "reset" then
		return reset(session)
	end
	return hint(session)
end

function SessionManager.snapshot(self: SessionManager, session: Session): Snapshot
	local level = session.entry.level
	return {
		sessionId = session.id,
		revision = session.revision,
		floor = session.entry.floor,
		floorCount = self.floorCount,
		levelId = level.id,
		width = level.width,
		height = level.height,
		cells = table.clone(session.board.cells),
		moves = session.moves,
		parMoves = session.entry.parMoves,
		solved = session.result ~= nil,
		tutorial = level.tutorial,
		allowUndo = level.allowUndo,
		canUndo = level.allowUndo and session.undoState ~= nil,
		hintsUsed = session.hintsUsed,
		hintCell = session.hintCell,
		changedCells = table.clone(session.changedCells),
		result = session.result,
	}
end

return SessionManager
