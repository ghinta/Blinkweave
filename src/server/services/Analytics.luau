--!strict
--[[
	Analytics: first-party Roblox AnalyticsService only, no third-party SDKs
	and no personal data. Every call is protected so analytics can never break
	gameplay (e.g. in Studio or during an AnalyticsService outage).
]]

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Analytics = {}

local PROGRESSION_PATH = "tower"
local TUTORIAL_START_STEP = 1
local TUTORIAL_FINISH_STEP = 2

local function log(label: string, call: () -> ...any)
	local ok, err = pcall(call)
	if not ok and RunService:IsStudio() then
		warn(`[Analytics] {label} not logged: {err}`)
	end
end

function Analytics.tutorialStarted(player: Player)
	log("tutorial_start", function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, TUTORIAL_START_STEP, "tutorial_start")
	end)
end

function Analytics.tutorialFinished(player: Player)
	log("tutorial_finish", function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, TUTORIAL_FINISH_STEP, "tutorial_finish")
	end)
end

function Analytics.floorStarted(player: Player, floor: number, levelId: string)
	log("floor_start", function()
		AnalyticsService:LogProgressionStartEvent(player, PROGRESSION_PATH, floor, levelId)
	end)
end

function Analytics.floorFinished(player: Player, floor: number, levelId: string)
	log("floor_finish", function()
		AnalyticsService:LogProgressionCompleteEvent(player, PROGRESSION_PATH, floor, levelId)
	end)
end

-- The player left an unsolved floor (back to lobby, switched floor or quit).
function Analytics.floorExited(player: Player, floor: number)
	log("floor_exit", function()
		AnalyticsService:LogCustomEvent(player, "floor_exit", floor)
	end)
end

function Analytics.reset(player: Player, floor: number)
	log("floor_reset", function()
		AnalyticsService:LogCustomEvent(player, "floor_reset", floor)
	end)
end

function Analytics.hint(player: Player, floor: number)
	log("hint_used", function()
		AnalyticsService:LogCustomEvent(player, "hint_used", floor)
	end)
end

return Analytics
