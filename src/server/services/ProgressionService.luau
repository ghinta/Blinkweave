--!strict
--[[
	ProgressionService: owns each player's profile while they are in the server.

	- Loads with retry/backoff; on failure play continues with an in-memory
	  profile that is merged into storage on the next successful save.
	- Saves are debounced to respect the DataStore per-key write limit and
	  retried by the autosave loop while they keep failing.
	- Only server-computed results are recorded.
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Config = require(script.Parent.Parent.Config)
local LevelLibrary = require(script.Parent.Parent.logic.LevelLibrary)
local ProgressModel = require(script.Parent.ProgressModel)
local ProgressStore = require(script.Parent.ProgressStore)

type Entry = LevelLibrary.Entry
type Profile = ProgressModel.Profile
type LevelResult = Types.LevelResult
type ProgressView = Types.ProgressView
type SettingName = Types.SettingName

type PlayerState = {
	profile: Profile,
	fromStorage: boolean,
	dirty: boolean,
	saving: boolean,
	saveQueued: boolean,
	lastSaveAt: number,
	released: boolean,
}

local ProgressionService = {}
ProgressionService.__index = ProgressionService

export type ProgressionService = typeof(setmetatable(
	{} :: {
		entries: { Entry },
		store: ProgressStore.ProgressStore,
		states: { [Player]: PlayerState },
		onSaveFailed: (player: Player) -> (),
	},
	ProgressionService
))

local function createAdapter(): ProgressStore.Adapter?
	local ok, result = pcall(function(): DataStore
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if not ok then
		warn(`[Progression] DataStore unavailable, progress is not persisted: {result}`)
		return nil
	end
	local dataStore = result :: DataStore
	return {
		read = function(key: string): unknown
			return dataStore:GetAsync(key)
		end,
		update = function(key: string, transform: (unknown) -> unknown)
			dataStore:UpdateAsync(key, function(stored: unknown): unknown
				return transform(stored)
			end)
		end,
	}
end

function ProgressionService.new(entries: { Entry }, onSaveFailed: (player: Player) -> ()): ProgressionService
	local store = ProgressStore.new({
		adapter = createAdapter(),
		wait = function(seconds: number)
			task.wait(seconds)
		end,
		warn = function(message: string)
			warn(`[Progression] {message}`)
		end,
		-- Studio without API access fails every call; do not stall joins there.
		maxAttempts = if RunService:IsStudio() then 1 else 4,
	})
	return setmetatable({
		entries = entries,
		store = store,
		states = {},
		onSaveFailed = onSaveFailed,
	}, ProgressionService)
end

-- Yields while loading. Returns false if the player left in the meantime.
function ProgressionService.load(self: ProgressionService, player: Player): boolean
	local profile, fromStorage = self.store:load(player.UserId)
	if player.Parent == nil then
		return false
	end
	self.states[player] = {
		profile = profile,
		fromStorage = fromStorage,
		dirty = false,
		saving = false,
		saveQueued = false,
		lastSaveAt = -math.huge,
		released = false,
	}
	return true
end

function ProgressionService.isLoaded(self: ProgressionService, player: Player): boolean
	return self.states[player] ~= nil
end

function ProgressionService.profile(self: ProgressionService, player: Player): Profile?
	local state = self.states[player]
	return if state then state.profile else nil
end

function ProgressionService.view(self: ProgressionService, player: Player): ProgressView?
	local state = self.states[player]
	if not state then
		return nil
	end
	local persistence: "ok" | "degraded" = if self.store:isAvailable() and state.fromStorage then "ok" else "degraded"
	return ProgressModel.view(state.profile, self.entries, persistence)
end

-- Saves now if anything changed; waits for a save already in flight. Yields.
function ProgressionService.saveNow(self: ProgressionService, player: Player)
	local state = self.states[player]
	if not state or not self.store:isAvailable() then
		return
	end
	while state.saving do
		task.wait(0.1)
	end
	if not state.dirty then
		return
	end
	state.saving = true
	state.dirty = false
	local ok, merged = self.store:save(player.UserId, state.profile)
	state.saving = false
	state.lastSaveAt = os.clock()
	if ok and merged then
		-- Adopt progress written by other servers without losing newer local changes.
		state.profile = ProgressModel.merge(merged, state.profile)
		state.fromStorage = true
		if state.dirty and not state.released then
			-- Something changed while the save was in flight.
			self:requestSave(player)
		end
	else
		-- Keep the unsaved progress; the autosave loop tries again later.
		state.dirty = true
		if not state.released then
			self.onSaveFailed(player)
		end
	end
end

-- Debounced save that respects the DataStore per-key write cooldown.
function ProgressionService.requestSave(self: ProgressionService, player: Player)
	local state = self.states[player]
	if not state then
		return
	end
	state.dirty = true
	if state.saveQueued or not self.store:isAvailable() then
		return
	end
	state.saveQueued = true
	local delay = math.max(0, state.lastSaveAt + Config.SAVE_COOLDOWN - os.clock())
	task.delay(delay, function()
		state.saveQueued = false
		self:saveNow(player)
	end)
end

function ProgressionService.recordCompletion(
	self: ProgressionService,
	player: Player,
	entry: Entry,
	result: LevelResult
): boolean
	local state = self.states[player]
	if not state then
		return false
	end
	local updated, improved =
		ProgressModel.recordCompletion(state.profile, entry.floor, entry.level.id, result, #self.entries)
	state.profile = updated
	-- Completions count even without a new best, so always persist.
	self:requestSave(player)
	return improved
end

function ProgressionService.setSetting(self: ProgressionService, player: Player, name: SettingName, value: boolean)
	local state = self.states[player]
	if not state then
		return
	end
	state.profile = ProgressModel.withSetting(state.profile, name, value)
	self:requestSave(player)
end

-- Final save when the player leaves. Yields.
function ProgressionService.release(self: ProgressionService, player: Player)
	local state = self.states[player]
	if not state then
		return
	end
	state.released = true
	self:saveNow(player)
	self.states[player] = nil
end

-- Saves every dirty profile in parallel and waits (for BindToClose).
function ProgressionService.saveAll(self: ProgressionService)
	local pending = 0
	for player in self.states do
		pending += 1
		task.spawn(function()
			self:saveNow(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

-- Periodically retries dirty profiles (e.g. after failed saves).
function ProgressionService.startAutosave(self: ProgressionService)
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for player, state in self.states do
				if state.dirty and not state.saveQueued then
					task.spawn(self.saveNow, self, player)
				end
			end
		end
	end)
end

return ProgressionService
