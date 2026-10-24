--!strict
--[[
	Hud: all 2D UI, built from code.

	- In a floor: status (floor, moves, goal), action buttons, an accessible
	  mini board that mirrors the 3D tiles, and the result panel when solved.
	- In the lobby: floor selection with stars, settings and save status.

	Layout is designed for a 1280x720 reference and scaled with UIScale;
	ScreenInsets keep it inside the device safe area.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Types = require(ReplicatedStorage.Shared.Types)
local Commands = require(script.Parent.Commands)
local Net = require(script.Parent.Net)
local Strings = require(script.Parent.Strings)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

type Snapshot = Types.Snapshot
type ProgressView = Types.ProgressView
type FloorView = Types.FloorView
type Notice = Types.Notice

local MARGIN = 12
local SIDE_WIDTH = 200
local GRID_SIZE = 200
local GRID_GAP = 4
local MIN_SCALE, MAX_SCALE = 0.75, 1.25
local TOAST_SECONDS = 2.4

local Hud = {}

local localPlayer = Players.LocalPlayer
local showKeyCaps = UserInputService.KeyboardEnabled

local root: Frame
local uiScale: UIScale

local statusPanel: Frame
local floorLabel: TextLabel
local movesLabel: TextLabel
local tipLabel: TextLabel

local actionsPanel: Frame
local undoButton: TextButton
local restartButton: TextButton
local hintButton: TextButton

local gridPanel: Frame
local gridFrame: Frame
local gridLayout: UIGridLayout
local gridButtons: { TextButton } = {}
local gridKey = ""

local solvedPanel: Frame
local solvedTitle: TextLabel
local starsLabel: TextLabel
local resultLabel: TextLabel
local bestLabel: TextLabel
local nextButton: TextButton

local lobbyPanel: Frame
local floorsFrame: Frame
local lobbyStatus: TextLabel
local soundButton: TextButton
local jumpButton: TextButton
local showFloorsButton: TextButton
local lobbyHidden = false

local toastLabel: TextLabel
local toastToken = 0

local function starsText(stars: number): string
	return string.rep("★", stars) .. string.rep("☆", 3 - stars)
end

local function setEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then Theme.colors.button else Theme.colors.buttonDisabled
	button.TextTransparency = if enabled then 0 else 0.55
end

function Hud.toast(text: string)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.Visible = true
	toastLabel.TextTransparency = 0
	toastLabel.BackgroundTransparency = 0.15
	task.delay(TOAST_SECONDS, function()
		if token ~= toastToken then
			return
		end
		local fade = TweenInfo.new(0.4)
		TweenService:Create(toastLabel, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.delay(0.4, function()
			if token == toastToken then
				toastLabel.Visible = false
			end
		end)
	end)
end

-- Building ---------------------------------------------------------------------

local function buildStatus()
	statusPanel = Ui.panel({
		Name = "Status",
		Position = UDim2.fromOffset(MARGIN, MARGIN),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	}, { Ui.padding(14), Ui.list(Enum.FillDirection.Vertical, 6) })

	floorLabel = Ui.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 32),
		Font = Theme.fontTitle,
		TextSize = 28,
		Parent = statusPanel,
	})
	movesLabel = Ui.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 24),
		Font = Theme.fontBold,
		TextSize = 20,
		Parent = statusPanel,
	})
	Ui.label({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 22),
		Text = Strings.get("goal"),
		TextColor3 = Theme.colors.gold,
		Font = Theme.fontBold,
		Parent = statusPanel,
	})
	tipLabel = Ui.label({
		LayoutOrder = 4,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 16,
		TextColor3 = Theme.colors.muted,
		Parent = statusPanel,
	})
	local lobbyButton = Ui.button({
		LayoutOrder = 5,
		Size = UDim2.fromOffset(140, 40),
		Text = Strings.get("lobby"),
		TextSize = 16,
		Parent = statusPanel,
	})
	lobbyButton.Activated:Connect(Commands.leave)
end

local function buildActions()
	actionsPanel = Ui.new("Frame", {
		Name = "Actions",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, MARGIN),
		Size = UDim2.fromOffset(SIDE_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = root,
	}, { Ui.list(Enum.FillDirection.Vertical, 8) })

	local function action(order: number, key: string, keyCap: string, command: () -> ()): TextButton
		local button = Ui.button({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, Theme.touchTarget),
			Text = Strings.get(key),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = actionsPanel,
		}, if showKeyCaps then keyCap else nil)
		Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 14), Parent = button })
		button.Activated:Connect(command)
		return button
	end

	undoButton = action(1, "undo", "Z", Commands.undo)
	restartButton = action(2, "restart", "R", Commands.restart)
	hintButton = action(3, "hint", "H", Commands.hint)
