--!strict
--[[
	ProgressStore: loads and saves profiles with retry and exponential backoff.

	The storage backend is injected (DataStoreService in the game, a fake in
	tests). Saves go through `update` with ProgressModel.merge, so a retry or a
	concurrent server can never lower stored progress.
	Without a backend (e.g. Studio without API access) the store reports
	itself as degraded and gameplay continues with in-memory progress.
]]

local ProgressModel = require(script.Parent.ProgressModel)

type Profile = ProgressModel.Profile

export type Adapter = {
	read: (key: string) -> unknown,
	-- Must call `transform` with the stored value and persist its return value.
	update: (key: string, transform: (unknown) -> unknown) -> (),
}

export type Options = {
	adapter: Adapter?,
	wait: (seconds: number) -> (),
	warn: ((message: string) -> ())?,
	maxAttempts: number?,
	baseDelay: number?,
}

local ProgressStore = {}
ProgressStore.__index = ProgressStore

export type ProgressStore = typeof(setmetatable(
	{} :: {
		adapter: Adapter?,
		wait: (seconds: number) -> (),
		warn: (message: string) -> (),
		maxAttempts: number,
		baseDelay: number,
	},
	ProgressStore
))

function ProgressStore.new(options: Options): ProgressStore
	return setmetatable({
		adapter = options.adapter,
		wait = options.wait,
		warn = options.warn or function(_message: string) end,
		maxAttempts = options.maxAttempts or 4,
		baseDelay = options.baseDelay or 1,
	}, ProgressStore)
end

function ProgressStore.key(userId: number): string
	return `player_{userId}`
end

function ProgressStore.isAvailable(self: ProgressStore): boolean
	return self.adapter ~= nil
end

-- Runs `operation` until it succeeds or attempts run out (1s, 2s, 4s, ... between tries).
function ProgressStore.retry<T>(self: ProgressStore, label: string, operation: () -> T): (boolean, T?)
	for attempt = 1, self.maxAttempts do
		local ok, result = pcall(operation)
		if ok then
			return true, result
		end
		self.warn(`{label} failed (attempt {attempt}/{self.maxAttempts}): {result}`)
		if attempt < self.maxAttempts then
			self.wait(self.baseDelay * 2 ^ (attempt - 1))
		end
	end
	return false, nil
end

-- Returns the profile and whether it really came from storage.
function ProgressStore.load(self: ProgressStore, userId: number): (Profile, boolean)
	local adapter = self.adapter
	if not adapter then
		return ProgressModel.default(), false
	end
	local key = ProgressStore.key(userId)
	local ok, raw = self:retry(`load {key}`, function(): unknown
		return adapter.read(key)
	end)
	if not ok then
		return ProgressModel.default(), false
	end
	return ProgressModel.sanitize(raw), true
end

-- Merges `profile` into storage. Returns success and the merged profile.
function ProgressStore.save(self: ProgressStore, userId: number, profile: Profile): (boolean, Profile?)
	local adapter = self.adapter
	if not adapter then
		return false, nil
	end
	local key = ProgressStore.key(userId)
	local merged: Profile? = nil
	local ok = self:retry(`save {key}`, function(): boolean
		adapter.update(key, function(stored: unknown): unknown
			merged = ProgressModel.merge(ProgressModel.sanitize(stored), profile)
			return merged
		end)
		return true
	end)
	return ok, if ok then merged else nil
end

return ProgressStore
