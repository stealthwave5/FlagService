
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlagService = require(ReplicatedStorage.Packages.FlagService) ---@module FlagService

local FLAG_NAME = "TestFlag"

local currentFlagValue = FlagService:GetFlag(FLAG_NAME)

FlagService:GetFlagChangedSignal(FLAG_NAME):Connect(function(newValue)
    currentFlagValue = newValue
    print("Current flag value is", currentFlagValue)
end)

print("Current flag value is", currentFlagValue)

FlagService:SetFlagThisServer(FLAG_NAME, not currentFlagValue)
task.wait(1)
print("Resetting flag")
FlagService:ResetFlagFromStorage(FLAG_NAME)