--!strict
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local ToggleEngine = t.require("ServerScriptService.Server.logic.ToggleEngine")
	local LevelLibrary = t.require("ServerScriptService.Server.logic.LevelLibrary")
	local SessionManager = t.require("ServerScriptService.Server.services.SessionManager")
	local catalog = t.require("ServerScriptService.Server.levels.Catalog")

	local entries = LevelLibrary.build(catalog)
	local ALICE, BOB = 1001, 2002

	local function fresh(floor: number?)
		local manager = SessionManager.new(#entries)
		local session = manager:start(ALICE, entries[floor or 1], 0)
		return manager, session
	end

	local function act(manager, owner: number, kind: string, extra: { [string]: any }?)
		local session = manager:get(owner)
		local request = {
			kind = kind,
			sessionId = if session then session.id else "none",
			expectedRevision = if session then session.revision else 0,
		}
		for key, value in extra or {} do
			request[key] = value
		end
		return manager:apply(owner, request, 10)
	end

	describe("SessionManager", function()
		it("starts at revision 0 with the level's initial board", function()
			local manager, session = fresh(4)
			expect(session.revision).toBe(0)
			expect(session.moves).toBe(0)
			expect(ToggleEngine.equals(session.board, entries[4].initialBoard)).toBe(true)
			local snapshot = manager:snapshot(session)
			expect(snapshot.floor).toBe(4)
			expect(snapshot.floorCount).toBe(10)
			expect(snapshot.width).toBe(4)
			expect(#snapshot.cells).toBe(16)
			expect(snapshot.solved).toBe(false)
			expect(snapshot.canUndo).toBe(false)
		end)

		it("applies a press and increments the revision", function()
			local manager, session = fresh(4)
			local outcome = act(manager, ALICE, "press", { cellIndex = 6 })
			expect(outcome.ok).toBe(true)
			expect(outcome.changed).toBe(true)
			expect(session.revision).toBe(1)
			expect(session.moves).toBe(1)
			local expected = ToggleEngine.toggle(entries[4].initialBoard, 6, "cross")
			expect(ToggleEngine.equals(session.board, expected)).toBe(true)
			expect(manager:snapshot(session).changedCells).toEqual({ 2, 5, 6, 7, 10 })
		end)

		it("solves a floor by replaying the solver's solution", function()
			local manager, session = fresh(5)
			local outcome
			for _, cell in entries[5].solution do
				outcome = act(manager, ALICE, "press", { cellIndex = cell })
				expect(outcome.ok).toBe(true)
			end
			expect(outcome.solvedNow).toBe(true)
			expect(session.result.stars).toBe(3)
			expect(session.result.moves).toBe(entries[5].parMoves)
			expect(session.result.timeSeconds).toBe(10)
			expect(manager:snapshot(session).solved).toBe(true)
		end)

		it("locks the board once solved", function()
			local manager = fresh(1)
			act(manager, ALICE, "press", { cellIndex = entries[1].solution[1] })
			expect(act(manager, ALICE, "press", { cellIndex = 1 }).error).toBe("already_solved")
			expect(act(manager, ALICE, "undo").error).toBe("already_solved")
			expect(act(manager, ALICE, "hint").error).toBe("already_solved")
		end)

		describe("rejects unsafe requests", function()
			it("without a session", function()
				local manager = SessionManager.new(10)
				local outcome =
					manager:apply(ALICE, { kind = "press", sessionId = "x", expectedRevision = 0, cellIndex = 1 }, 0)
				expect(outcome.ok).toBe(false)
				expect(outcome.error).toBe("no_session")
			end)

			it("for another session id", function()
				local manager, session = fresh()
				local outcome = manager:apply(ALICE, {
					kind = "press",
					sessionId = session.id .. "x",
					expectedRevision = 0,
					cellIndex = 1,
				}, 0)
				expect(outcome.error).toBe("wrong_session")
				expect(session.revision).toBe(0)
			end)

			it("with a stale revision", function()
				local manager, session = fresh(4)
				local request = { kind = "press", sessionId = session.id, expectedRevision = 0, cellIndex = 1 }
				expect(manager:apply(ALICE, request, 0).ok).toBe(true)
				-- The identical request again is a duplicate and must not toggle twice.
				local duplicate = manager:apply(ALICE, request, 0)
				expect(duplicate.ok).toBe(false)
				expect(duplicate.error).toBe("stale_revision")
				expect(session.moves).toBe(1)
			end)

			it("with out-of-bounds cells", function()
				local manager, session = fresh(1)
				for _, cell in { 0, 10, -3, 2.5, 0 / 0, math.huge } do
					local outcome = act(manager, ALICE, "press", { cellIndex = cell })
					expect(outcome.ok).toBe(false)
					expect(outcome.error).toBe("out_of_bounds")
				end
				expect(session.revision).toBe(0)
				expect(ToggleEngine.equals(session.board, entries[1].initialBoard)).toBe(true)
			end)

			it("with non-session kinds", function()
				local manager = fresh()
				expect(act(manager, ALICE, "start").error).toBe("bad_request")
			end)
		end)

		describe("undo", function()
			it("restores the board and move count by one step", function()
				local manager, session = fresh(4)
				act(manager, ALICE, "press", { cellIndex = 1 })
				act(manager, ALICE, "press", { cellIndex = 16 })
				local afterFirst = ToggleEngine.toggle(entries[4].initialBoard, 1, "cross")
				local outcome = act(manager, ALICE, "undo")
				expect(outcome.ok).toBe(true)
				expect(ToggleEngine.equals(session.board, afterFirst)).toBe(true)
				expect(session.moves).toBe(1)
				expect(session.revision).toBe(3)
			end)

			it("is limited to one step", function()
				local manager = fresh(4)
				act(manager, ALICE, "press", { cellIndex = 1 })
				act(manager, ALICE, "press", { cellIndex = 2 })
				expect(act(manager, ALICE, "undo").ok).toBe(true)
				expect(act(manager, ALICE, "undo").error).toBe("undo_unavailable")
			end)

			it("is unavailable before the first move", function()
				local manager = fresh(4)
				expect(act(manager, ALICE, "undo").error).toBe("undo_unavailable")
			end)

			it("respects levels that disable undo", function()
				local manager, session = fresh(10)
				expect(entries[10].level.allowUndo).toBe(false)
				act(manager, ALICE, "press", { cellIndex = 1 })
				expect(manager:snapshot(session).canUndo).toBe(false)
				expect(act(manager, ALICE, "undo").error).toBe("undo_unavailable")
			end)
		end)

		describe("reset", function()
			it("restores the initial board and is free in the tutorial", function()
				local manager, session = fresh(2)
				act(manager, ALICE, "press", { cellIndex = 5 })
				expect(act(manager, ALICE, "reset").ok).toBe(true)
				expect(ToggleEngine.equals(session.board, entries[2].initialBoard)).toBe(true)
				expect(session.moves).toBe(0)
				expect(session.resets).toBe(1)
			end)

			it("keeps counting moves outside the tutorial", function()
				local manager, session = fresh(4)
				act(manager, ALICE, "press", { cellIndex = 5 })
				act(manager, ALICE, "press", { cellIndex = 6 })
				act(manager, ALICE, "reset")
				expect(ToggleEngine.equals(session.board, entries[4].initialBoard)).toBe(true)
				expect(session.moves).toBe(2)
				expect(act(manager, ALICE, "undo").error).toBe("undo_unavailable")
			end)
		end)

		describe("hint", function()
			it("points at a cell of a minimal solution and counts once per board", function()
				local manager, session = fresh(6)
				local outcome = act(manager, ALICE, "hint")
				expect(outcome.ok).toBe(true)
				expect(session.hintsUsed).toBe(1)
				expect(table.find(entries[6].solution, session.hintCell) ~= nil).toBe(true)
				local again = act(manager, ALICE, "hint")
				expect(again.ok).toBe(true)
				expect(again.changed).toBe(false)
				expect(session.hintsUsed).toBe(1)
			end)

			it("is cleared by the next move and lowers the stars", function()
				local manager, session = fresh(1)
				act(manager, ALICE, "hint")
				local cell = session.hintCell
				act(manager, ALICE, "press", { cellIndex = cell })
				expect(session.hintCell).toBeNil()
				expect(session.result.stars).toBe(2)
			end)
		end)

		it("keeps two players' boards independent", function()
			local manager = SessionManager.new(#entries)
			local alice = manager:start(ALICE, entries[4], 0)
			local bob = manager:start(BOB, entries[4], 0)
			expect(alice.id).notToBe(bob.id)
			act(manager, ALICE, "press", { cellIndex = 1 })
			expect(alice.moves).toBe(1)
			expect(bob.moves).toBe(0)
			expect(ToggleEngine.equals(bob.board, entries[4].initialBoard)).toBe(true)
			-- Bob cannot act on Alice's session even with her id and revision.
			local outcome =
				manager:apply(BOB, { kind = "press", sessionId = alice.id, expectedRevision = 1, cellIndex = 2 }, 0)
			expect(outcome.error).toBe("wrong_session")
			expect(alice.revision).toBe(1)
		end)

		it("replaces the session on restart and forgets it on stop", function()
			local manager, first = fresh(1)
			local second = manager:start(ALICE, entries[1], 5)
			expect(second.id).notToBe(first.id)
			expect(manager:get(ALICE)).toBe(second)
			expect(manager:stop(ALICE)).toBe(second)
			expect(manager:get(ALICE)).toBeNil()
		end)
	end)
end
