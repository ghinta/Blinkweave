--!strict
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local ToggleEngine = t.require("ServerScriptService.Server.logic.ToggleEngine")
	local GF2Solver = t.require("ServerScriptService.Server.logic.GF2Solver")
	local LevelCodec = t.require("ServerScriptService.Server.logic.LevelCodec")
	local Prng = t.require("ServerScriptService.Server.logic.Prng")

	local function board(text: string)
		return (LevelCodec.decodeBoard(text))
	end

	local function popCount(mask: number): number
		local count = 0
		while mask ~= 0 do
			mask = bit32.band(mask, mask - 1)
			count += 1
		end
		return count
	end

	-- Exhaustive minimum over all 2^n press sets (Gray-code walk, bitmask
	-- arithmetic independent of the solver). Only feasible for small boards.
	local function bruteForceMinimum(start): number?
		local n = ToggleEngine.cellCount(start)
		local pressMasks = {}
		for press = 1, n do
			local mask = 0
			for _, cell in ToggleEngine.affectedCells(start.width, start.height, press, "cross") do
				mask = bit32.bor(mask, bit32.lshift(1, cell - 1))
			end
			pressMasks[press] = mask
		end
		local target = 0
		for index, lit in start.cells do
			if lit then
				target = bit32.bor(target, bit32.lshift(1, index - 1))
			end
		end
		local best: number? = if target == 0 then 0 else nil
		local pressed, effect = 0, 0
		for step = 1, bit32.lshift(1, n) - 1 do
			local flipped = bit32.countrz(step) + 1
			pressed = bit32.bxor(pressed, bit32.lshift(1, flipped - 1))
			effect = bit32.bxor(effect, pressMasks[flipped])
			if effect == target then
				local weight = popCount(pressed)
				if not best or weight < best then
					best = weight
				end
			end
		end
		return best
	end

	describe("GF2Solver", function()
		it("knows the null-space dimension of the classic sizes", function()
			expect(GF2Solver.nullity(3, 3, "cross")).toBe(0)
			expect(GF2Solver.nullity(4, 4, "cross")).toBe(4)
			expect(GF2Solver.nullity(5, 5, "cross")).toBe(2)
		end)

		it("returns an empty solution for a solved board", function()
			local solution = GF2Solver.solve(ToggleEngine.new(4, 4), "cross")
			expect(solution).toEqual({ presses = {}, optimal = true })
			expect(GF2Solver.hint(ToggleEngine.new(4, 4), "cross")).toBeNil()
		end)

		it("solves a single press", function()
			local solution = GF2Solver.solve(board(".#./###/.#."), "cross")
			expect(solution).toEqual({ presses = { 5 }, optimal = true })
		end)

		it("reports unsolvable 5x5 boards", function()
			-- A single lit corner is outside the 5x5 column space.
			local corner = board("#..../...../...../...../.....")
			expect(GF2Solver.isSolvable(corner, "cross")).toBe(false)
			expect(GF2Solver.solve(corner, "cross")).toBeNil()
			expect(GF2Solver.hint(corner, "cross")).toBeNil()
		end)

		it("solves every 3x3 board and the solution is minimal", function()
			for mask = 0, 511 do
				local cells = {}
				for index = 1, 9 do
					cells[index] = bit32.band(mask, bit32.lshift(1, index - 1)) ~= 0
				end
				local start = ToggleEngine.new(3, 3, cells)
				local solution = GF2Solver.solve(start, "cross")
				expect(solution).toBeTruthy()
				expect(ToggleEngine.isSolved(ToggleEngine.applyAll(start, solution.presses, "cross"))).toBe(true)
				expect(solution.optimal).toBe(true)
				expect(#solution.presses).toBe(bruteForceMinimum(start))
			end
		end)

		it("finds proven minima on 4x4 boards (checked by brute force)", function()
			local rng = Prng.new(4242)
			for _ = 1, 12 do
				local presses = {}
				for index = 1, 16 do
					if rng:nextInt(0, 2) == 0 then
						table.insert(presses, index)
					end
				end
				local start = ToggleEngine.applyAll(ToggleEngine.new(4, 4), presses, "cross")
				local solution = GF2Solver.solve(start, "cross")
				expect(solution.optimal).toBe(true)
				expect(#solution.presses).toBe(bruteForceMinimum(start))
				expect(#solution.presses).toBeAtMost(#presses)
			end
		end)

		it("reconstructs a valid solution for random solvable 5x5 boards", function()
			local rng = Prng.new(99)
			for _ = 1, 200 do
				local presses = {}
				for index = 1, 25 do
					if rng:nextInt(0, 1) == 1 then
						table.insert(presses, index)
					end
				end
				local start = ToggleEngine.applyAll(ToggleEngine.new(5, 5), presses, "cross")
				local solution = GF2Solver.solve(start, "cross")
				expect(solution).toBeTruthy()
				expect(solution.optimal).toBe(true)
				expect(#solution.presses).toBeAtMost(#presses)
				expect(ToggleEngine.isSolved(ToggleEngine.applyAll(start, solution.presses, "cross"))).toBe(true)
			end
		end)

		it("returns presses in ascending order without duplicates", function()
			local start = ToggleEngine.applyAll(ToggleEngine.new(5, 5), { 3, 9, 14, 22 }, "cross")
			local presses = GF2Solver.solve(start, "cross").presses
			for index = 2, #presses do
				expect(presses[index] > presses[index - 1]).toBe(true)
			end
		end)

		it("gives a hint that shortens the minimal solution by one", function()
			local start = ToggleEngine.applyAll(ToggleEngine.new(4, 4), { 2, 7, 12, 13 }, "cross")
			local before = #GF2Solver.solve(start, "cross").presses
			local hint = GF2Solver.hint(start, "cross")
			expect(hint).toBeTruthy()
			local after = #GF2Solver.solve(ToggleEngine.toggle(start, hint, "cross"), "cross").presses
			expect(after).toBe(before - 1)
		end)

		it("supports non-square boards", function()
			local start = ToggleEngine.applyAll(ToggleEngine.new(5, 3), { 1, 8, 15 }, "cross")
			local solution = GF2Solver.solve(start, "cross")
			expect(ToggleEngine.isSolved(ToggleEngine.applyAll(start, solution.presses, "cross"))).toBe(true)
		end)
	end)
end
