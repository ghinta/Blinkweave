--!strict
--[[
	Net: the client's view of server state and its only way to send actions.

	The server is authoritative. The client predicts the next revision so
	quick consecutive taps are accepted in order; after any rejection the
	server resends its snapshot and the prediction is reset to it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = require(ReplicatedStorage.Shared.Protocol)
local Types = require(ReplicatedStorage.Shared.Types)

type Snapshot = Types.Snapshot
type ProgressView = Types.ProgressView
type Notice = Types.Notice
type ActionRequest = Types.ActionRequest
type ActionKind = Types.ActionKind
type SettingName = Types.SettingName

type Listener<T> = (T) -> ()

local Net = {}

Net.snapshot = nil :: Snapshot?
Net.progress = nil :: ProgressView?

local remotes = Protocol.getRemotes()
local nextRevision = 0
local resyncPending = false

local snapshotListeners: { Listener<Snapshot?> } = {}
local progressListeners: { Listener<ProgressView> } = {}
local noticeListeners: { Listener<Notice> } = {}

local function emit<T>(listeners: { Listener<T> }, value: T)
	for _, listener in listeners do
		task.spawn(listener, value)
	end
end

function Net.onSnapshot(listener: Listener<Snapshot?>)
	table.insert(snapshotListeners, listener)
end

function Net.onProgress(listener: Listener<ProgressView>)
	table.insert(progressListeners, listener)
end

function Net.onNotice(listener: Listener<Notice>)
	table.insert(noticeListeners, listener)
end

local function send(request: ActionRequest)
	remotes.action:FireServer(request)
end

-- Session actions need the current session and the predicted revision.
local function sendSessionAction(kind: ActionKind, cellIndex: number?): boolean
	local snapshot = Net.snapshot
	if not snapshot or snapshot.solved then
		return false
	end
	send({
		kind = kind,
		sessionId = snapshot.sessionId,
		expectedRevision = nextRevision,
		cellIndex = cellIndex,
	})
	nextRevision += 1
	return true
end

function Net.press(cellIndex: number): boolean
	return sendSessionAction("press", cellIndex)
end

function Net.undo(): boolean
	local snapshot = Net.snapshot
	if not snapshot or not snapshot.canUndo then
		return false
	end
	return sendSessionAction("undo")
end

function Net.reset(): boolean
	return sendSessionAction("reset")
end

function Net.hint(): boolean
	local snapshot = Net.snapshot
	-- A visible hint is free to ask for again and does not bump the revision.
	if not snapshot or snapshot.hintCell ~= nil then
		return false
	end
	return sendSessionAction("hint")
end

function Net.start(floor: number)
	send({ kind = "start", floor = floor })
end

function Net.nextFloor()
	send({ kind = "next" })
end

function Net.leave()
	send({ kind = "leave" })
end

function Net.setSetting(setting: SettingName, value: boolean)
	send({ kind = "setting", setting = setting, value = value })
end

function Net.sync()
	send({ kind = "sync" })
end

function Net.isSettingOn(setting: SettingName): boolean
	local progress = Net.progress
	if not progress then
		return true
	end
	return progress.settings[setting]
end

remotes.snapshot.OnClientEvent:Connect(function(payload: Snapshot | false)
	if payload == false then
		Net.snapshot = nil
		nextRevision = 0
		resyncPending = false
		emit(snapshotListeners, nil)
		return
	end
	local snapshot = payload :: Snapshot
	local previous = Net.snapshot
	if resyncPending or not previous or previous.sessionId ~= snapshot.sessionId then
		nextRevision = snapshot.revision
		resyncPending = false
	else
		nextRevision = math.max(nextRevision, snapshot.revision)
	end
	Net.snapshot = snapshot
	emit(snapshotListeners, snapshot)
end)

remotes.progress.OnClientEvent:Connect(function(progress: ProgressView)
	Net.progress = progress
	emit(progressListeners, progress)
end)

remotes.notice.OnClientEvent:Connect(function(notice: Notice)
	if notice.code ~= "save_failed" then
		-- Every other notice is a rejection that the server follows with a snapshot.
		resyncPending = true
	end
	emit(noticeListeners, notice)
end)

return Net
