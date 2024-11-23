
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlagService = require(ReplicatedStorage.Packages.FlagService) ---@module FlagService

FlagService:SetFlag("TestFlag", true)
print(FlagService:GetFlag("TestFlag"))
FlagService:SetFlagThisServer("TestFlag", false)
FlagService:SetFlag("TestFlag", true)