local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlagService = require(ReplicatedStorage.Packages.FlagService) ---@module FlagService

local success, result: FlagService.Flag = FlagService:GetFlagAsync("TestFlag"):await()

local testFlagPart

local function runTestFlagPart(value: any)
    if testFlagPart == nil then
        testFlagPart = Instance.new("Part")
        testFlagPart.Name = "TestFlagPart"
        testFlagPart.Parent = workspace
        testFlagPart.Color = Color3.new(255, 255, 255)
        testFlagPart.Material = Enum.Material.Neon
        testFlagPart.Position = Vector3.new(0, 10, 0)
    end

    if value == true then
        testFlagPart.Parent = workspace
    else
        testFlagPart.Parent = nil
    end
end

FlagService:GetFlagChangedSignal("TestFlag"):Connect(function(value: any)
    print(value)
    runTestFlagPart(value)
end)


runTestFlagPart(result.Value)