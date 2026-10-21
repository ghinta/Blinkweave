--!strict
-- Client entry point: start controllers, wire feedback sounds, request state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Client = script.Parent
local Audio = require(Client.Audio)
local BoardController = require(Client.BoardController)
local Hud = require(Client.Hud)
local InputController = require(Client.InputController)
local Net = require(Client.Net)

type Snapshot = Types.Snapshot

BoardController.start()
InputController.start()
Hud.start()

Net.onProgress(function(progress: Types.ProgressView)
	Audio.setEnabled(progress.settings.soundOn)
end)

-- Sound feedback for accepted moves and for solving a floor.
local lastSession: string? = nil
local lastRevision = -1
Net.onSnapshot(function(snapshot: Snapshot?)
	if not snapshot then
		lastSession = nil
		return
	end
	local isNewEvent = snapshot.sessionId == lastSession and snapshot.revision > lastRevision
	lastSession = snapshot.sessionId
	lastRevision = snapshot.revision
	if not isNewEvent then
		return
	end
	if snapshot.solved then
		Audio.solved()
	elseif #snapshot.changedCells > 0 then
		local lit = 0
		for _, on in snapshot.cells do
			if on then
				lit += 1
			end
		end
		Audio.toggle(lit, #snapshot.cells)
	end
end)

-- Remote events fired before these listeners existed may be missed; ask again.
Net.sync()