end

local function buildGrid()
	gridPanel = Ui.panel({
		Name = "Board",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, MARGIN + 3 * Theme.touchTarget + 2 * 8 + MARGIN),
		Size = UDim2.fromOffset(SIDE_WIDTH, GRID_SIZE + 34),
		Parent = root,
	}, { Ui.padding(10) })
	Ui.label({
		Size = UDim2.new(1, 0, 0, 20),
		Text = Strings.get("gridLabel"),
		TextSize = 14,
		TextColor3 = Theme.colors.muted,
		Parent = gridPanel,
	})
	gridFrame = Ui.new("Frame", {
		Name = "Cells",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 1, -24),
		BackgroundTransparency = 1,
		Parent = gridPanel,
	})
	gridLayout = Ui.new("UIGridLayout", {
		CellPadding = UDim2.fromOffset(GRID_GAP, GRID_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = gridFrame,
	})
end

local function buildSolved()
	solvedPanel = Ui.panel({
		Name = "Solved",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = root,
	}, { Ui.padding(18), Ui.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Center) })

	solvedTitle = Ui.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Font = Theme.fontTitle,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = solvedPanel,
	})
	starsLabel = Ui.label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 48),
		TextSize = 44,
		TextColor3 = Theme.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = solvedPanel,
	})
	resultLabel = Ui.label({
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = solvedPanel,
	})
	bestLabel = Ui.label({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.colors.muted,
		Parent = solvedPanel,
	})
	nextButton = Ui.button({
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, Theme.touchTarget),
		BackgroundColor3 = Theme.colors.accent,
		TextColor3 = Theme.colors.accentText,
		Parent = solvedPanel,
	}, if showKeyCaps then "N" else nil)
	nextButton.Activated:Connect(Commands.nextFloor)

	local row = Ui.new("Frame", {
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, Theme.touchTarget),
		BackgroundTransparency = 1,
		Parent = solvedPanel,
	}, { Ui.list(Enum.FillDirection.Horizontal, 10) })
	local replayButton = Ui.button({
		Size = UDim2.new(0.5, -5, 1, 0),
		Text = Strings.get("replay"),
		Parent = row,
	})
	replayButton.Activated:Connect(Commands.restart)
	local lobbyButton = Ui.button({
		Size = UDim2.new(0.5, -5, 1, 0),
		Text = Strings.get("lobby"),
		Parent = row,
	})
	lobbyButton.Activated:Connect(Commands.leave)
end

local function buildLobby()
	lobbyPanel = Ui.panel({
		Name = "Lobby",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(500, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = root,
	}, { Ui.padding(18), Ui.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Center) })

	Ui.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Text = "BLINKWEAVE",
		Font = Theme.fontTitle,
		TextSize = 36,
		TextColor3 = Theme.colors.accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = lobbyPanel,
	})
	Ui.label({
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = Strings.get("subtitle") .. "\n" .. Strings.get("howTo"),
		TextSize = 16,
		TextColor3 = Theme.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = lobbyPanel,
	})

	floorsFrame = Ui.new("Frame", {
		LayoutOrder = 3,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = lobbyPanel,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(84, 92),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})

	lobbyStatus = Ui.label({
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 15,
		TextColor3 = Theme.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = lobbyPanel,
	})

	local settingsRow = Ui.new("Frame", {
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Parent = lobbyPanel,
	}, { Ui.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center) })
	soundButton = Ui.button({ Size = UDim2.fromScale(0.38, 1), TextSize = 15, Parent = settingsRow })
	jumpButton = Ui.button({ Size = UDim2.fromScale(0.38, 1), TextSize = 15, Parent = settingsRow })
	local hideButton = Ui.button({
		Size = UDim2.fromScale(0.2, 1),
		Text = Strings.get("hideFloors"),
		TextSize = 15,
		Parent = settingsRow,
	})
	soundButton.Activated:Connect(function()
		Net.setSetting("soundOn", not Net.isSettingOn("soundOn"))
	end)
	jumpButton.Activated:Connect(function()
		Net.setSetting("jumpToggles", not Net.isSettingOn("jumpToggles"))
	end)
	hideButton.Activated:Connect(function()
		lobbyHidden = true
		Hud.refresh()
	end)

	showFloorsButton = Ui.button({
		Name = "ShowFloors",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, MARGIN),
		Size = UDim2.fromOffset(180, Theme.touchTarget),
		Text = Strings.get("floors"),
		Visible = false,
		Parent = root,
	})
	showFloorsButton.Activated:Connect(function()
		lobbyHidden = false
		Hud.refresh()
	end)
