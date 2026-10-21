--!strict
--[[
	ChamberBuilder: one player's puzzle floor as physical geometry.

	Tiles carry attributes (owner, cell, lit) and a CollectionService tag; the
	client renders their look from those attributes. Parts are only a view:
	the authoritative board lives in SessionManager.

	Layout (top view, north is up):
	    [exit pad]
	  ===|door|===      north wall
	   . . . . .
	   . tiles .        row 1 is the northern row
	   . . . . .
	      entry         players arrive from the south
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Protocol = require(ReplicatedStorage.Shared.Protocol)
local Layout = require(script.Parent.Layout)
local Parts = require(script.Parent.Parts)

export type BuildParams = {
	ownerUserId: number,
	width: number,
	height: number,
	origin: Vector3,
	cells: { boolean },
}

export type Chamber = {
	model: Model,
	tiles: { BasePart },
	door: BasePart,
	exitPad: BasePart,
	entryCFrame: CFrame,
}

local ChamberBuilder = {}

local DOOR_CLOSED_TRANSPARENCY = 0.35
local EXIT_IDLE_TRANSPARENCY = 0.7

function ChamberBuilder.build(params: BuildParams): Chamber
	local width, height, origin = params.width, params.height, params.origin
	local pitch = Layout.pitch()
	local thickness = Layout.PLATFORM_THICKNESS
	local gridWidth = width * pitch - Layout.TILE_GAP
	local gridDepth = height * pitch - Layout.TILE_GAP
	local halfWidth = gridWidth / 2 + Layout.MARGIN_SIDE
	local northZ = -gridDepth / 2 - Layout.MARGIN_NORTH
	local southZ = gridDepth / 2 + Layout.MARGIN_SOUTH
	local depth = southZ - northZ
	local centerZ = (southZ + northZ) / 2

	local model = Instance.new("Model")
	model.Name = `Chamber_{params.ownerUserId}`

	Parts.make(model, {
		name = "Platform",
		size = Vector3.new(halfWidth * 2, thickness, depth),
		position = origin + Vector3.new(0, -thickness / 2, centerZ),
	})

	-- The tower body below the floor; taller with every floor climbed.
	local pillarHeight = origin.Y - thickness
	if pillarHeight > 1 then
		Parts.make(model, {
			name = "Pillar",
			size = Vector3.new(halfWidth * 2 - 6, pillarHeight, depth - 6),
			position = Vector3.new(origin.X, pillarHeight / 2, origin.Z + centerZ),
			color = Layout.COLORS.stoneDark,
			material = Enum.Material.Cobblestone,
		})
	end

	-- Glowing trim along the platform edges.
	for _, side in { -1, 1 } do
		Parts.make(model, {
			name = "Trim",
			size = Vector3.new(0.4, 0.4, depth),
			position = origin + Vector3.new(side * (halfWidth + 0.2), -0.6, centerZ),
			color = Layout.COLORS.trim,
			material = Enum.Material.Neon,
		})
	end

	-- West, east and south guard walls.
	Parts.guardWall(model, "WestWall", Vector3.new(1, 0, depth), origin + Vector3.new(-halfWidth - 0.5, 0, centerZ))
	Parts.guardWall(model, "EastWall", Vector3.new(1, 0, depth), origin + Vector3.new(halfWidth + 0.5, 0, centerZ))
	Parts.guardWall(model, "SouthWall", Vector3.new(halfWidth * 2 + 2, 0, 1), origin + Vector3.new(0, 0, southZ + 0.5))

	-- North wall with a door gap in the middle.
	local segmentWidth = halfWidth - Layout.DOOR_WIDTH / 2 + 1
	for _, side in { -1, 1 } do
		Parts.make(model, {
			name = "NorthWall",
			size = Vector3.new(segmentWidth, Layout.WALL_HEIGHT, 2),
			position = origin
				+ Vector3.new(side * (Layout.DOOR_WIDTH / 2 + segmentWidth / 2), Layout.WALL_HEIGHT / 2, northZ - 1),
			color = Layout.COLORS.stoneDark,
			material = Enum.Material.Cobblestone,
		})
	end
	Parts.make(model, {
		name = "Lintel",
		size = Vector3.new(Layout.DOOR_WIDTH, Layout.WALL_HEIGHT - Layout.DOOR_HEIGHT, 2),
		position = origin + Vector3.new(0, (Layout.WALL_HEIGHT + Layout.DOOR_HEIGHT) / 2, northZ - 1),
		color = Layout.COLORS.stoneDark,
		material = Enum.Material.Cobblestone,
	})

	local door = Parts.make(model, {
		name = "Door",
		size = Vector3.new(Layout.DOOR_WIDTH, Layout.DOOR_HEIGHT, 1),
		position = origin + Vector3.new(0, Layout.DOOR_HEIGHT / 2, northZ - 1),
		color = Layout.COLORS.doorLocked,
		material = Enum.Material.Neon,
		transparency = DOOR_CLOSED_TRANSPARENCY,
	})
	door:SetAttribute(Protocol.ATTR_OWNER, params.ownerUserId)
	door:SetAttribute(Protocol.ATTR_OPEN, false)
	CollectionService:AddTag(door, Protocol.DOOR_TAG)

	-- Exit ledge behind the door.
	local ledgeZ = northZ - 2 - 5
	local ledgeWidth = Layout.DOOR_WIDTH + 4
	Parts.make(model, {
		name = "Ledge",
		size = Vector3.new(ledgeWidth, thickness, 10),
		position = origin + Vector3.new(0, -thickness / 2, ledgeZ),
	})
	local exitPad = Parts.make(model, {
		name = "ExitPad",
		size = Vector3.new(6, 0.4, 6),
		position = origin + Vector3.new(0, 0.2, ledgeZ - 1),
		color = Layout.COLORS.exit,
		material = Enum.Material.Neon,
		transparency = EXIT_IDLE_TRANSPARENCY,
	})
	Parts.guardWall(model, "LedgeWest", Vector3.new(1, 0, 10), origin + Vector3.new(-ledgeWidth / 2 - 0.5, 0, ledgeZ))
	Parts.guardWall(model, "LedgeEast", Vector3.new(1, 0, 10), origin + Vector3.new(ledgeWidth / 2 + 0.5, 0, ledgeZ))
	Parts.guardWall(model, "LedgeNorth", Vector3.new(ledgeWidth + 2, 0, 1), origin + Vector3.new(0, 0, ledgeZ - 5.5))

	local tileFolder = Instance.new("Folder")
	tileFolder.Name = "Tiles"
	tileFolder.Parent = model
	local tiles: { BasePart } = {}
	for row = 1, height do
		for column = 1, width do
			local index = (row - 1) * width + column
			local tile = Parts.make(tileFolder, {
				name = `Tile_{index}`,
				size = Vector3.new(Layout.TILE_SIZE, Layout.TILE_HEIGHT, Layout.TILE_SIZE),
				position = origin
					+ Layout.cellOffset(width, height, column, row)
					+ Vector3.new(0, Layout.TILE_HEIGHT / 2, 0),
				color = Layout.COLORS.tileOff,
			})
			tile:SetAttribute(Protocol.ATTR_OWNER, params.ownerUserId)
			tile:SetAttribute(Protocol.ATTR_CELL, index)
			tile:SetAttribute(Protocol.ATTR_LIT, params.cells[index] == true)
			CollectionService:AddTag(tile, Protocol.TILE_TAG)
			tiles[index] = tile
		end
	end

	local entryPosition = origin + Vector3.new(0, 3, southZ - 5)
	local entryCFrame = CFrame.lookAt(entryPosition, entryPosition + Vector3.new(0, 0, -1))

	model.Parent = workspace
	return {
		model = model,
		tiles = tiles,
		door = door,
		exitPad = exitPad,
		entryCFrame = entryCFrame,
	}
end

function ChamberBuilder.setCells(chamber: Chamber, cells: { boolean })
	for index, tile in chamber.tiles do
		tile:SetAttribute(Protocol.ATTR_LIT, cells[index] == true)
	end
end

function ChamberBuilder.setDoorOpen(chamber: Chamber, open: boolean)
	chamber.door.CanCollide = not open
	chamber.door.Transparency = if open then 1 else DOOR_CLOSED_TRANSPARENCY
	chamber.door:SetAttribute(Protocol.ATTR_OPEN, open)
	chamber.exitPad.Transparency = if open then 0 else EXIT_IDLE_TRANSPARENCY
end

function ChamberBuilder.destroy(chamber: Chamber)
	chamber.model:Destroy()
end

return ChamberBuilder
