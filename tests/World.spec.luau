--!strict
-- Builds the lobby, chambers and UI helpers inside Lune's Roblox DataModel, which
-- rejects unknown properties and wrong value types. Behaviour that needs signals,
-- physics or networking is covered by the Studio smoke test instead.
return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local env = t.roblox()
	local UDim2, Enum = env.datatypes.UDim2, env.datatypes.Enum
	local Protocol = env.require("ReplicatedStorage.Shared.Protocol")
	local Layout = env.require("ServerScriptService.Server.world.Layout")
	local ChamberBuilder = env.require("ServerScriptService.Server.world.ChamberBuilder")
	local LobbyBuilder = env.require("ServerScriptService.Server.world.LobbyBuilder")
	local LevelLibrary = env.require("ServerScriptService.Server.logic.LevelLibrary")
	local catalog = env.require("ServerScriptService.Server.levels.Catalog")
	local Ui = env.require("StarterPlayer.StarterPlayerScripts.Client.Ui")

	local entries = LevelLibrary.build(catalog)

	describe("LobbyBuilder", function()
		it("builds the lobby with spawn, tower and a tagged start pad", function()
			local lobby = LobbyBuilder.build()
			expect(lobby.model.Parent).toBe(env.workspace)
			expect(lobby.model:FindFirstChild("LobbySpawn").ClassName).toBe("SpawnLocation")
			expect(lobby.model:FindFirstChild("Tower")).toBeTruthy()
			expect(env.collectionService:HasTag(lobby.startPad, Protocol.START_PAD_TAG)).toBe(true)
			expect(env.dataModel:GetService("Lighting"):FindFirstChildOfClass("Atmosphere")).toBeTruthy()
		end)
	end)

	describe("ChamberBuilder", function()
		for _, floor in { 1, 4, 10 } do
			local entry = entries[floor]
			local level = entry.level
			it(`builds floor {floor} ({level.width}x{level.height}) with tagged, attributed tiles`, function()
				local chamber = ChamberBuilder.build({
					ownerUserId = 42,
					width = level.width,
					height = level.height,
					origin = Layout.chamberOrigin(2, floor),
					cells = entry.initialBoard.cells,
				})
				expect(chamber.model.Parent).toBe(env.workspace)
				expect(#chamber.tiles).toBe(level.width * level.height)
				for index, tile in chamber.tiles do
					expect(tile:GetAttribute(Protocol.ATTR_CELL)).toBe(index)
					expect(tile:GetAttribute(Protocol.ATTR_OWNER)).toBe(42)
					expect(tile:GetAttribute(Protocol.ATTR_LIT)).toBe(entry.initialBoard.cells[index])
					expect(env.collectionService:HasTag(tile, Protocol.TILE_TAG)).toBe(true)
				end
				expect(env.collectionService:HasTag(chamber.door, Protocol.DOOR_TAG)).toBe(true)
				expect(chamber.door.CanCollide).toBe(true)
				expect(chamber.door:GetAttribute(Protocol.ATTR_OPEN)).toBe(false)
				ChamberBuilder.destroy(chamber)
			end)
		end

		it("lays out row 1 to the north and columns west to east", function()
			local chamber = ChamberBuilder.build({
				ownerUserId = 1,
				width = 3,
				height = 3,
				origin = Layout.chamberOrigin(1, 1),
				cells = table.create(9, false),
			})
			local first, last = chamber.tiles[1].Position, chamber.tiles[9].Position
			expect(first.X < last.X).toBe(true)
			expect(first.Z < last.Z).toBe(true)
			-- The door sits north of every tile and the entry south of them.
			expect(chamber.door.Position.Z < first.Z).toBe(true)
			expect(chamber.entryCFrame.Position.Z > last.Z).toBe(true)
			ChamberBuilder.destroy(chamber)
		end)

		it("mirrors cell updates and opens the door", function()
			local chamber = ChamberBuilder.build({
				ownerUserId = 7,
				width = 3,
				height = 3,
				origin = Layout.chamberOrigin(3, 2),
				cells = table.create(9, false),
			})
			local cells = table.create(9, false)
			cells[5] = true
			ChamberBuilder.setCells(chamber, cells)
			expect(chamber.tiles[5]:GetAttribute(Protocol.ATTR_LIT)).toBe(true)
			expect(chamber.tiles[4]:GetAttribute(Protocol.ATTR_LIT)).toBe(false)
			ChamberBuilder.setDoorOpen(chamber, true)
			expect(chamber.door.CanCollide).toBe(false)
			expect(chamber.door:GetAttribute(Protocol.ATTR_OPEN)).toBe(true)
			ChamberBuilder.destroy(chamber)
			expect(chamber.model.Parent).toBeNil()
		end)
	end)

	describe("Layout", function()
		it("keeps player slots apart", function()
			local widest = 5 * Layout.pitch() + 2 * Layout.MARGIN_SIDE + 2
			local seen = {}
			for slot = 1, 50 do
				local x = Layout.slotX(slot)
				for _, other in seen do
					expect(math.abs(other - x) >= widest).toBe(true)
				end
				table.insert(seen, x)
			end
		end)

		it("raises every floor above the previous one", function()
			for floor = 2, #entries do
				expect(Layout.chamberOrigin(1, floor).Y > Layout.chamberOrigin(1, floor - 1).Y).toBe(true)
			end
		end)
	end)

	describe("Ui helpers", function()
		it("create valid GUI objects", function()
			local panel = Ui.panel({ Name = "Panel", Size = UDim2.fromOffset(100, 50) }, { Ui.padding(8) })
			expect(panel.ClassName).toBe("Frame")
			expect(panel:FindFirstChildOfClass("UIPadding")).toBeTruthy()
			local label = Ui.label({ Text = "Hi", Parent = panel })
			expect(label.Parent).toBe(panel)
			local button = Ui.button({ Text = "Go" }, "Z")
			expect(button:FindFirstChild("KeyCap").Text).toBe("Z")
			expect(Ui.list(Enum.FillDirection.Vertical, 4).ClassName).toBe("UIListLayout")
		end)
	end)
end
