--!strict
-- Server entry point: build and validate the level catalog, then start the game.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = script.Parent
local Config = require(Server.Config)
local catalog = require(Server.levels.Catalog)
local LevelLibrary = require(Server.logic.LevelLibrary)
local GameService = require(Server.services.GameService)

-- Fails loudly at startup if any floor is malformed or unsolvable.
local entries = LevelLibrary.build(catalog)

GameService.new(entries):start()

if RunService:IsStudio() and ServerScriptService:GetAttribute(Config.SMOKE_TEST_ATTRIBUTE) == true then
	require(Server.dev.SmokeTest).run(entries)
end
