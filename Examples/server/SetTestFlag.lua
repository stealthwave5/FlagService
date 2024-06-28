local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlagService = require(ReplicatedStorage.Packages.FlagService) ---@module FlagService

local success, result = FlagService:SetFlagAsync("TestFlag", true, {
    Author = "Scott",
}):await()

print(success, result)