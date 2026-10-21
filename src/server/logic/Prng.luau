--!strict
--[[
	Prng: deterministic xorshift32 generator.

	Uses only bit32 shifts and XOR so the sequence is identical in Roblox and
	in headless Lune tests. Not suitable for anything security related.
]]

local Prng = {}
Prng.__index = Prng

export type Prng = typeof(setmetatable({} :: { state: number }, Prng))

-- Fallback for seeds that reduce to zero, which xorshift cannot leave.
local ZERO_SEED_REPLACEMENT = 0x9E3779B9
local WARMUP_STEPS = 8

function Prng.new(seed: number): Prng
	assert(type(seed) == "number" and seed == seed and seed % 1 == 0, "seed must be an integer")
	local state = bit32.band(seed, 0xFFFFFFFF)
	if state == 0 then
		state = ZERO_SEED_REPLACEMENT
	end
	local self = setmetatable({ state = state }, Prng)
	-- Spread neighbouring seeds apart before the first draw.
	for _ = 1, WARMUP_STEPS do
		self:nextUInt32()
	end
	return self
end

function Prng.nextUInt32(self: Prng): number
	local x = self.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.state = x
	return x
end

-- Integer in [minValue, maxValue]. The modulo bias is negligible for board sizes.
function Prng.nextInt(self: Prng, minValue: number, maxValue: number): number
	assert(maxValue >= minValue, "empty range")
	return minValue + self:nextUInt32() % (maxValue - minValue + 1)
end

return Prng
