

-- FLAG SETUP
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlagService = require(ReplicatedStorage.Packages.FlagService) ---@module FlagService

local FLAG_NAME = "ZoneEnabled"
local DEFAULT_VALUE = false

local ZONE_MODEL = workspace:WaitForChild("ZoneModel")

local izZoneEnabled = FlagService:GetFlag(FLAG_NAME)

if izZoneEnabled == nil then
    FlagService:SetFlag(FLAG_NAME, DEFAULT_VALUE)
end

local function updateZoneEnabled(isEnabled: boolean)
    izZoneEnabled = isEnabled

    ZONE_MODEL.Parent = isEnabled and workspace or ReplicatedStorage
end

FlagService:GetFlagChangedSignal(FLAG_NAME):Connect(updateZoneEnabled)
updateZoneEnabled(izZoneEnabled)

-- CHAT COMMANDS FOR TESTING

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local function createCommand(commandName: string, alias: string, callback: (player: Player) -> ())
    local command: TextChatCommand = Instance.new("TextChatCommand")
	command.Name = commandName
	command.PrimaryAlias = alias
	command.Triggered:Connect(function(originTextSource, unfilteredText)
		local userId: number = originTextSource.UserId
		local player: Player = Players:GetPlayerByUserId(userId)

        if player then
            callback(player)
        end
	end)
	command.Parent = TextChatService
end

createCommand("toggleZone", "/toggleZone", function(player)
    FlagService:SetFlag(FLAG_NAME, not izZoneEnabled)
end)

createCommand("toggleZoneLocal", "/toggleZoneLocal", function(player)
    FlagService:SetFlagThisServer(FLAG_NAME, not izZoneEnabled)
end)

createCommand("updateZone", "/updateZone", function(player)
    FlagService:UpdateFlag(FLAG_NAME)
end)

createCommand("publishZone", "/publishZone", function(player)
    FlagService:PublishFlag(FLAG_NAME)
end)