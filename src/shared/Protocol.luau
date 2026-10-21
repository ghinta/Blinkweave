--!strict
--[[
	Network protocol constants shared by client and server.

	Remote traffic:
	  Action   (client -> server)  Types.ActionRequest
	  Snapshot (server -> client)  Types.Snapshot, or false when no session is active
	  Progress (server -> client)  Types.ProgressView
	  Notice   (server -> client)  Types.Notice
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = {}

Protocol.REMOTES_FOLDER = "BlinkweaveRemotes"
Protocol.ACTION = "Action"
Protocol.SNAPSHOT = "Snapshot"
Protocol.PROGRESS = "Progress"
Protocol.NOTICE = "Notice"

-- World tagging used by the client renderer and input raycasts.
Protocol.TILE_TAG = "BlinkweaveTile"
Protocol.DOOR_TAG = "BlinkweaveDoor"
Protocol.START_PAD_TAG = "BlinkweaveStartPad"
Protocol.ATTR_OWNER = "BlinkweaveOwner"
Protocol.ATTR_CELL = "BlinkweaveCell"
Protocol.ATTR_LIT = "BlinkweaveLit"
Protocol.ATTR_OPEN = "BlinkweaveOpen"

export type Remotes = {
	action: RemoteEvent,
	snapshot: RemoteEvent,
	progress: RemoteEvent,
	notice: RemoteEvent,
}

local cached: Remotes? = nil

-- Creates the remotes on the server and waits for them on the client.
function Protocol.getRemotes(): Remotes
	if cached then
		return cached
	end

	local folder: Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(Protocol.REMOTES_FOLDER)
		if existing then
			folder = existing
		else
			folder = Instance.new("Folder")
			folder.Name = Protocol.REMOTES_FOLDER
			folder.Parent = ReplicatedStorage
		end
	else
		folder = ReplicatedStorage:WaitForChild(Protocol.REMOTES_FOLDER)
	end

	local function remote(name: string): RemoteEvent
		if RunService:IsServer() then
			local existing = folder:FindFirstChild(name)
			if existing and existing:IsA("RemoteEvent") then
				return existing
			end
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
			return event
		end
		return folder:WaitForChild(name) :: RemoteEvent
	end

	local remotes: Remotes = {
		action = remote(Protocol.ACTION),
		snapshot = remote(Protocol.SNAPSHOT),
		progress = remote(Protocol.PROGRESS),
		notice = remote(Protocol.NOTICE),
	}
	cached = remotes
	return remotes
end

return Protocol
