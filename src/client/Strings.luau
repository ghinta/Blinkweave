--!strict
--[[
	UI strings in German and English. The player's Roblox locale picks the
	language; anything not German falls back to English.
]]

local Players = game:GetService("Players")

type Table = { [string]: string }

local en: Table = {
	floor = "Floor",
	moves = "Moves",
	par = "Par",
	time = "Time",
	best = "Best",
	goal = "Goal: all lights off",
	howTo = "Tap a tile or jump on it: it flips itself and its neighbours.",
	tutorialReset = "Tutorial: restarting is free.",
	undo = "Undo",
	restart = "Restart",
	hint = "Hint",
	lobby = "Lobby",
	solvedTitle = "Floor solved!",
	towerComplete = "Tower complete!",
	nextFloor = "Next floor",
	replay = "Play again",
	play = "Play",
	locked = "Locked",
	tutorial = "Tutorial",
	floors = "Floors",
	hideFloors = "Hide",
	sound = "Sound",
	jumpToggles = "Jump flips",
	on = "On",
	off = "Off",
	loading = "Loading progress…",
	degraded = "Progress can't be saved right now.",
	subtitle = "Flip one tile, change its neighbours, climb the tower.",
	doorLocked = "All lights off",
	doorOpen = "Exit",
	startPad = "Enter the tower",
	gridLabel = "Board",
	-- Notices
	rate_limited = "A little slower, please.",
	undo_unavailable = "Undo is not available.",
	floor_locked = "That floor is still locked.",
	not_solved = "Solve the floor first.",
	unavailable = "Not available right now.",
	save_failed = "Saving failed. Retrying soon.",
}

local de: Table = {
	floor = "Stockwerk",
	moves = "Züge",
	par = "Par",
	time = "Zeit",
	best = "Bestwert",
	goal = "Ziel: Alle Lichter aus",
	howTo = "Tippe eine Fliese an oder springe darauf: Sie und ihre Nachbarn schalten um.",
	tutorialReset = "Tutorial: Neustart ist kostenlos.",
	undo = "Rückgängig",
	restart = "Neustart",
	hint = "Hinweis",
	lobby = "Lobby",
	solvedTitle = "Stockwerk gelöst!",
	towerComplete = "Turm geschafft!",
	nextFloor = "Nächster Stock",
	replay = "Nochmal",
	play = "Spielen",
	locked = "Gesperrt",
	tutorial = "Tutorial",
	floors = "Stockwerke",
	hideFloors = "Ausblenden",
	sound = "Ton",
	jumpToggles = "Sprung schaltet",
	on = "An",
	off = "Aus",
	loading = "Fortschritt wird geladen …",
	degraded = "Fortschritt kann gerade nicht gespeichert werden.",
	subtitle = "Schalte eine Fliese, verändere ihre Nachbarn, erklimm den Turm.",
	doorLocked = "Alle Lichter aus",
	doorOpen = "Ausgang",
	startPad = "Turm betreten",
	gridLabel = "Spielfeld",
	rate_limited = "Etwas langsamer, bitte.",
	undo_unavailable = "Rückgängig ist nicht möglich.",
	floor_locked = "Dieses Stockwerk ist noch gesperrt.",
	not_solved = "Löse zuerst das Rätsel.",
	unavailable = "Gerade nicht verfügbar.",
	save_failed = "Speichern fehlgeschlagen. Neuer Versuch folgt.",
}

local function pickTable(): Table
	local locale = string.lower(Players.LocalPlayer.LocaleId)
	return if string.sub(locale, 1, 2) == "de" then de else en
end

local active = pickTable()

local Strings = {}

function Strings.get(key: string): string
	return active[key] or en[key] or key
end

function Strings.has(key: string): boolean
	return en[key] ~= nil
end

function Strings.formatTime(seconds: number): string
	local whole = math.floor(seconds + 0.5)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

return Strings
