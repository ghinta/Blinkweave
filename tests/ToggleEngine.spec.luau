--!strict
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local ToggleEngine = t.require("ServerScriptService.Server.logic.ToggleEngine")
	local LevelCodec = t.require("ServerScriptService.Server.logic.LevelCodec")

	local function board(text: string)
		return (LevelCodec.decodeBoard(text))
	end

	local function encode(b): string
		return LevelCodec.encodeBoard(b)
	end

	describe("ToggleEngine", function()
		describe("toggle (cross)", function()
			it("toggles the centre and its four neighbours on 3x3", function()
				local result = ToggleEngine.toggle(ToggleEngine.new(3, 3), 5, "cross")
				expect(encode(result)).toBe(".#./###/.#.")
			end)

			it("only toggles in-bounds neighbours at a corner", function()
				local result = ToggleEngine.toggle(ToggleEngine.new(3, 3), 1, "cross")
				expect(encode(result)).toBe("##./#../...")
				local opposite = ToggleEngine.toggle(ToggleEngine.new(3, 3), 9, "cross")
				expect(encode(opposite)).toBe(".../..#/.##")
			end)

			it("only toggles in-bounds neighbours on an edge", function()
				local result = ToggleEngine.toggle(ToggleEngine.new(3, 3), 2, "cross")
				expect(encode(result)).toBe("###/.#./...")
			end)

			it("XORs instead of setting", function()
				local result = ToggleEngine.toggle(board("###/###/###"), 5, "cross")
				expect(encode(result)).toBe("#.#/.../#.#")
			end)

			it("never wraps around rows", function()
				-- Cell 3 is the right end of row 1; cell 4 starts row 2.
				local result = ToggleEngine.toggle(ToggleEngine.new(3, 3), 3, "cross")
				expect(encode(result)).toBe(".##/..#/...")
			end)

			it("matches self + orthogonal neighbours for every cell on every size", function()
				for _, size in { { 1, 1 }, { 2, 3 }, { 3, 3 }, { 4, 4 }, { 5, 5 }, { 7, 2 } } do
					local w, h = size[1], size[2]
					for index = 1, w * h do
						local column, row = ToggleEngine.positionOf(w, index)
						local result = ToggleEngine.toggle(ToggleEngine.new(w, h), index, "cross")
						for cell = 1, w * h do
							local c, r = ToggleEngine.positionOf(w, cell)
							local distance = math.abs(c - column) + math.abs(r - row)
							expect(result.cells[cell]).toBe(distance <= 1)
						end
					end
				end
			end)

			it("pressing the same cell twice restores the board", function()
				local start = board("#..#/.##./#..#/.##.")
				for index = 1, 16 do
					local twice = ToggleEngine.toggle(ToggleEngine.toggle(start, index, "cross"), index, "cross")
					expect(ToggleEngine.equals(twice, start)).toBe(true)
				end
			end)

			it("is order independent", function()
				local start = ToggleEngine.new(5, 5)
				local a = ToggleEngine.applyAll(start, { 1, 7, 13, 25 }, "cross")
				local b = ToggleEngine.applyAll(start, { 25, 13, 1, 7 }, "cross")
				expect(ToggleEngine.equals(a, b)).toBe(true)
			end)

			it("does not mutate the input board", function()
				local start = ToggleEngine.new(3, 3)
				ToggleEngine.toggle(start, 5, "cross")
				expect(ToggleEngine.isSolved(start)).toBe(true)
				expect(table.isfrozen(start.cells)).toBe(true)
			end)

			it("rejects invalid indices", function()
				local start = ToggleEngine.new(3, 3)
				for _, index in { 0, 10, -1, 1.5, 0 / 0, math.huge } do
					expect(function()
						ToggleEngine.toggle(start, index, "cross")
					end).toThrow("out of bounds")
				end
			end)

			it("rejects unknown rules", function()
				expect(function()
					ToggleEngine.toggle(ToggleEngine.new(3, 3), 5, "diagonal" :: any)
				end).toThrow("unknown rule")
			end)
		end)

		describe("helpers", function()
			it("detects the solved state", function()
				expect(ToggleEngine.isSolved(ToggleEngine.new(4, 4))).toBe(true)
				expect(ToggleEngine.isSolved(board(".../.#./..."))).toBe(false)
			end)

			it("counts lit cells", function()
				expect(ToggleEngine.litCount(board("#.#/.#./#.#"))).toBe(5)
			end)

			it("converts between index and position", function()
				expect(ToggleEngine.indexOf(4, 3, 2)).toBe(7)
				local column, row = ToggleEngine.positionOf(4, 7)
				expect(column).toBe(3)
				expect(row).toBe(2)
			end)

			it("validates sizes", function()
				expect(ToggleEngine.isValidSize(3, 3)).toBe(true)
				expect(ToggleEngine.isValidSize(5, 5)).toBe(true)
				expect(ToggleEngine.isValidSize(0, 3)).toBe(false)
				expect(ToggleEngine.isValidSize(6, 6)).toBe(false)
				expect(ToggleEngine.isValidSize(2.5, 2)).toBe(false)
				expect(ToggleEngine.isValidSize("3", 3)).toBe(false)
			end)

			it("validates indices", function()
				local b = ToggleEngine.new(3, 3)
				expect(ToggleEngine.isValidIndex(b, 1)).toBe(true)
				expect(ToggleEngine.isValidIndex(b, 9)).toBe(true)
				expect(ToggleEngine.isValidIndex(b, 10)).toBe(false)
				expect(ToggleEngine.isValidIndex(b, "1")).toBe(false)
				expect(ToggleEngine.isValidIndex(b, nil)).toBe(false)
			end)

			it("lists changed cells", function()
				local before = ToggleEngine.new(3, 3)
				local after = ToggleEngine.toggle(before, 1, "cross")
				expect(ToggleEngine.diff(before, after)).toEqual({ 1, 2, 4 })
			end)

			it("rejects malformed cell arrays", function()
				expect(function()
					ToggleEngine.new(2, 2, { true, false })
				end).toThrow("cell count")
			end)
		end)
	end)
end
