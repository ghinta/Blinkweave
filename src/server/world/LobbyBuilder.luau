--!strict
--[[
	LobbyBuilder: the shared 3D lobby at the world origin.

	A stone plaza with the spawn, a central tower and a glowing start pad.
	Stepping on the pad continues at the highest unlocked floor; the lobby UI
	offers every unlocked floor as well.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Protocol = require(ReplicatedStorage.Shared.Protocol)
local Layout = require(script.Parent.Layout)
local Parts = require(script.Parent.Parts)

export type Lobby = {
	model: Model,
	spawnCFrame: CFrame,
	startPad: BasePart,
}

local LobbyBuilder = {}

local function addAtmosphere()
	if Lighting:FindFirstChildOfClass("Atmosphere") then
		return
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(70, 96, 140)
	atmosphere.Decay = Color3.fromRGB(28, 40, 72)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting
end

function LobbyBuilder.build(): Lobby
	addAtmosphere()

	local model = Instance.new("Model")
	model.Name = "Lobby"
	local size = Layout.LOBBY_SIZE
	local half = size / 2

	Parts.make(model, {
		name = "Plaza",
		size = Vector3.new(size, 2, size),
		position = Vector3.new(0, -1, 0),
	})
	Parts.guardWall(model, "WestWall", Vector3.new(1, 0, size), Vector3.new(-half - 0.5, 0, 0))
	Parts.guardWall(model, "EastWall", Vector3.new(1, 0, size), Vector3.new(half + 0.5, 0, 0))
	Parts.guardWall(model, "SouthWall", Vector3.new(size + 2, 0, 1), Vector3.new(0, 0, half + 0.5))
	Parts.guardWall(model, "NorthWall", Vector3.new(size + 2, 0, 1), Vector3.new(0, 0, -half - 0.5))

	-- Central tower with glowing seams.
	local towerPosition = Vector3.new(0, 30, -24)
	local tower = Parts.make(model, {
		name = "Tower",
		size = Vector3.new(16, 60, 16),
		position = towerPosition,
		color = Layout.COLORS.stoneDark,
		material = Enum.Material.Cobblestone,
	})
	for _, height in { 12, 26, 40, 54 } do
		Parts.make(model, {
			name = "TowerSeam",
			size = Vector3.new(16.6, 0.6, 16.6),
			position = Vector3.new(towerPosition.X, height, towerPosition.Z),
			color = Layout.COLORS.trim,
			material = Enum.Material.Neon,
		})
	end

	-- NormalId.Back is the +Z face, which looks at the plaza and the spawn.
	local sign = Instance.new("SurfaceGui")
	sign.Name = "TitleSign"
	sign.Face = Enum.NormalId.Back
	sign.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sign.PixelsPerStud = 40
	sign.LightInfluence = 0
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.12)
	title.Position = UDim2.fromScale(0, 0.62)
	title.BackgroundTransparency = 1
	title.Text = "BLINKWEAVE"
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = Layout.COLORS.trim
	title.Parent = sign
	sign.Parent = tower

	local startPad = Parts.make(model, {
		name = "StartPad",
		size = Vector3.new(10, 0.4, 10),
		position = Vector3.new(0, 0.2, 2),
		color = Layout.COLORS.trim,
		material = Enum.Material.Neon,
	})
	CollectionService:AddTag(startPad, Protocol.START_PAD_TAG)

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "LobbySpawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.Position = Layout.LOBBY_SPAWN + Vector3.new(0, 0.5, 0)
	spawnLocation.Color = Layout.COLORS.stone
	spawnLocation.Material = Enum.Material.Slate
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = model

	model.Parent = workspace

	local spawnPosition = Layout.LOBBY_SPAWN + Vector3.new(0, 4, 0)
	return {
		model = model,
		spawnCFrame = CFrame.lookAt(spawnPosition, spawnPosition + Vector3.new(0, 0, -1)),
		startPad = startPad,
	}
end

return LobbyBuilder
