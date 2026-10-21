--!strict
--[[
	Studio smoke test for the Roblox-facing server pieces.

	Runs only in Studio when ServerScriptService has the attribute
	`BlinkweaveSmokeTest = true` (Config.SMOKE_TEST_ATTRIBUTE). It drives two
	fake owners through SessionManager + ChamberBuilder: builds chambers,
	replays the solver solutions, checks tile attributes, tags and the door,
	then removes everything again. Results are printed to the Output window.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = require(ReplicatedStorage.Shared.Protocol)
local LevelLibrary = require(script.Parent.Parent.logic.LevelLibrary)
local ChamberBuilder = require(script.Parent.Parent.world.ChamberBuilder)
local Layout = require(script.Parent.Parent.world.Layout)
local SessionManager = require(script.Parent.Parent.services.SessionManager)

type Entry = LevelLibrary.Entry

local SmokeTest = {}

-- Fake owners use negative keys so they never collide with real UserIds.
local OWNERS = { -1, -2 }
-- Slots far away from real players.
local FIRST_SLOT = 90

function SmokeTest.run(entries: { Entry })
	local failures: { string } = {}
	local function check(condition: boolean, message: string)
		if not condition then
			table.insert(failures, message)
		end
	end

	local remotes = Protocol.getRemotes()
	check(remotes.action:IsA("RemoteEvent"), "action remote missing")
	check(remotes.snapshot:IsA("RemoteEvent"), "snapshot remote missing")

	local manager = SessionManager.new(#entries)
	for ownerIndex, owner in OWNERS do
		for _, floor in { 1, #entries } do
			local entry = entries[floor]
			local session = manager:start(owner, entry, os.clock())
			local chamber = ChamberBuilder.build({
				ownerUserId = owner,
				width = entry.level.width,
				height = entry.level.height,
				origin = Layout.chamberOrigin(FIRST_SLOT + ownerIndex, floor),
				cells = session.board.cells,
			})
			check(#chamber.tiles == entry.level.width * entry.level.height, `floor {floor}: tile count`)
			check(CollectionService:HasTag(chamber.tiles[1], Protocol.TILE_TAG), `floor {floor}: tile tag`)
			check(chamber.door.CanCollide, `floor {floor}: door starts closed`)

			for _, cell in entry.solution do
				local outcome = manager:apply(owner, {
					kind = "press",
					sessionId = session.id,
					expectedRevision = session.revision,
					cellIndex = cell,
				}, os.clock())
				check(outcome.ok, `floor {floor}: press {cell} rejected ({outcome.error})`)
				ChamberBuilder.setCells(chamber, session.board.cells)
				if outcome.solvedNow then
					ChamberBuilder.setDoorOpen(chamber, true)
				end
			end

			for index, tile in chamber.tiles do
				check(
					tile:GetAttribute(Protocol.ATTR_LIT) == session.board.cells[index],
					`floor {floor}: tile {index} out of sync`
				)
				check(tile:GetAttribute(Protocol.ATTR_OWNER) == owner, `floor {floor}: tile {index} owner`)
			end
			check(session.result ~= nil, `floor {floor}: not solved by its solution`)
			check(not chamber.door.CanCollide, `floor {floor}: door did not open`)
			check(chamber.door:GetAttribute(Protocol.ATTR_OPEN) == true, `floor {floor}: door attribute`)

			ChamberBuilder.destroy(chamber)
			check(chamber.model.Parent == nil, `floor {floor}: chamber not destroyed`)
		end
	end

	-- Independent sessions: the second owner's actions never touch the first.
	local a = manager:start(OWNERS[1], entries[4], 0)
	local b = manager:start(OWNERS[2], entries[4], 0)
	manager:apply(OWNERS[1], { kind = "press", sessionId = a.id, expectedRevision = 0, cellIndex = 1 }, 0)
	check(b.revision == 0 and a.revision == 1, "sessions are not independent")
	manager:stop(OWNERS[1])
	manager:stop(OWNERS[2])

	if #failures == 0 then
		print("[Blinkweave SmokeTest] PASS")
	else
		warn(`[Blinkweave SmokeTest] FAIL ({#failures})\n  {table.concat(failures, "\n  ")}`)
	end
end

return SmokeTest
