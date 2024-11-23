--!nonstrict

--
--			FlagService
--
--

local FlagService = {}

-- Services
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")

-- Modules
local Signal: Signal do

	local FreeRunnerThread

	--[[
		Yield-safe coroutine reusing by stravant;
		Sources:
		https://devforum.roblox.com/t/lua-signal-class-comparison-optimal-goodsignal-class/1387063
		https://gist.github.com/stravant/b75a322e0919d60dde8a0316d1f09d2f
	--]]

	local function AcquireRunnerThreadAndCallEventHandler(fn, ...)
		local acquired_runner_thread = FreeRunnerThread
		FreeRunnerThread = nil
		fn(...)
		-- The handler finished running, this runner thread is free again.
		FreeRunnerThread = acquired_runner_thread
	end

	local function RunEventHandlerInFreeThread(...)
		AcquireRunnerThreadAndCallEventHandler(...)
		while true do
			AcquireRunnerThreadAndCallEventHandler(coroutine.yield())
		end
	end

	local Connection = {}
	Connection.__index = Connection

	local SignalClass = {}
	SignalClass.__index = SignalClass

	function Connection:Disconnect()

		if self.is_connected == false then
			return
		end

		local signal = self.signal
		self.is_connected = false
		signal.listener_count -= 1

		if signal.head == self then
			signal.head = self.next
		else
			local prev = signal.head
			while prev ~= nil and prev.next ~= self do
				prev = prev.next
			end
			if prev ~= nil then
				prev.next = self.next
			end
		end

	end

	function SignalClass.new()

		local self = {
			head = nil,
			listener_count = 0,
		}
		setmetatable(self, SignalClass)

		return self

	end

	function SignalClass:Connect(listener: (...any) -> ())

		if type(listener) ~= "function" then
			error(`[{script.Name}]: \"listener\" must be a function; Received {typeof(listener)}`)
		end

		local connection = {
			listener = listener,
			signal = self,
			next = self.head,
			is_connected = true,
		}
		setmetatable(connection, Connection)

		self.head = connection
		self.listener_count += 1

		return connection

	end

	function SignalClass:GetListenerCount(): number
		return self.listener_count
	end

	function SignalClass:Fire(...)
		local item = self.head
		while item ~= nil do
			if item.is_connected == true then
				if not FreeRunnerThread then
					FreeRunnerThread = coroutine.create(RunEventHandlerInFreeThread)
				end
				task.spawn(FreeRunnerThread, item.listener, ...)
			end
			item = item.next
		end
	end

	Signal = table.freeze({
		new = SignalClass.new,
	})

end

-- Types
type Signal = {
    new: () -> Signal,
    Connect: (self: Signal, listener: (...any) -> ()) -> RBXScriptConnection,
    GetListenerCount: () -> number,
    Fire: (self: Signal, ...any) -> (),
}

type CachedFlag = {
    FlagName: string,
    Value: any,
}

type FlagMessageData = {
    ServerId: string,
    CachedFlag: CachedFlag,
}

-- Constants
local FLAG_SERVICE_DATA_STORE_NAME = "FlagService_DataStore"
local FLAG_SERVICE_MESSAGING_TOPIC = "FlagService_Messaging_Topic"

local IS_STUDIO = RunService:IsStudio()
local SERVER_ID = IS_STUDIO and "Studio" or game.JobId

local FLAG_SERVICE_DATA_STORE = DataStoreService:GetDataStore(FLAG_SERVICE_DATA_STORE_NAME)

-- Variables
local isStarted = false
local cachedFlags: { [string]: CachedFlag } = {}
local flagChangedSignals: { [string]: Signal } = {}

-- Private functions
local function verboseWarn(...)
    warn("[FlagService]", ..., " | ", debug.traceback())
end

local function fireFlagUpdatedSignal(flagName: string, value: any)
    local flagChangedSignal: Signal? = flagChangedSignals[flagName]

    if flagChangedSignal ~= nil then
        flagChangedSignal:Fire(value)
    end
end

local function createCachedFlag(flagName: string, value: any?, isThisServerOnly: boolean?, dontFireSignal: boolean?)
    if flagName == nil then
        verboseWarn("Flag name is nil, cannot cache flag")
        return
    end

    if cachedFlags[flagName] ~= nil then
        verboseWarn(`Flag {flagName} is already cached!`)
        
        return
    end

    if isThisServerOnly == nil then
        isThisServerOnly = false
    end

    if dontFireSignal == nil then
        dontFireSignal = false
    end

    local cachedFlag: CachedFlag = {
        FlagName = flagName,
        IsThisServerOnly = isThisServerOnly,
        Value = value,
    }

    cachedFlags[flagName] = cachedFlag

    if dontFireSignal == true then
        return
    end

    fireFlagUpdatedSignal(flagName, value)
end

local function getCachedFlag(flagName: string): CachedFlag
    return cachedFlags[flagName]
end

