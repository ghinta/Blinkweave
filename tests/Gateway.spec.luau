--!strict
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local RequestValidator = t.require("ServerScriptService.Server.services.RequestValidator")
	local RateLimiter = t.require("ServerScriptService.Server.services.RateLimiter")

	describe("RequestValidator", function()
		it("accepts a well-formed press", function()
			local request, code =
				RequestValidator.parse({ kind = "press", sessionId = "1-1", expectedRevision = 3, cellIndex = 4 })
			expect(code).toBeNil()
			expect(request).toEqual({ kind = "press", sessionId = "1-1", expectedRevision = 3, cellIndex = 4 })
		end)

		it("strips unknown fields", function()
			local request = RequestValidator.parse({
				kind = "undo",
				sessionId = "1-1",
				expectedRevision = 0,
				cells = { true },
				moves = 0,
				solved = true,
			})
			expect(request).toEqual({ kind = "undo", sessionId = "1-1", expectedRevision = 0 })
		end)

		it("parses lobby and setting actions", function()
			expect(RequestValidator.parse({ kind = "start", floor = 3 })).toEqual({ kind = "start", floor = 3 })
			expect(RequestValidator.parse({ kind = "next" })).toEqual({ kind = "next" })
			expect(RequestValidator.parse({ kind = "sync", floor = 9 })).toEqual({ kind = "sync" })
			expect(RequestValidator.parse({ kind = "setting", setting = "soundOn", value = false })).toEqual({
				kind = "setting",
				setting = "soundOn",
				value = false,
			})
		end)

		it("rejects malformed payloads", function()
			expect(RequestValidator.parse(nil)).toBeNil()
			local cases = {
				42,
				"press",
				{},
				{ kind = "explode" },
				{ kind = "press", sessionId = "1-1", expectedRevision = 0 },
				{ kind = "press", sessionId = "1-1", expectedRevision = 0, cellIndex = "4" },
				{ kind = "press", sessionId = 11, expectedRevision = 0, cellIndex = 4 },
				{ kind = "press", sessionId = string.rep("a", 65), expectedRevision = 0, cellIndex = 4 },
				{ kind = "undo", sessionId = "1-1", expectedRevision = -1 },
				{ kind = "undo", sessionId = "1-1", expectedRevision = 0.5 },
				{ kind = "undo", sessionId = "1-1", expectedRevision = 0 / 0 },
				{ kind = "start", floor = "1" },
				{ kind = "start", floor = 1.5 },
				{ kind = "setting", setting = "admin", value = true },
				{ kind = "setting", setting = "soundOn", value = "off" },
			}
			for _, payload in cases do
				local request, code = RequestValidator.parse(payload)
				expect(request).toBeNil()
				expect(code).toBe("bad_request")
			end
		end)
	end)

	describe("RateLimiter", function()
		local function limiter()
			return RateLimiter.new({ capacity = 3, refillPerSecond = 2, minInterval = 0.1 })
		end

		it("allows a burst up to the capacity", function()
			local rl = limiter()
			expect(rl:allow(1, 0.0)).toBe(true)
			expect(rl:allow(1, 0.2)).toBe(true)
			expect(rl:allow(1, 0.4)).toBe(true)
			expect(rl:allow(1, 0.45)).toBe(false)
		end)

		it("enforces the cooldown between actions", function()
			local rl = limiter()
			expect(rl:allow(1, 1.0)).toBe(true)
			expect(rl:allow(1, 1.05)).toBe(false)
			expect(rl:allow(1, 1.11)).toBe(true)
		end)

		it("rejects rapid-fire spam and recovers over time", function()
			local rl = limiter()
			local accepted = 0
			for step = 0, 99 do
				if rl:allow(1, step * 0.01) then
					accepted += 1
				end
			end
			-- One second of spam: the burst plus about two refilled tokens.
			expect(accepted).toBeAtMost(5)
			expect(rl:allow(1, 10)).toBe(true)
		end)

		it("tracks keys independently", function()
			local rl = limiter()
			for _ = 1, 3 do
				rl:allow(1, 0)
			end
			expect(rl:allow(2, 0)).toBe(true)
		end)

		it("forgets keys", function()
			local rl = limiter()
			rl:allow(1, 0)
			rl:forget(1)
			expect(rl:allow(1, 0.01)).toBe(true)
		end)
	end)
end
