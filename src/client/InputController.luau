--!strict
--[[
	InputController: turns taps, clicks, jump landings and shortcuts into commands.

	- Tap / click on one of your own tiles presses it.
	- Landing on one of your own tiles after a real jump presses it
	  (can be switched off in the lobby settings).
	- Keyboard: Z undo, R restart, H hint, N next floor.
	  Gamepad: X undo, Y hint. Every action also has an on-screen button.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Protocol = require(ReplicatedStorage.Shared.Protocol)
local Commands = require(script.Parent.Commands)
local Net = require(script.Parent.Net)

local localPlayer = Players.LocalPlayer

local InputController = {}

-- A mouse press that moves further than this is a camera drag, not a click.
local CLICK_TOLERANCE = 8
-- Shorter airtime than this is a step down, not a jump landing.
local MIN_AIRTIME = 0.3
local RAY_LENGTH = 400
local LANDING_RAY = 8

local function ownCellOf(instance: Instance?): number?
	if not instance or not CollectionService:HasTag(instance, Protocol.TILE_TAG) then
		return nil
	end
	if instance:GetAttribute(Protocol.ATTR_OWNER) ~= localPlayer.UserId then
		return nil
	end
	local cell = instance:GetAttribute(Protocol.ATTR_CELL)
	return if type(cell) == "number" then cell else nil
end

local function raycastParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if localPlayer.Character then { localPlayer.Character } else {}
	return params
end

local function pressAtScreenPoint(position: Vector2)
	local camera = workspace.CurrentCamera
	if not camera or not Net.snapshot then
		return
	end
	local ray = camera:ScreenPointToRay(position.X, position.Y)
	local result = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, raycastParams())
	local cell = ownCellOf(result and result.Instance)
	if cell then
		Commands.press(cell)
	end
end

local function bindPointer()
	local pressedAt: Vector2? = nil
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressedAt = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not pressedAt then
			return
		end
		local start = pressedAt
		pressedAt = nil
		local position = Vector2.new(input.Position.X, input.Position.Y)
		if not processed and (position - start).Magnitude <= CLICK_TOLERANCE then
			pressAtScreenPoint(position)
		end
	end)
	UserInputService.TouchTap:Connect(function(positions: { Vector2 }, processed: boolean)
		if not processed and positions[1] then
			pressAtScreenPoint(positions[1])
		end
	end)
end

local function bindCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	local airborneSince: number? = nil
	humanoid.StateChanged:Connect(function(_old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
		if new == Enum.HumanoidStateType.Jumping or new == Enum.HumanoidStateType.Freefall then
			airborneSince = airborneSince or os.clock()
			return
		end
		if new ~= Enum.HumanoidStateType.Landed then
			return
		end
		local since = airborneSince
		airborneSince = nil
		if not since or os.clock() - since < MIN_AIRTIME then
			return
		end
		if not Net.snapshot or not Net.isSettingOn("jumpToggles") then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local result = workspace:Raycast(root.Position, Vector3.new(0, -LANDING_RAY, 0), raycastParams())
		local cell = ownCellOf(result and result.Instance)
		if cell then
			Commands.press(cell)
		end
	end)
end

local SHORTCUTS: { [Enum.KeyCode]: () -> () } = {
	[Enum.KeyCode.Z] = Commands.undo,
	[Enum.KeyCode.R] = Commands.restart,
	[Enum.KeyCode.H] = Commands.hint,
	[Enum.KeyCode.N] = Commands.nextFloor,
	[Enum.KeyCode.ButtonX] = Commands.undo,
	[Enum.KeyCode.ButtonY] = Commands.hint,
}

local function bindShortcuts()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		-- `processed` is true while typing in chat or a text box.
		if processed or not Net.snapshot then
			return
		end
		local command = SHORTCUTS[input.KeyCode]
		if command then
			command()
		end
	end)
end

function InputController.start()
	bindPointer()
	bindShortcuts()
	localPlayer.CharacterAdded:Connect(bindCharacter)
	if localPlayer.Character then
		task.spawn(bindCharacter, localPlayer.Character)
	end
end

return InputController
