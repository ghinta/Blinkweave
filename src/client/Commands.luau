--!strict
-- Player intents shared by HUD buttons, keyboard/gamepad shortcuts and world input.

local Audio = require(script.Parent.Audio)
local Net = require(script.Parent.Net)

local Commands = {}

function Commands.press(cellIndex: number)
	Net.press(cellIndex)
end

function Commands.undo()
	if not Net.undo() then
		Audio.denied()
	end
end

-- Restarts the current puzzle, or replays the floor once it is solved.
function Commands.restart()
	local snapshot = Net.snapshot
	if not snapshot then
		return
	end
	Audio.click()
	if snapshot.solved then
		Net.start(snapshot.floor)
	else
		Net.reset()
	end
end

function Commands.hint()
	local snapshot = Net.snapshot
	if not snapshot or snapshot.solved then
		Audio.denied()
		return
	end
	Audio.click()
	Net.hint()
end

function Commands.nextFloor()
	local snapshot = Net.snapshot
	if not snapshot or not snapshot.solved then
		Audio.denied()
		return
	end
	Audio.travel()
	Net.nextFloor()
end

function Commands.leave()
	Audio.click()
	Net.leave()
end

function Commands.start(floor: number)
	Audio.travel()
	Net.start(floor)
end

return Commands
