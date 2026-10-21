--!strict
--[[
	GameService: wires sessions, progression, world and analytics together.

	Every player has a context with a fixed slot (chamber column). Starting a
	floor creates a fresh session and rebuilds the chamber at that floor's
	height; solving opens the door, and the exit pad (or the HUD) leads up.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = require(ReplicatedStorage.Shared.Protocol)
local Types = require(ReplicatedStorage.Shared.Types)
local Config = require(script.Parent.Parent.Config)
local LevelLibrary = require(script.Parent.Parent.logic.LevelLibrary)
local world = script.Parent.Parent.world
local Layout = require(world.Layout)
local ChamberBuilder = require(world.ChamberBuilder)
local LobbyBuilder = require(world.LobbyBuilder)
local ActionGateway = require(script.Parent.ActionGateway)
local Analytics = require(script.Parent.Analytics)
local ProgressionService = require(script.Parent.ProgressionService)
local SessionManager = require(script.Parent.SessionManager)

type Entry = LevelLibrary.Entry
type Session = SessionManager.Session
type Chamber = ChamberBuilder.Chamber
type ActionRequest = Types.ActionRequest
type ErrorCode = Types.ErrorCode
type Notice = Types.Notice

type PlayerContext = {
	player: Player,
	slot: number,
	chamber: Chamber?,
	chamberConnections: { RBXScriptConnection },
	lastPadTouch: number,
}

local GameService = {}
GameService.__index = GameService

export type GameService = typeof(setmetatable(
	{} :: {
		entries: { Entry },
		lastTutorialFloor: number,
		sessions: SessionManager.SessionManager,
		progression: ProgressionService.ProgressionService,
		gateway: ActionGateway.ActionGateway,
		remotes: Protocol.Remotes,
		lobby: LobbyBuilder.Lobby,
		contexts: { [Player]: PlayerContext },
		usedSlots: { [number]: boolean },
	},
	GameService
))

function GameService.new(entries: { Entry }): GameService
	local lastTutorialFloor = 0
	for _, entry in entries do
		if entry.level.tutorial then
			lastTutorialFloor = math.max(lastTutorialFloor, entry.floor)
		end
	end

	local service: GameService
	local progression = ProgressionService.new(entries, function(player: Player)
		service:notice(player, "save_failed")
	end)
	service = setmetatable({
		entries = entries,
		lastTutorialFloor = lastTutorialFloor,
		sessions = SessionManager.new(#entries),
		progression = progression,
		gateway = ActionGateway.new(),
		remotes = Protocol.getRemotes(),
		lobby = LobbyBuilder.build(),
		contexts = {},
		usedSlots = {},
	}, GameService)
	return service
end

-- Messaging ----------------------------------------------------------------

function GameService.notice(self: GameService, player: Player, code: Types.NoticeCode)
	local notice: Notice = { code = code }
	self.remotes.notice:FireClient(player, notice)
end

function GameService.sendSnapshot(self: GameService, player: Player)
	local session = self.sessions:get(player.UserId)
	self.remotes.snapshot:FireClient(player, if session then self.sessions:snapshot(session) else false)
end

-- Every rejection is followed by the current snapshot so the client can resync.
function GameService.reject(self: GameService, player: Player, code: ErrorCode)
	self:notice(player, code)
	self:sendSnapshot(player)
end

function GameService.sendProgress(self: GameService, player: Player)
	local view = self.progression:view(player)
	if view then
		self.remotes.progress:FireClient(player, view)
	end
end

-- World ----------------------------------------------------------------------

function GameService.teleport(_self: GameService, player: Player, target: CFrame)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		-- CharacterAdded moves the next character into place.
		return
	end
	if workspace.StreamingEnabled then
		pcall(function()
			player:RequestStreamAroundAsync(target.Position, 3)
		end)
	end
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(target)
end

function GameService.destroyChamber(_self: GameService, context: PlayerContext)
	for _, connection in context.chamberConnections do
		connection:Disconnect()
	end
	table.clear(context.chamberConnections)
	if context.chamber then
		ChamberBuilder.destroy(context.chamber)
		context.chamber = nil
	end
end

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return if model then Players:GetPlayerFromCharacter(model) else nil
end

local function debounced(context: PlayerContext): boolean
	local now = os.clock()
	if now - context.lastPadTouch < Config.PAD_DEBOUNCE then
		return true
	end
	context.lastPadTouch = now
	return false
end

function GameService.buildChamber(self: GameService, context: PlayerContext, session: Session)
	local player = context.player
	local level = session.entry.level
	local chamber = ChamberBuilder.build({
		ownerUserId = player.UserId,
		width = level.width,
		height = level.height,
		origin = Layout.chamberOrigin(context.slot, session.entry.floor),
		cells = session.board.cells,
	})
	context.chamber = chamber
	table.insert(
		context.chamberConnections,
		chamber.exitPad.Touched:Connect(function(hit: BasePart)
			if playerFromHit(hit) ~= player or debounced(context) then
				return
			end
			local current = self.sessions:get(player.UserId)
			if current and current.result then
				self:nextFloor(player)
			end
		end)
	)
end

-- Floors ---------------------------------------------------------------------

-- Ends the current session (if any). Unsolved sessions count as an exit.
function GameService.endSession(self: GameService, context: PlayerContext)
	local session = self.sessions:stop(context.player.UserId)
	if session and not session.result then
		Analytics.floorExited(context.player, session.entry.floor)
	end
	self:destroyChamber(context)
end

function GameService.startFloor(self: GameService, player: Player, floor: number)
	local context = self.contexts[player]
	local profile = self.progression:profile(player)
	if not context or not profile then
		self:reject(player, "unavailable")
		return
	end
	local entry = self.entries[floor]
	if not entry or floor > math.min(profile.highestUnlocked, #self.entries) then
		self:reject(player, "floor_locked")
		return
	end

	self:endSession(context)
	local session = self.sessions:start(player.UserId, entry, os.clock())
	self:buildChamber(context, session)
	self:teleport(player, (context.chamber :: Chamber).entryCFrame)
	self:sendSnapshot(player)

	Analytics.floorStarted(player, floor, entry.level.id)
	if entry.level.tutorial and floor == 1 and profile.levels[entry.level.id] == nil then
		Analytics.tutorialStarted(player)
	end
end

function GameService.nextFloor(self: GameService, player: Player)
	local session = self.sessions:get(player.UserId)
	if not session or not session.result then
		self:reject(player, "not_solved")
		return
	end
	local nextFloor = session.entry.floor + 1
	if nextFloor > #self.entries then
		-- Top of the tower: back to the lobby.
		self:leave(player)
	else
		self:startFloor(player, nextFloor)
	end
end

function GameService.leave(self: GameService, player: Player)
	local context = self.contexts[player]
	if not context then
		return
	end
	self:endSession(context)
	self:teleport(player, self.lobby.spawnCFrame)
	self:sendSnapshot(player)
	self:sendProgress(player)
end

function GameService.onSolved(self: GameService, player: Player, context: PlayerContext, session: Session)
	local entry = session.entry
	local result = session.result
	local profile = self.progression:profile(player)
	if not result or not profile then
		return
	end
	local firstCompletion = profile.levels[entry.level.id] == nil
	self.progression:recordCompletion(player, entry, result)
	if context.chamber then
		ChamberBuilder.setDoorOpen(context.chamber, true)
	end
	Analytics.floorFinished(player, entry.floor, entry.level.id)
	if entry.floor == self.lastTutorialFloor and firstCompletion then
		Analytics.tutorialFinished(player)
	end
end

-- Actions --------------------------------------------------------------------

function GameService.handleSessionAction(self: GameService, player: Player, request: ActionRequest)
	local context = self.contexts[player]
	if not context then
		return
	end
	local outcome = self.sessions:apply(player.UserId, request, os.clock())
	if not outcome.ok then
		self:reject(player, outcome.error or "bad_request")
		return
	end

	local session = outcome.session :: Session
	if outcome.changed then
		if context.chamber then
			ChamberBuilder.setCells(context.chamber, session.board.cells)
		end
		if request.kind == "reset" then
			Analytics.reset(player, session.entry.floor)
		elseif request.kind == "hint" then
			Analytics.hint(player, session.entry.floor)
		end
	end
	if outcome.solvedNow then
		self:onSolved(player, context, session)
	end
	self:sendSnapshot(player)
	if outcome.solvedNow then
		self:sendProgress(player)
	end
end

function GameService.handleAction(self: GameService, player: Player, request: ActionRequest)
	local kind = request.kind
	if SessionManager.isSessionAction(kind) then
		self:handleSessionAction(player, request)
	elseif kind == "start" then
		self:startFloor(player, request.floor :: number)
	elseif kind == "next" then
		self:nextFloor(player)
	elseif kind == "leave" then
		self:leave(player)
	elseif kind == "setting" then
		if self.progression:isLoaded(player) then
			self.progression:setSetting(player, request.setting :: Types.SettingName, request.value == true)
			self:sendProgress(player)
		end
	elseif kind == "sync" then
		self:sendSnapshot(player)
		self:sendProgress(player)
	end
end

-- Players --------------------------------------------------------------------

function GameService.allocateSlot(self: GameService): number
	local slot = 1
	while self.usedSlots[slot] do
		slot += 1
	end
	self.usedSlots[slot] = true
	return slot
end

function GameService.onCharacterAdded(self: GameService, player: Player, character: Model)
	local context = self.contexts[player]
	if not context or not context.chamber then
		return
	end
	-- Respawned during a floor (e.g. after a fall): return to the chamber entry.
	if character:WaitForChild("HumanoidRootPart", 10) and context.chamber then
		task.defer(function()
			if context.chamber and player.Character == character then
				self:teleport(player, context.chamber.entryCFrame)
			end
		end)
	end
end

function GameService.onPlayerAdded(self: GameService, player: Player)
	local context: PlayerContext = {
		player = player,
		slot = self:allocateSlot(),
		chamber = nil,
		chamberConnections = {},
		lastPadTouch = -math.huge,
	}
	self.contexts[player] = context
	player.CharacterAdded:Connect(function(character: Model)
		self:onCharacterAdded(player, character)
	end)

	if not self.progression:load(player) then
		return
	end
	self:sendProgress(player)
	self:sendSnapshot(player)
end

function GameService.onPlayerRemoving(self: GameService, player: Player)
	local context = self.contexts[player]
	if not context then
		return
	end
	self:endSession(context)
	self.usedSlots[context.slot] = nil
	self.contexts[player] = nil
	self.gateway:forget(player)
	self.progression:release(player)
end

function GameService.onStartPadTouched(self: GameService, hit: BasePart)
	local player = playerFromHit(hit)
	local context = player and self.contexts[player]
	if not player or not context or debounced(context) or self.sessions:get(player.UserId) then
		return
	end
	local profile = self.progression:profile(player)
	if profile then
		self:startFloor(player, math.min(profile.highestUnlocked, #self.entries))
	end
end

function GameService.start(self: GameService)
	self.gateway:connect(self.remotes, function(player: Player, request: ActionRequest)
		self:handleAction(player, request)
	end, function(player: Player, code: ErrorCode)
		self:reject(player, code)
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		self:onPlayerAdded(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(self.onPlayerAdded, self, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		self:onPlayerRemoving(player)
	end)

	self.lobby.startPad.Touched:Connect(function(hit: BasePart)
		self:onStartPadTouched(hit)
	end)

	self.progression:startAutosave()
	game:BindToClose(function()
		self.progression:saveAll()
	end)
end

return GameService
