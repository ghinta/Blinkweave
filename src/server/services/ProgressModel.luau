--!strict
--[[
	ProgressModel: the persisted player profile and its pure transformations.

	Profiles only ever improve: merging two copies keeps the highest unlock,
	the most stars and the best moves/time per level. That makes saves safe to
	retry and safe against a second server writing the same key.
	Only server-computed results are recorded; clients never report progress.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local LevelLibrary = require(script.Parent.Parent.logic.LevelLibrary)

type LevelResult = Types.LevelResult
type Settings = Types.Settings
type SettingName = Types.SettingName
type ProgressView = Types.ProgressView
type FloorView = Types.FloorView
type Entry = LevelLibrary.Entry

export type LevelRecord = {
	stars: number,
	bestMoves: number,
	bestTime: number,
	completions: number,
}

export type Profile = {
	version: number,
	highestUnlocked: number,
	levels: { [string]: LevelRecord },
	settings: Settings,
}

local ProgressModel = {}

ProgressModel.VERSION = 1
ProgressModel.MAX_STARS = 3

local LEVEL_ID_PATTERN = "^floor_%d%d%d$"

local function defaultSettings(): Settings
	return { soundOn = true, jumpToggles = true }
end

function ProgressModel.default(): Profile
	return {
		version = ProgressModel.VERSION,
		highestUnlocked = 1,
		levels = {},
		settings = defaultSettings(),
	}
end

local function isFinite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function finiteNumber(value: unknown, fallback: number): number
	return if isFinite(value) then value :: number else fallback
end

local function cloneRecord(record: LevelRecord): LevelRecord
	return {
		stars = record.stars,
		bestMoves = record.bestMoves,
		bestTime = record.bestTime,
		completions = record.completions,
	}
end

function ProgressModel.clone(profile: Profile): Profile
	local levels = {}
	for id, record in profile.levels do
		levels[id] = cloneRecord(record)
	end
	return {
		version = profile.version,
		highestUnlocked = profile.highestUnlocked,
		levels = levels,
		settings = { soundOn = profile.settings.soundOn, jumpToggles = profile.settings.jumpToggles },
	}
end

-- Defensive decode of stored data. Unknown or broken fields fall back to defaults.
function ProgressModel.sanitize(raw: unknown): Profile
	local profile = ProgressModel.default()
	if type(raw) ~= "table" then
		return profile
	end
	local data = raw :: { [string]: unknown }

	profile.highestUnlocked = math.max(1, math.floor(finiteNumber(data.highestUnlocked, 1)))

	local levels = data.levels
	if type(levels) == "table" then
		for id, value in levels :: { [unknown]: unknown } do
			if type(id) == "string" and string.match(id, LEVEL_ID_PATTERN) and type(value) == "table" then
				local record = value :: { [string]: unknown }
				local completions = math.floor(finiteNumber(record.completions, 0))
				-- A record without usable bests is dropped rather than guessed.
				if
					completions > 0
					and isFinite(record.stars)
					and isFinite(record.bestMoves)
					and isFinite(record.bestTime)
				then
					profile.levels[id] = {
						stars = math.clamp(math.floor(record.stars :: number), 0, ProgressModel.MAX_STARS),
						bestMoves = math.max(0, math.floor(record.bestMoves :: number)),
						bestTime = math.max(0, record.bestTime :: number),
						completions = completions,
					}
				end
			end
		end
	end

	local settings = data.settings
	if type(settings) == "table" then
		local values = settings :: { [string]: unknown }
		if type(values.soundOn) == "boolean" then
			profile.settings.soundOn = values.soundOn
		end
		if type(values.jumpToggles) == "boolean" then
			profile.settings.jumpToggles = values.jumpToggles
		end
	end

	return profile
end

-- Records a solved floor. Returns the new profile and whether anything improved.
function ProgressModel.recordCompletion(
	profile: Profile,
	floor: number,
	levelId: string,
	result: LevelResult,
	floorCount: number
): (Profile, boolean)
	local updated = ProgressModel.clone(profile)
	local previous = updated.levels[levelId]
	local improved = false

	if previous then
		improved = result.stars > previous.stars
			or result.moves < previous.bestMoves
			or result.timeSeconds < previous.bestTime
		updated.levels[levelId] = {
			stars = math.max(previous.stars, result.stars),
			bestMoves = math.min(previous.bestMoves, result.moves),
			bestTime = math.min(previous.bestTime, result.timeSeconds),
			completions = previous.completions + 1,
		}
	else
		improved = true
		updated.levels[levelId] = {
			stars = result.stars,
			bestMoves = result.moves,
			bestTime = result.timeSeconds,
			completions = 1,
		}
	end

	local unlock = math.min(floor + 1, floorCount)
	if unlock > updated.highestUnlocked then
		updated.highestUnlocked = unlock
		improved = true
	end
	return updated, improved
end

function ProgressModel.withSetting(profile: Profile, name: SettingName, value: boolean): Profile
	local updated = ProgressModel.clone(profile)
	updated.settings[name] = value
	return updated
end

-- Monotonic merge used inside UpdateAsync. Settings follow `current`.
function ProgressModel.merge(stored: Profile, current: Profile): Profile
	local merged = ProgressModel.clone(current)
	merged.highestUnlocked = math.max(stored.highestUnlocked, current.highestUnlocked)
	for id, record in stored.levels do
		local mine = merged.levels[id]
		if mine then
			merged.levels[id] = {
				stars = math.max(record.stars, mine.stars),
				bestMoves = math.min(record.bestMoves, mine.bestMoves),
				bestTime = math.min(record.bestTime, mine.bestTime),
				completions = math.max(record.completions, mine.completions),
			}
		else
			merged.levels[id] = cloneRecord(record)
		end
	end
	return merged
end

-- What the lobby shows. Unlocks are clamped to the floors that exist.
function ProgressModel.view(profile: Profile, entries: { Entry }, persistence: "ok" | "degraded"): ProgressView
	local floors: { FloorView } = {}
	local highestUnlocked = math.min(profile.highestUnlocked, #entries)
	for _, entry in entries do
		local level = entry.level
		local record = profile.levels[level.id]
		table.insert(floors, {
			floor = entry.floor,
			levelId = level.id,
			size = `{level.width}x{level.height}`,
			tutorial = level.tutorial,
			unlocked = entry.floor <= highestUnlocked,
			stars = if record then record.stars else 0,
			bestMoves = if record then record.bestMoves else nil,
			bestTime = if record then record.bestTime else nil,
			parMoves = entry.parMoves,
		})
	end
	return {
		highestUnlocked = highestUnlocked,
		floors = floors,
		settings = { soundOn = profile.settings.soundOn, jumpToggles = profile.settings.jumpToggles },
		persistence = persistence,
	}
end

return ProgressModel