end

local function buildToast()
	toastLabel = Ui.label({
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -120),
		Size = UDim2.fromOffset(440, 44),
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = 0.15,
		Font = Theme.fontBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Parent = root,
	})
	Ui.corner().Parent = toastLabel
end

-- Rendering --------------------------------------------------------------------

local function renderGridCell(button: TextButton, lit: boolean, hinted: boolean)
	button.BackgroundColor3 = if lit then Theme.colors.tileLit else Theme.colors.tileOff
	local icon = button:FindFirstChild("Icon") :: Frame
	icon.Size = if lit then UDim2.fromScale(0.42, 0.42) else UDim2.fromScale(0.16, 0.16)
	icon.Rotation = if lit then 45 else 0
	icon.BackgroundColor3 = if lit then Theme.colors.panel else Theme.colors.iconOff
	local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = if hinted then Theme.colors.gold else Theme.colors.panelStroke
	stroke.Thickness = if hinted then 3 else 1
	stroke.Transparency = if hinted then 0 else 0.6
end

local function rebuildGrid(snapshot: Snapshot)
	for _, button in gridButtons do
		button:Destroy()
	end
	table.clear(gridButtons)
	local inner = GRID_SIZE - 20
	local across = math.max(snapshot.width, snapshot.height)
	local cell = math.floor((inner - (across - 1) * GRID_GAP) / across)
	gridLayout.CellSize = UDim2.fromOffset(cell, cell)
	gridLayout.FillDirectionMaxCells = snapshot.width
	for index = 1, snapshot.width * snapshot.height do
		local button: TextButton = Ui.new("TextButton", {
			Name = `Cell_{index}`,
			LayoutOrder = index,
			Text = "",
			AutoButtonColor = true,
			BorderSizePixel = 0,
			Parent = gridFrame,
		}, {
			Ui.corner(UDim.new(0, 6)),
			Ui.stroke(nil, 1, 0.6),
			Ui.new("Frame", {
				Name = "Icon",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				BorderSizePixel = 0,
			}, { Ui.corner(UDim.new(0.2, 0)) }),
		})
		button.Activated:Connect(function()
			Commands.press(index)
		end)
		gridButtons[index] = button
	end
end

local function renderSession(snapshot: Snapshot)
	floorLabel.Text = string.format("%s %02d / %02d", Strings.get("floor"), snapshot.floor, snapshot.floorCount)
	local moves = `{Strings.get("moves")} {snapshot.moves}  ·  {Strings.get("par")} {snapshot.parMoves}`
	if snapshot.hintsUsed > 0 then
		moves ..= `  ·  {Strings.get("hint")} {snapshot.hintsUsed}`
	end
	movesLabel.Text = moves
	tipLabel.Text = if snapshot.tutorial then Strings.get("howTo") .. "\n" .. Strings.get("tutorialReset") else ""
	tipLabel.Visible = snapshot.tutorial

	setEnabled(undoButton, snapshot.canUndo and not snapshot.solved)
	setEnabled(restartButton, true)
	restartButton.Text = Strings.get(if snapshot.solved then "replay" else "restart")
	setEnabled(hintButton, not snapshot.solved)

	local key = `{snapshot.sessionId}:{snapshot.width}x{snapshot.height}`
	if key ~= gridKey then
		gridKey = key
		rebuildGrid(snapshot)
	end
	for index, button in gridButtons do
		renderGridCell(button, snapshot.cells[index] == true, snapshot.hintCell == index)
	end

	local result = snapshot.result
	solvedPanel.Visible = result ~= nil
	if result then
		local lastFloor = snapshot.floor >= snapshot.floorCount
		solvedTitle.Text = Strings.get(if lastFloor then "towerComplete" else "solvedTitle")
		starsLabel.Text = starsText(result.stars)
		local time = Strings.formatTime(result.timeSeconds)
		resultLabel.Text =
			`{Strings.get("moves")} {result.moves}  ·  {Strings.get("par")} {result.parMoves}  ·  {time}`
		-- Personal best arrives with the progress update right after the snapshot.
		local progress = Net.progress
		local floorView = progress and progress.floors[snapshot.floor]
		local bestMoves, bestTime = floorView and floorView.bestMoves, floorView and floorView.bestTime
		bestLabel.Text = if bestMoves and bestTime
			then `{Strings.get("best")}: {bestMoves} {Strings.get("moves")}  ·  {Strings.formatTime(bestTime)}`
			else ""
		nextButton.Text = Strings.get(if lastFloor then "lobby" else "nextFloor")
	end
