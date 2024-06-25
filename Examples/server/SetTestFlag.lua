local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlagService = require(ReplicatedStorage.Packages.FlagService) ---@module FlagService

local success, result = FlagService:SetFlagAsync("TestFlag", false, {
    Author = "Scott",
}):await()

print(success, result)