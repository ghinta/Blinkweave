--!strict
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local ToggleEngine = t.require("ServerScriptService.Server.logic.ToggleEngine")
	local GF2Solver = t.require("ServerScriptService.Server.logic.GF2Solver")
	local PuzzleGenerator = t.require("ServerScriptService.Server.logic.PuzzleGenerator")
	local LevelCodec = t.require("ServerScriptService.Server.logic.LevelCodec")
	local Prng = t.require("ServerScriptService.Server.logic.Prng")

	describe("Prng", function()
		it("is deterministic per seed", function()
			local a, b = Prng.new(123), Prng.new(123)
			for _ = 1, 100 do
				expect(a:nextUInt32()).toBe(b:nextUInt32())
			end
		end)

		it("produces different streams for neighbouring seeds", function()
			expect(Prng.new(1):nextUInt32()).notToBe(Prng.new(2):nextUInt32())
		end)

		it("handles a zero seed and stays in range", function()
			local rng = Prng.new(0)
			for _ = 1, 1000 do
				local value = rng:nextInt(3, 7)
				expect(value >= 3 and value <= 7 and value % 1 == 0).toBe(true)
			end
		end)

		it("rejects non-integer seeds", function()
			expect(function()
				Prng.new(1.5)
			end).toThrow("integer")
		end)
	end)

	describe("PuzzleGenerator", function()
		it("generates at least 1,000 solvable, unsolved puzzles across sizes and seeds", function()
			local generated = 0
			for _, size in { 3, 4, 5 } do
				for seed = 1, 340 do
					local scramble = 1 + seed % (size * 2)
					local puzzle = PuzzleGenerator.generate({
						width = size,
						height = size,
						rule = "cross",
						seed = seed * 7919 + size,
						scrambleMoves = scramble,
						minParMoves = 1,
					})
					expect(ToggleEngine.isSolved(puzzle.board)).toBe(false)
					expect(GF2Solver.isSolvable(puzzle.board, "cross")).toBe(true)
					local solved = ToggleEngine.applyAll(puzzle.board, puzzle.solution, "cross")
					expect(ToggleEngine.isSolved(solved)).toBe(true)
					expect(puzzle.parMoves).toBe(#puzzle.solution)
					expect(puzzle.parIsOptimal).toBe(true)
					expect(puzzle.parMoves).toBeAtMost(scramble)
					generated += 1
				end
			end
			expect(generated >= 1000).toBe(true)
		end)

		it("is deterministic for the same parameters", function()
			local params = { width = 5, height = 5, rule = "cross", seed = 777, scrambleMoves = 9 }
			local a = PuzzleGenerator.generate(params)
			local b = PuzzleGenerator.generate(params)
			expect(LevelCodec.encodeBoard(a.board)).toBe(LevelCodec.encodeBoard(b.board))
			expect(a.solution).toEqual(b.solution)
		end)

		it("produces different boards for different seeds", function()
			local a = PuzzleGenerator.generate({ width = 5, height = 5, rule = "cross", seed = 1, scrambleMoves = 9 })
			local b = PuzzleGenerator.generate({ width = 5, height = 5, rule = "cross", seed = 2, scrambleMoves = 9 })
			expect(LevelCodec.encodeBoard(a.board)).notToBe(LevelCodec.encodeBoard(b.board))
		end)

		it("on 3x3 the par equals the number of scramble presses", function()
			-- 3x3 has a trivial null space, so distinct presses are the unique solution.
			for scramble = 1, 9 do
				local puzzle = PuzzleGenerator.generate({
					width = 3,
					height = 3,
					rule = "cross",
					seed = scramble,
					scrambleMoves = scramble,
				})
				expect(puzzle.parMoves).toBe(scramble)
			end
		end)

		it("re-rolls until the par reaches minParMoves", function()
			for seed = 1, 50 do
				local puzzle =
					PuzzleGenerator.generate({ width = 4, height = 4, rule = "cross", seed = seed, scrambleMoves = 6 })
				expect(puzzle.parMoves).toBe(6)
			end
		end)

		it("never returns the solved board", function()
			-- On a 2x1 board pressing both cells is a quiet pattern (every cell is
			-- toggled twice), so the only possible scramble is always rejected.
			expect(function()
				PuzzleGenerator.generate({
					width = 2,
					height = 1,
					rule = "cross",
					seed = 5,
					scrambleMoves = 2,
					maxAttempts = 4,
				})
			end).toThrow("could not generate")
		end)

		it("validates parameters", function()
			expect(function()
				PuzzleGenerator.generate({ width = 3, height = 3, rule = "cross", seed = 1, scrambleMoves = 0 })
			end).toThrow("scrambleMoves")
			expect(function()
				PuzzleGenerator.generate({ width = 9, height = 9, rule = "cross", seed = 1, scrambleMoves = 3 })
			end).toThrow("size")
		end)
	end)
end
