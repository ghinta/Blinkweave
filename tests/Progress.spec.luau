--!strict
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local ProgressModel = t.require("ServerScriptService.Server.services.ProgressModel")
	local ProgressStore = t.require("ServerScriptService.Server.services.ProgressStore")
	local LevelLibrary = t.require("ServerScriptService.Server.logic.LevelLibrary")
	local catalog = t.require("ServerScriptService.Server.levels.Catalog")

	local entries = LevelLibrary.build(catalog)

	local function result(stars: number, moves: number, time: number)
		return { stars = stars, moves = moves, parMoves = 3, hintsUsed = 0, timeSeconds = time }
	end

	-- In-memory DataStore stand-in that can fail a number of times first.
	local function fakeAdapter(failures: number)
		local data: { [string]: any } = {}
		local calls = 0
		local adapter = {
			data = data,
			read = function(key: string): any
				calls += 1
				if calls <= failures then
					error("simulated outage")
				end
				return data[key]
			end,
			update = function(key: string, transform: (any) -> any)
				calls += 1
				if calls <= failures then
					error("simulated outage")
				end
				data[key] = transform(data[key])
			end,
		}
		return adapter
	end

	local function newStore(adapter, waits: { number }?)
		return ProgressStore.new({
			adapter = adapter,
			wait = function(seconds: number)
				if waits then
					table.insert(waits, seconds)
				end
			end,
		})
	end

	describe("ProgressModel", function()
		it("starts with floor 1 unlocked", function()
			local profile = ProgressModel.default()
			expect(profile.highestUnlocked).toBe(1)
			expect(profile.settings).toEqual({ soundOn = true, jumpToggles = true })
		end)

		it("records a first completion and unlocks the next floor", function()
			local profile, improved =
				ProgressModel.recordCompletion(ProgressModel.default(), 1, "floor_001", result(3, 1, 12), 10)
			expect(improved).toBe(true)
			expect(profile.highestUnlocked).toBe(2)
			expect(profile.levels.floor_001).toEqual({ stars = 3, bestMoves = 1, bestTime = 12, completions = 1 })
		end)

		it("keeps personal bests per field", function()
			local profile =
				ProgressModel.recordCompletion(ProgressModel.default(), 4, "floor_004", result(3, 3, 40), 10)
			local updated, improved = ProgressModel.recordCompletion(profile, 4, "floor_004", result(2, 5, 20), 10)
			expect(improved).toBe(true)
			expect(updated.levels.floor_004).toEqual({ stars = 3, bestMoves = 3, bestTime = 20, completions = 2 })
			local same, noChange = ProgressModel.recordCompletion(updated, 4, "floor_004", result(1, 9, 99), 10)
			expect(noChange).toBe(false)
			expect(same.levels.floor_004.completions).toBe(3)
		end)

		it("does not mutate the input profile", function()
			local profile = ProgressModel.default()
			ProgressModel.recordCompletion(profile, 1, "floor_001", result(3, 1, 5), 10)
			expect(profile.highestUnlocked).toBe(1)
			expect(profile.levels.floor_001).toBeNil()
		end)

		it("never unlocks beyond the last floor", function()
			local profile =
				ProgressModel.recordCompletion(ProgressModel.default(), 10, "floor_010", result(1, 20, 5), 10)
			expect(profile.highestUnlocked).toBe(10)
		end)

		it("merges monotonically", function()
			local stored = ProgressModel.sanitize({
				highestUnlocked = 6,
				levels = { floor_001 = { stars = 3, bestMoves = 1, bestTime = 30, completions = 4 } },
				settings = { soundOn = true, jumpToggles = true },
			})
			local current = ProgressModel.sanitize({
				highestUnlocked = 2,
				levels = {
					floor_001 = { stars = 2, bestMoves = 2, bestTime = 10, completions = 1 },
					floor_002 = { stars = 1, bestMoves = 7, bestTime = 50, completions = 1 },
				},
				settings = { soundOn = false, jumpToggles = true },
			})
			local merged = ProgressModel.merge(stored, current)
			expect(merged.highestUnlocked).toBe(6)
			expect(merged.levels.floor_001).toEqual({ stars = 3, bestMoves = 1, bestTime = 10, completions = 4 })
			expect(merged.levels.floor_002.stars).toBe(1)
			expect(merged.settings.soundOn).toBe(false)
		end)

		it("sanitizes corrupt or hostile data", function()
			expect(ProgressModel.sanitize(nil)).toEqual(ProgressModel.default())
			expect(ProgressModel.sanitize("garbage")).toEqual(ProgressModel.default())
			local profile = ProgressModel.sanitize({
				highestUnlocked = 0 / 0,
				levels = {
					floor_001 = { stars = 99, bestMoves = 1.7, bestTime = -4, completions = 2 },
					floor_002 = { stars = 2, bestMoves = "x", bestTime = 1, completions = 1 },
					hacked = { stars = 3, bestMoves = 1, bestTime = 1, completions = 1 },
				},
				settings = { soundOn = "loud" },
			})
			expect(profile.highestUnlocked).toBe(1)
			expect(profile.levels.floor_001).toEqual({ stars = 3, bestMoves = 1, bestTime = 0, completions = 2 })
			expect(profile.levels.floor_002).toBeNil()
			expect(profile.levels.hacked).toBeNil()
			expect(profile.settings.soundOn).toBe(true)
		end)

		it("builds the lobby view", function()
			local profile = ProgressModel.recordCompletion(ProgressModel.default(), 1, "floor_001", result(3, 1, 9), 10)
			local view = ProgressModel.view(profile, entries, "ok")
			expect(#view.floors).toBe(10)
			expect(view.highestUnlocked).toBe(2)
			expect(view.floors[1].stars).toBe(3)
			expect(view.floors[2].unlocked).toBe(true)
			expect(view.floors[3].unlocked).toBe(false)
			expect(view.floors[1].size).toBe("3x3")
		end)

		it("changes settings", function()
			local profile = ProgressModel.withSetting(ProgressModel.default(), "jumpToggles", false)
			expect(profile.settings.jumpToggles).toBe(false)
		end)
	end)

	describe("ProgressStore", function()
		it("round-trips a profile through the adapter", function()
			local adapter = fakeAdapter(0)
			local store = newStore(adapter)
			local profile = ProgressModel.recordCompletion(ProgressModel.default(), 1, "floor_001", result(3, 1, 9), 10)
			local ok = store:save(7, profile)
			expect(ok).toBe(true)
			local loaded, fromStorage = store:load(7)
			expect(fromStorage).toBe(true)
			expect(loaded).toEqual(profile)
		end)

		it("survives a reconnect with a stale local copy", function()
			local adapter = fakeAdapter(0)
			local store = newStore(adapter)
			local advanced = ProgressModel.sanitize({ highestUnlocked = 5 })
			store:save(7, advanced)
			-- A second server that loaded earlier saves an older profile.
			local _, merged = store:save(7, ProgressModel.default())
			expect(merged.highestUnlocked).toBe(5)
			expect(store:load(7).highestUnlocked).toBe(5)
		end)

		it("retries with exponential backoff", function()
			local waits = {}
			local store = newStore(fakeAdapter(2), waits)
			local _, fromStorage = store:load(7)
			expect(fromStorage).toBe(true)
			expect(waits).toEqual({ 1, 2 })
		end)

		it("falls back to a default profile when storage keeps failing", function()
			local waits = {}
			local store = newStore(fakeAdapter(100), waits)
			local profile, fromStorage = store:load(7)
			expect(fromStorage).toBe(false)
			expect(profile).toEqual(ProgressModel.default())
			expect(#waits).toBe(3)
			expect(store:save(7, profile)).toBe(false)
		end)

		it("works without a backend", function()
			local store = newStore(nil)
			expect(store:isAvailable()).toBe(false)
			local profile, fromStorage = store:load(7)
			expect(fromStorage).toBe(false)
			expect(profile.highestUnlocked).toBe(1)
			expect(store:save(7, profile)).toBe(false)
		end)

		it("uses one key per player", function()
			expect(ProgressStore.key(123)).toBe("player_123")
		end)
	end)
end
