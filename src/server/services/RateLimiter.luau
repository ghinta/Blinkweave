--!strict
--[[
	RateLimiter: per-key token bucket plus a minimum spacing between actions.

	Pure Luau; the caller passes the current time (os.clock() on the server).
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type Options = {
	-- Burst size.
	capacity: number,
	-- Tokens regained per second.
	refillPerSecond: number,
	-- Cooldown: minimum seconds between two accepted actions of one key.
	minInterval: number,
}

type Bucket = { tokens: number, updatedAt: number, lastAcceptedAt: number }

export type RateLimiter = typeof(setmetatable(
	{} :: {
		options: Options,
		buckets: { [number]: Bucket },
	},
	RateLimiter
))

function RateLimiter.new(options: Options): RateLimiter
	assert(options.capacity >= 1, "capacity must be at least 1")
	assert(options.refillPerSecond > 0, "refillPerSecond must be positive")
	assert(options.minInterval >= 0, "minInterval must not be negative")
	return setmetatable({ options = options, buckets = {} }, RateLimiter)
end

-- Returns true and consumes a token when the action may proceed.
function RateLimiter.allow(self: RateLimiter, key: number, now: number): boolean
	local options = self.options
	local bucket = self.buckets[key]
	if not bucket then
		bucket = { tokens = options.capacity, updatedAt = now, lastAcceptedAt = -math.huge }
		self.buckets[key] = bucket
	end

	local elapsed = math.max(0, now - bucket.updatedAt)
	bucket.tokens = math.min(options.capacity, bucket.tokens + elapsed * options.refillPerSecond)
	bucket.updatedAt = now

	if now - bucket.lastAcceptedAt < options.minInterval or bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	bucket.lastAcceptedAt = now
	return true
end

function RateLimiter.forget(self: RateLimiter, key: number)
	self.buckets[key] = nil
end

return RateLimiter
