--!strict
--[[
	World layout: sizes, colours and positions shared by the world builders.

	Every player gets a personal chamber in their own "slot" column. Each new
	floor is rebuilt higher up, so progressing literally climbs the tower.
]]

local Layout = {}

Layout.TILE_SIZE = 6
Layout.TILE_GAP = 0.5
Layout.TILE_HEIGHT = 0.6
Layout.PLATFORM_THICKNESS = 2
Layout.MARGIN_SIDE = 7
Layout.MARGIN_NORTH = 7
Layout.MARGIN_SOUTH = 12
Layout.DOOR_WIDTH = 8
Layout.DOOR_HEIGHT = 11
Layout.WALL_HEIGHT = 14
Layout.PARAPET_HEIGHT = 2

Layout.LOBBY_SIZE = 96
Layout.LOBBY_SPAWN = Vector3.new(0, 0, 30)

Layout.SLOT_SPACING = 72
Layout.CHAMBER_Z = -120
Layout.BASE_HEIGHT = 24
Layout.FLOOR_RISE = 10

Layout.COLORS = table.freeze({
	stone = Color3.fromRGB(46, 52, 66),
	stoneDark = Color3.fromRGB(30, 34, 46),
	tileOff = Color3.fromRGB(58, 64, 80),
	trim = Color3.fromRGB(79, 227, 255),
	doorLocked = Color3.fromRGB(255, 176, 72),
	exit = Color3.fromRGB(120, 255, 200),
})

-- Horizontal offset of a slot: 0, +1, -1, +2, -2, ... spacings from the centre.
function Layout.slotX(slot: number): number
	local k = slot - 1
	local distance = math.ceil(k / 2) * Layout.SLOT_SPACING
	return if k % 2 == 1 then distance else -distance
end

-- Centre of the tile grid (on top of the platform) for a slot and floor.
function Layout.chamberOrigin(slot: number, floor: number): Vector3
	return Vector3.new(Layout.slotX(slot), Layout.BASE_HEIGHT + (floor - 1) * Layout.FLOOR_RISE, Layout.CHAMBER_Z)
end

function Layout.pitch(): number
	return Layout.TILE_SIZE + Layout.TILE_GAP
end

-- Offset of a cell centre from the grid centre. Row 1 is north (towards the door).
function Layout.cellOffset(width: number, height: number, column: number, row: number): Vector3
	local pitch = Layout.pitch()
	return Vector3.new((column - (width + 1) / 2) * pitch, 0, (row - (height + 1) / 2) * pitch)
end

return Layout
