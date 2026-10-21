--!strict
--[[
	ActionGateway: the only entry point for client actions.

	Order of checks for every remote call:
	  1. per-player rate limit and cooldown
	  2. payload shape (RequestValidator)
	  3. membership, session id, revision and bounds (SessionManager, via handler)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = require(ReplicatedStorage.Shared.Protocol)
local Types = require(ReplicatedStorage.Shared.Types)
local Config = require(script.Parent.Parent.Config)
local RateLimiter = require(script.Parent.RateLimiter)
local RequestValidator = require(script.Parent.RequestValidator)

type ActionRequest = Types.ActionRequest
type ErrorCode = Types.ErrorCode

export type Handler = (player: Player, request: ActionRequest) -> ()
export type RejectHandler = (player: Player, code: ErrorCode) -> ()

local ActionGateway = {}
ActionGateway.__index = ActionGateway

export type ActionGateway = typeof(setmetatable(
	{} :: {
		limiter: RateLimiter.RateLimiter,
		connection: RBXScriptConnection?,
	},
	ActionGateway
))

function ActionGateway.new(): ActionGateway
	return setmetatable({
		limiter = RateLimiter.new(Config.RATE_LIMIT),
		connection = nil,
	}, ActionGateway)
end

function ActionGateway.connect(
	self: ActionGateway,
	remotes: Protocol.Remotes,
	handler: Handler,
	onReject: RejectHandler
)
	assert(self.connection == nil, "ActionGateway is already connected")
	self.connection = remotes.action.OnServerEvent:Connect(function(player: Player, raw: unknown)
		if not self.limiter:allow(player.UserId, os.clock()) then
			onReject(player, "rate_limited")
			return
		end
		local request: ActionRequest?, code: ErrorCode? = RequestValidator.parse(raw)
		if not request then
			onReject(player, code or "bad_request")
			return
		end
		handler(player, request)
	end)
end

function ActionGateway.forget(self: ActionGateway, player: Player)
	self.limiter:forget(player.UserId)
end

return ActionGateway
