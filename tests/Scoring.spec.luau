--!strict
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Scoring = t.require("ServerScriptService.Server.logic.Scoring")

	describe("Scoring", function()
		it("gives three stars for par without hints", function()
			expect(Scoring.stars(4, 4, 0)).toBe(3)
		end)

		it("drops to two stars for a few extra moves or one hint", function()
			expect(Scoring.stars(5, 4, 0)).toBe(2)
			expect(Scoring.stars(4, 4, 1)).toBe(2)
			expect(Scoring.stars(6, 4, 1)).toBe(2)
		end)

		it("allows at least two extra moves for two stars", function()
			expect(Scoring.twoStarAllowance(1)).toBe(2)
			expect(Scoring.stars(3, 1, 0)).toBe(2)
			expect(Scoring.stars(4, 1, 0)).toBe(1)
		end)

		it("scales the allowance with the par", function()
			expect(Scoring.twoStarAllowance(10)).toBe(5)
			expect(Scoring.stars(15, 10, 0)).toBe(2)
			expect(Scoring.stars(16, 10, 0)).toBe(1)
		end)

		it("gives one star with two or more hints", function()
			expect(Scoring.stars(4, 4, 2)).toBe(1)
		end)

		it("does not use time for stars", function()
			local fast = Scoring.result(4, 4, 0, 3)
			local slow = Scoring.result(4, 4, 0, 3000)
			expect(fast.stars).toBe(slow.stars)
		end)

		it("clamps negative durations", function()
			expect(Scoring.result(1, 1, 0, -5).timeSeconds).toBe(0)
		end)
	end)
end
