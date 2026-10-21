--!strict
--[[
	RequestValidator: turns untrusted remote payloads into typed requests.

	Only known fields of the expected primitive types are copied, so extra
	keys, wrong types, NaN or oversized strings never reach game logic.
	Range checks that depend on the session (cell bounds, revision) happen in
	SessionManager; floor bounds are checked by the game service.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

type ActionRequest = Types.ActionRequest
type ActionKind = Types.ActionKind
type ErrorCode = Types.ErrorCode
type SettingName = Types.SettingName

local RequestValidator = {}

local MAX_SESSION_ID_LENGTH = 64

local KINDS: { [string]: boolean } = {
	press = true,
	undo = true,
	reset = true,
	hint = true,
	start = true,
	next = true,
	leave = true,
	setting = true,
	sync = true,
}

local SETTINGS: { [string]: boolean } = {
	soundOn = true,
	jumpToggles = true,
}

local NEEDS_SESSION: { [string]: boolean } = {
	press = true,
	undo = true,
	reset = true,
	hint = true,
}

local function isInteger(value: unknown): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and math.abs(value) < 2 ^ 31
end

function RequestValidator.parse(raw: unknown): (ActionRequest?, ErrorCode?)
	if type(raw) ~= "table" then
		return nil, "bad_request"
	end
	local payload = raw :: { [unknown]: unknown }
	local kind = payload.kind
	if type(kind) ~= "string" or not KINDS[kind] then
		return nil, "bad_request"
	end

	local request: ActionRequest = { kind = kind :: ActionKind }

	if NEEDS_SESSION[kind] then
		local sessionId = payload.sessionId
		local revision = payload.expectedRevision
		if type(sessionId) ~= "string" or #sessionId > MAX_SESSION_ID_LENGTH then
			return nil, "bad_request"
		end
		if not isInteger(revision) or (revision :: number) < 0 then
			return nil, "bad_request"
		end
		request.sessionId = sessionId
		request.expectedRevision = revision :: number
	end

	if kind == "press" then
		local cellIndex = payload.cellIndex
		if type(cellIndex) ~= "number" then
			return nil, "bad_request"
		end
		-- Non-integer or out-of-range indices are rejected by the session as out_of_bounds.
		request.cellIndex = cellIndex
	elseif kind == "start" then
		local floor = payload.floor
		if not isInteger(floor) then
			return nil, "bad_request"
		end
		request.floor = floor :: number
	elseif kind == "setting" then
		local setting = payload.setting
		local value = payload.value
		if type(setting) ~= "string" or not SETTINGS[setting] or type(value) ~= "boolean" then
			return nil, "bad_request"
		end
		request.setting = setting :: SettingName
		request.value = value
	end

	return request, nil
end

return RequestValidator
