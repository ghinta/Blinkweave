--!strict
--[[
	BoardController: renders every tagged tile from its replicated attributes.

	Tiles show their state by colour AND shape (accessibility): lit tiles glow
	cyan with a dark diamond, dark tiles are slate with a small grey dot.
	Icons and lights are only added to the local player's own tiles. The hint
	tile gets a gold highlight. Door and start pad get localized labels.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Protocol = require(ReplicatedStorage.Shared.Protocol)
local Types = require(ReplicatedStorage.Shared.Types)
local Net = require(script.Parent.Net)
local Strings = require(script.Parent.Strings)
local Theme = require(script.Parent.Theme)

type Snapshot = Types.Snapshot

-- Shape icon and light, built only for the local player's own tiles.
type Face = {
	icon: Frame,
	iconCorner: UICorner,
	iconScale: UIScale,
	light: PointLight,
}

type TileView = {
	tile: BasePart,
	face: Face?,
	connection: RBXScriptConnection,
}

local localPlayer = Players.LocalPlayer

local FADE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local BoardController = {}

local views: { [Instance]: TileView } = {}
local hintHighlight: Highlight? = nil

local function applyLook(view: TileView, lit: boolean, animate: boolean)
	local tile = view.tile
	local color = if lit then Theme.colors.tileLit else Theme.colors.tileOff
	tile.Material = if lit then Enum.Material.Neon else Enum.Material.Slate
	if animate then
		TweenService:Create(tile, FADE, { Color = color }):Play()
	else
		tile.Color = color
	end

	local face = view.face
	if not face then
		return
	end
	face.light.Enabled = lit
	local icon = face.icon
	icon.Size = if lit then UDim2.fromScale(0.4, 0.4) else UDim2.fromScale(0.12, 0.12)
	icon.Rotation = if lit then 45 else 0
	icon.BackgroundColor3 = if lit then Theme.colors.panel else Theme.colors.iconOff
	face.iconCorner.CornerRadius = if lit then UDim.new(0.15, 0) else UDim.new(0.5, 0)
	if animate then
		face.iconScale.Scale = 0.3
		TweenService:Create(face.iconScale, POP, { Scale = 1 }):Play()
	end
end

local function isLit(tile: Instance): boolean
	return tile:GetAttribute(Protocol.ATTR_LIT) == true
end

local function buildFace(tile: BasePart): Face
	local surface = Instance.new("SurfaceGui")
	surface.Name = "TileFace"
	surface.Face = Enum.NormalId.Top
	surface.LightInfluence = 0
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.BorderSizePixel = 0
	icon.BackgroundTransparency = 0.1
	local iconCorner = Instance.new("UICorner")
	iconCorner.Parent = icon
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = icon
	local iconScale = Instance.new("UIScale")
	iconScale.Parent = icon
	icon.Parent = surface
	surface.Parent = tile

	local light = Instance.new("PointLight")
	light.Color = Theme.colors.tileLit
	light.Range = 9
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = tile

	return { icon = icon, iconCorner = iconCorner, iconScale = iconScale, light = light }
end

local function decorateTile(instance: Instance)
	if not instance:IsA("BasePart") or views[instance] then
		return
	end
	local tile = instance
	local isOwn = tile:GetAttribute(Protocol.ATTR_OWNER) == localPlayer.UserId

	local view: TileView = {
		tile = tile,
		-- Other players' boards only change colour; that keeps lights and GUIs cheap.
		face = if isOwn then buildFace(tile) else nil,
		connection = tile:GetAttributeChangedSignal(Protocol.ATTR_LIT):Connect(function()
			local current = views[tile]
			if current then
				applyLook(current, isLit(tile), true)
			end
		end),
	}
	views[tile] = view
	applyLook(view, isLit(tile), false)
end

local function forgetTile(instance: Instance)
	local view = views[instance]
	if view then
		view.connection:Disconnect()
		views[instance] = nil
	end
end

local function billboard(adornee: BasePart, offset: Vector3, maxDistance: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(240, 44)
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Theme.colors.panel
	label.BackgroundTransparency = 0.25
	label.Font = Theme.fontBold
	label.TextSize = 20
	label.TextColor3 = Theme.colors.text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	label.Parent = gui
	gui.Adornee = adornee
	gui.Parent = adornee
	return label
end

local function decorateDoor(instance: Instance)
	if not instance:IsA("BasePart") or instance:FindFirstChild("Label") then
		return
	end
	local door = instance
	local label = billboard(door, Vector3.new(0, door.Size.Y / 2 + 2.5, 0), 80)
	local function refresh()
		local open = door:GetAttribute(Protocol.ATTR_OPEN) == true
		label.Text = Strings.get(if open then "doorOpen" else "doorLocked")
		label.TextColor3 = if open then Theme.colors.accent else Theme.colors.gold
	end
	door:GetAttributeChangedSignal(Protocol.ATTR_OPEN):Connect(refresh)
	refresh()
end

local function decorateStartPad(instance: Instance)
	if not instance:IsA("BasePart") or instance:FindFirstChild("Label") then
		return
	end
	local label = billboard(instance, Vector3.new(0, 5, 0), 120)
	label.Text = Strings.get("startPad")
	label.TextColor3 = Theme.colors.accent
end

local function ownTile(cell: number): BasePart?
	for _, view in views do
		local tile = view.tile
		if
			tile:GetAttribute(Protocol.ATTR_OWNER) == localPlayer.UserId
			and tile:GetAttribute(Protocol.ATTR_CELL) == cell
		then
			return tile
		end
	end
	return nil
end

local function updateHint(snapshot: Snapshot?)
	if hintHighlight then
		hintHighlight:Destroy()
		hintHighlight = nil
	end
	local cell = snapshot and snapshot.hintCell
	if not cell then
		return
	end
	local tile = ownTile(cell)
	if not tile then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "HintHighlight"
	highlight.FillColor = Theme.colors.gold
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = Theme.colors.gold
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = tile
	hintHighlight = highlight
end

local function watchTag(tag: string, added: (Instance) -> (), removed: ((Instance) -> ())?)
	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(added, instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(added)
	if removed then
		CollectionService:GetInstanceRemovedSignal(tag):Connect(removed)
	end
end

function BoardController.start()
	watchTag(Protocol.TILE_TAG, decorateTile, forgetTile)
	watchTag(Protocol.DOOR_TAG, decorateDoor)
	watchTag(Protocol.START_PAD_TAG, decorateStartPad)
	Net.onSnapshot(updateHint)
end

return BoardController
