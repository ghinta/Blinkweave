--!strict
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local ToggleEngine = t.require("ServerScriptService.Server.logic.ToggleEngine")
	local GF2Solver = t.require("ServerScriptService.Server.logic.GF2Solver")
	local LevelCodec = t.require("ServerScriptService.Server.logic.LevelCodec")
	local LevelLibrary = t.require("ServerScriptService.Server.logic.LevelLibrary")
	local catalog = t.require("ServerScriptService.Server.levels.Catalog")

	local function validLevel(overrides: { [string]: any }?)
		local level = {
			id = "floor_042",
			width = 3,
			height = 3,
			rule = "cross",
			seed = 1,
			target = "allOff",
			scrambleMoves = 2,
			allowUndo = true,
			tutorial = false,
		}
		for key, value in overrides or {} do
			level[key] = value
		end
		return level
	end

	describe("LevelCodec", function()
		it("round-trips boards", function()
			for _, text in { "#", ".#./###/.#.", "#..#/.##./..../####", "#.#.#/...../#####/.#.#./..#.." } do
				local decoded = LevelCodec.decodeBoard(text)
				expect(decoded).toBeTruthy()
				expect(LevelCodec.encodeBoard(decoded)).toBe(text)
			end
		end)

		it("decodes row-major cells", function()
			local decoded = LevelCodec.decodeBoard("#../..#")
			expect(decoded.width).toBe(3)
			expect(decoded.height).toBe(2)
			expect(decoded.cells).toEqual({ true, false, false, false, false, true })
		end)

		it("rejects malformed text", function()
			for _, text in { "", "#./#", "#x#/...", "....../....../....../....../....../......" } do
				local decoded, reason = LevelCodec.decodeBoard(text)
				expect(decoded).toBeNil()
				expect(type(reason)).toBe("string")
			end
		end)

		it("accepts a valid level definition", function()
			expect(LevelCodec.validateLevel(validLevel())).toBe(true)
		end)

		it("rejects invalid level definitions", function()
			local cases = {
				{ id = "level1" },
				{ width = 0 },
				{ width = 6, height = 6 },
				{ rule = "diagonal" },
				{ seed = 1.5 },
				{ target = "allOn" },
				{ scrambleMoves = 0 },
				{ scrambleMoves = 10 },
				{ parMoves = 3 },
				{ allowUndo = "yes" },
				{ tutorial = 1 },
			}
			for _, overrides in cases do
				local ok, reason = LevelCodec.validateLevel(validLevel(overrides))
				expect(ok).toBe(false)
				expect(type(reason)).toBe("string")
			end
		end)
	end)

	describe("Catalog", function()
		local entries = LevelLibrary.build(catalog)

		it("contains 10 floors: 3 tutorial, 4 standard, 3 advanced", function()
			expect(#entries).toBe(10)
			local tutorials, standard, advanced = 0, 0, 0
			for _, entry in entries do
				if entry.level.tutorial then
					tutorials += 1
					expect(entry.level.width).toBe(3)
				elseif entry.level.width == 4 then
					standard += 1
				elseif entry.level.width == 5 then
					advanced += 1
				end
			end
			expect(tutorials).toBe(3)
			expect(standard).toBe(4)
			expect(advanced).toBe(3)
		end)

		it("numbers floors in order with matching ids", function()
			for floor, entry in entries do
				expect(entry.floor).toBe(floor)
				expect(entry.level.id).toBe(string.format("floor_%03d", floor))
			end
		end)

		it("puts the tutorial floors first", function()
			for floor = 1, 3 do
				expect(entries[floor].level.tutorial).toBe(true)
			end
		end)

		it("only uses the cross rule in the MVP", function()
			for _, entry in entries do
				expect(entry.level.rule).toBe("cross")
			end
		end)

		it("has unsolved, solvable boards with a proven par", function()
			for _, entry in entries do
				local board = entry.initialBoard
				expect(ToggleEngine.isSolved(board)).toBe(false)
				expect(GF2Solver.isSolvable(board, "cross")).toBe(true)
				expect(entry.parIsOptimal).toBe(true)
				expect(entry.parMoves).toBe(entry.level.scrambleMoves)
				expect(ToggleEngine.isSolved(ToggleEngine.applyAll(board, entry.solution, "cross"))).toBe(true)
			end
		end)

		it("gets harder (par never decreases within a board size)", function()
			for floor = 2, #entries do
				local previous, current = entries[floor - 1], entries[floor]
				if previous.level.width == current.level.width then
					expect(current.parMoves >= previous.parMoves).toBe(true)
				end
			end
		end)

		it("pins the generated boards so seed changes are deliberate", function()
			local expected = {
				"#../##./#..",
				"##./#.#/.##",
				".#./###/...",
				"..##/#.##/#.##/#.#.",
				"..#./.#../.###/....",
				".#.#/..../.###/#..#",
				"#.../...#/..##/.##.",
				"#..##/##.##/#####/.##../#.###",
				".##../.#.#./..##./#.#../#.#.#",
				".#..#/.#..#/.#.#./.##../.###.",
			}
			for floor, entry in entries do
				expect(LevelCodec.encodeBoard(entry.initialBoard)).toBe(expected[floor])
			end
		end)

		it("rejects duplicate ids", function()
			expect(function()
				LevelLibrary.build({ validLevel(), validLevel() })
			end).toThrow("duplicate")
		end)

		it("rejects authored par values", function()
			expect(function()
				LevelLibrary.build({ validLevel({ parMoves = 2 }) })
			end).toThrow("parMoves")
		end)
	end)
end
