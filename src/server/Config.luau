--!strict
-- Server tuning values. Gameplay rules live in the level catalog, not here.

return table.freeze({
	-- Bump the suffix only with a migration plan; old keys are not read.
	DATASTORE_NAME = "BlinkweaveProgress_v1",
	AUTOSAVE_INTERVAL = 60,
	-- DataStore allows one write per key every 6 seconds.
	SAVE_COOLDOWN = 7,
	-- Per-player action rate: burst, refill per second, cooldown in seconds.
	RATE_LIMIT = table.freeze({ capacity = 10, refillPerSecond = 8, minInterval = 0.05 }),
	-- Seconds between two touch-triggered pad activations of one player.
	PAD_DEBOUNCE = 1.5,
	-- Set this attribute on ServerScriptService in Studio to run the smoke test.
	SMOKE_TEST_ATTRIBUTE = "BlinkweaveSmokeTest",
})