end

local function floorCard(view: FloorView): TextButton
	local card: TextButton = Ui.new("TextButton", {
		Name = `Floor_{view.floor}`,
		LayoutOrder = view.floor,
		Text = "",
		AutoButtonColor = view.unlocked,
		BorderSizePixel = 0,
		BackgroundColor3 = if view.unlocked then Theme.colors.button else Theme.colors.buttonDisabled,
	}, {
		Ui.corner(UDim.new(0, 10)),
		Ui.stroke(if view.tutorial then Theme.colors.gold else nil, 1, 0.5),
		Ui.label({
			Size = UDim2.new(1, 0, 0, 34),
			Position = UDim2.fromOffset(0, 6),
			Text = tostring(view.floor),
			Font = Theme.fontTitle,
			TextSize = 28,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTransparency = if view.unlocked then 0 else 0.5,
		}),
		Ui.label({
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 40),
			Text = if view.tutorial then Strings.get("tutorial") else view.size,
			TextSize = 13,
			TextColor3 = Theme.colors.muted,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
		Ui.label({
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.fromOffset(0, 62),
			Text = if view.unlocked then starsText(view.stars) else Strings.get("locked"),
			TextSize = if view.unlocked then 18 else 13,
			TextColor3 = if view.unlocked then Theme.colors.gold else Theme.colors.muted,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
	})
	card.Activated:Connect(function()
		if view.unlocked then
			Commands.start(view.floor)
		else
			Hud.toast(Strings.get("floor_locked"))
		end
	end)
	return card
end

local function renderLobby(progress: ProgressView?)
	for _, child in floorsFrame:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	if not progress then
		lobbyStatus.Text = Strings.get("loading")
		soundButton.Visible = false
		jumpButton.Visible = false
		return
	end
	for _, view in progress.floors do
		floorCard(view).Parent = floorsFrame
	end
	lobbyStatus.Text = if progress.persistence == "degraded" then Strings.get("degraded") else ""
	lobbyStatus.TextColor3 = if progress.persistence == "degraded" then Theme.colors.danger else Theme.colors.muted
	soundButton.Visible = true
	jumpButton.Visible = true
	local function onOff(value: boolean): string
		return Strings.get(if value then "on" else "off")
	end
	soundButton.Text = `{Strings.get("sound")}: {onOff(progress.settings.soundOn)}`
	jumpButton.Text = `{Strings.get("jumpToggles")}: {onOff(progress.settings.jumpToggles)}`
end

-- Shows the panels that match the current state.
function Hud.refresh()
	local snapshot = Net.snapshot
	local inSession = snapshot ~= nil
	statusPanel.Visible = inSession
	actionsPanel.Visible = inSession
	gridPanel.Visible = inSession
	if snapshot then
		renderSession(snapshot)
	else
		solvedPanel.Visible = false
		gridKey = ""
	end
	lobbyPanel.Visible = not inSession and not lobbyHidden
	showFloorsButton.Visible = not inSession and lobbyHidden
end

local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), MIN_SCALE, MAX_SCALE)
	uiScale.Scale = scale
	-- The root is enlarged so that, once scaled, it exactly covers the screen.
	root.Size = UDim2.fromScale(1 / scale, 1 / scale)
end

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BlinkweaveHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	root = Ui.new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	uiScale = Ui.new("UIScale", { Parent = root })

	buildStatus()
	buildActions()
	buildGrid()
	buildSolved()
	buildLobby()
	buildToast()

	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	updateScale()
	local function watchCamera()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
			updateScale()
		end
	end
	watchCamera()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)

	Net.onSnapshot(function()
		Hud.refresh()
	end)
	Net.onProgress(function(progress: ProgressView)
		renderLobby(progress)
		Hud.refresh()
	end)
	Net.onNotice(function(notice: Notice)
		if Strings.has(notice.code) then
			Hud.toast(Strings.get(notice.code))
		end
	end)

	renderLobby(Net.progress)
	Hud.refresh()
end

return Hud
