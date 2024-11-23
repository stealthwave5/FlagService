
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlagService = require(ReplicatedStorage.Packages.FlagService) ---@module FlagService

local FLAG_NAME = "TestFlag"

FlagService:GetFlagChangedSignal(FLAG_NAME):Connect(function(newValue)
    print("Flag changed to", newValue)
end)

local currentFlagValue = FlagService:GetFlag(FLAG_NAME)
print("Current flag value is", currentFlagValue)
FlagService:SetFlag(FLAG_NAME, not currentFlagValue)