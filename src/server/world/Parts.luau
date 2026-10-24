--!strict
-- Small helper for building anchored geometry from code (no marketplace assets).

local Layout = require(script.Parent.Layout)

export type Props = {
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	-- Invisible barriers collide but are ignored by raycasts and touches.
	barrier: boolean?,
}

local Parts = {}

function Parts.make(parent: Instance, props: Props): Part
	local part = Instance.new("Part")
	part.Name = props.name
	part.Anchored = true
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Layout.COLORS.stone
	part.Material = props.material or Enum.Material.Slate
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.barrier then
		part.Transparency = 1
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
	else
		part.Transparency = props.transparency or 0
	end
	part.Parent = parent
	return part
end

-- A visible low wall with an invisible barrier on top, so nobody falls off.
function Parts.guardWall(parent: Instance, name: string, size: Vector3, basePosition: Vector3)
	Parts.make(parent, {
		name = name,
		size = Vector3.new(size.X, Layout.PARAPET_HEIGHT, size.Z),
		position = basePosition + Vector3.new(0, Layout.PARAPET_HEIGHT / 2, 0),
		color = Layout.COLORS.stoneDark,
		material = Enum.Material.Cobblestone,
	})
	Parts.make(parent, {
		name = name .. "Barrier",
		size = Vector3.new(size.X, Layout.WALL_HEIGHT, size.Z),
		position = basePosition + Vector3.new(0, Layout.WALL_HEIGHT / 2, 0),
		barrier = true,
	})
end

return Parts