local function getFlag(flagName: string): any
    local cachedFlag = getCachedFlag(flagName)

    if cachedFlag ~= nil then
        return cachedFlag.Value
    end

    local success, result = pcall(function()
        return FLAG_SERVICE_DATA_STORE:GetAsync(flagName)
    end)

    if not success then
        verboseWarn(`Failed to get flag value for flag {flagName}`, result)
        
        return nil
    end

    createCachedFlag(flagName, result, false, true)

    return result
end

local function pullLatestFlagValueFromDataStore(flagName: string)
    local success, result = pcall(function()
        return FLAG_SERVICE_DATA_STORE:GetAsync(flagName)
    end)

    if not success then
        verboseWarn(`Failed to get flag value for flag {flagName}`, result)
        
        return
    end

    local cachedFlag = getCachedFlag(flagName)

    if cachedFlag == nil then
        verboseWarn(`Cached flag {flagName} is nil, cannot pull latest flag value from DataStore`)
        
        return
    end

    cachedFlag.Value = result
    cachedFlag.IsThisServerOnly = false
    
    fireFlagUpdatedSignal(flagName, result)
end

local function sendFlagUpdateMessage(flagName: string)
    local cachedFlag = getCachedFlag(flagName)

    if cachedFlag == nil then
        verboseWarn(`Cached flag {flagName} is nil, cannot send flag update message`)
        
        return
    end

    local flagMessageData: FlagMessageData = {
        ServerId = SERVER_ID,
        CachedFlag = cachedFlag,
    }

    MessagingService:PublishAsync(FLAG_SERVICE_MESSAGING_TOPIC, flagMessageData)
end

local function updateFlagDataStore(flagName: string?)
    local cachedFlag = getCachedFlag(flagName)

    if cachedFlag == nil then
        verboseWarn(`Cached flag {flagName} is nil, cannot update flag data store`)
        
        return
    end

    local success, result = pcall(FLAG_SERVICE_DATA_STORE.UpdateAsync, FLAG_SERVICE_DATA_STORE, flagName, function(oldValue: any?)
        return cachedFlag.Value
    end)

    if not success then
        verboseWarn(`Failed to update flag {flagName} in DataStore`, result)
        
        return
    end
end

local function setCachedFlagValue(flagName: string, value: any?, isThisServerOnly: boolean): boolean
    if flagName == nil then
        verboseWarn("Flag name is nil, cannot set flag value")
        return false
    end

    if isThisServerOnly == nil then
        verboseWarn("isThisServerOnly is nil, cannot set flag value")
        return false
    end

    local cachedFlag = getCachedFlag(flagName)

    if cachedFlag == nil then
        createCachedFlag(flagName, value, isThisServerOnly)
        
        return true
    end

    --! This essentially session locks the flag, currently feels unnecessary
    -- if cachedFlag.IsThisServerOnly == true and isThisServerOnly == false then
    --     verboseWarn(`Flag {flagName} is set to this server only, cannot set flag value`)
        
    --     return false
    -- end

    cachedFlag.Value = value
    cachedFlag.IsThisServerOnly = isThisServerOnly

    fireFlagUpdatedSignal(flagName, value)

    return true
end

local function setFlag(flagName: string, value: any?, isThisServerOnly: boolean)
    local hasSetFlag = setCachedFlagValue(flagName, value, isThisServerOnly)

    if hasSetFlag == false then
        return
    end

    if isThisServerOnly == false then
        updateFlagDataStore(flagName)
        sendFlagUpdateMessage(flagName)
    end
end

local function getFlagChangedSignal(flagName: string): Signal
    if flagChangedSignals[flagName] == nil then
        local newSignal = Signal.new()

        flagChangedSignals[flagName] = newSignal
    end

    return flagChangedSignals[flagName]
end

local function readFlagChangedMessages()
    MessagingService:SubscribeAsync(FLAG_SERVICE_MESSAGING_TOPIC, function(message: Message)
        local messageFlagData: FlagMessageData = message.Data

        local serverId = messageFlagData.ServerId

        if serverId == SERVER_ID then
            return
        end

        local cachedFlag = messageFlagData.CachedFlag

        setCachedFlagValue(cachedFlag.FlagName, cachedFlag.Value, false)
    end)
end

-- Public functions
function FlagService:GetFlag(flagName: string)
    return getFlag(flagName)
end

function FlagService:SetFlagThisServer(flagName: string, value: any?)
    return setFlag(flagName, value, true)    
end

function FlagService:SetFlag(flagName: string, value: any?)
    return setFlag(flagName, value, false)
end

function FlagService:GetFlagChangedSignal(flagName: string)
    return getFlagChangedSignal(flagName)
end

function FlagService:ResetFlagFromStorage(flagName: string)
    return pullLatestFlagValueFromDataStore(flagName)
end

-- Start
function FlagService.start()
    if isStarted == true then
        return FlagService
    end

    isStarted = true

    readFlagChangedMessages()

    return FlagService
end

return FlagService.start()