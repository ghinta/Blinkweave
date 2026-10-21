--!strict
--[[
	Audio cues using sounds bundled with the Roblox client (rbxasset://),
	so no marketplace audio is needed. Replace the ids with original sounds
	before launch. Respects the player's sound setting.
]]

local SoundService = game:GetService("SoundService")

local SOUND_IDS = table.freeze({
	ping = "rbxasset://sounds/electronicpingshort.wav",
	click = "rbxasset://sounds/button.wav",
	whoosh = "rbxasset://sounds/swoosh.wav",
})

local Audio = {}

local enabled = true

function Audio.setEnabled(value: boolean)
	enabled = value
end

local function play(soundId: string, speed: number, volume: number)
	if not enabled then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = speed
	sound.Volume = volume
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	-- Safety net if the asset never loads and Ended never fires.
	task.delay(5, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Higher pitch when more lights are on after the move, lower when fewer.
function Audio.toggle(litAfter: number, cellCount: number)
	local ratio = if cellCount > 0 then litAfter / cellCount else 0
	play(SOUND_IDS.ping, 0.85 + ratio * 0.5, 0.45)
end

function Audio.solved()
	for step, speed in { 1.0, 1.26, 1.5 } do
		task.delay((step - 1) * 0.12, play, SOUND_IDS.ping, speed, 0.6)
	end
end

function Audio.click()
	play(SOUND_IDS.click, 1.1, 0.35)
end

function Audio.denied()
	play(SOUND_IDS.click, 0.6, 0.35)
end

function Audio.travel()
	play(SOUND_IDS.whoosh, 1, 0.5)
end

return Audio
